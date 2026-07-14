#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import shutil
import socket
import stat
import subprocess
import tempfile
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

WORKSPACE = Path(os.environ.get("OSSM_WORKSPACE", "/foss/designs"))
EXPORTS = WORKSPACE / "exports"
PDK_MARKER = Path("/opt/ossm/immutable/PDK_COMMITS")
DESKTOP_SENTINEL = Path("/run/ossm/desktop-ready")
MAX_DOWNLOAD_BYTES = 256 * 1024 * 1024
REQUIRED_COMMANDS = ("xschem", "ngspice", "klayout", "netgen", "labctl")
REQUIRED_PROGRAMS = ("xvnc", "xfce", "websockify", "gateway", "nginx")


def _tcp_ready(host: str, port: int) -> bool:
    try:
        with socket.create_connection((host, port), timeout=0.5):
            return True
    except OSError:
        return False


def _supervisor_states() -> dict[str, str]:
    result = subprocess.run(
        ["supervisorctl", "-c", "/opt/ossm/supervisor/supervisord.conf", "status"],
        check=False,
        capture_output=True,
        text=True,
        timeout=3,
    )
    states: dict[str, str] = {}
    for line in result.stdout.splitlines():
        fields = line.split()
        if len(fields) >= 2:
            states[fields[0]] = fields[1]
    return states


def health_report() -> tuple[bool, dict[str, object]]:
    states = _supervisor_states()
    checks: dict[str, object] = {
        "supervisor": {
            name: states.get(name) == "RUNNING" for name in REQUIRED_PROGRAMS
        },
        "vnc_tcp": _tcp_ready("127.0.0.1", 5901),
        "websockify_tcp": _tcp_ready("127.0.0.1", 6080),
        "desktop_ready": DESKTOP_SENTINEL.is_file(),
        "pdk_marker": PDK_MARKER.is_file()
        and "openrule1um=7b3c4c4d8feca8e94388bb856a42ee4caf8f8763"
        in PDK_MARKER.read_text(encoding="utf-8"),
        "commands": {name: shutil.which(name) is not None for name in REQUIRED_COMMANDS},
    }

    workspace_ok = False
    try:
        EXPORTS.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(dir=WORKSPACE, prefix=".health-", delete=True) as f:
            f.write(b"ok")
            f.flush()
        workspace_ok = True
    except OSError:
        workspace_ok = False
    checks["workspace_writable"] = workspace_ok

    supervisor_ok = all(checks["supervisor"].values())
    commands_ok = all(checks["commands"].values())
    ok = supervisor_ok and commands_ok and all(
        bool(checks[name])
        for name in (
            "vnc_tcp",
            "websockify_tcp",
            "desktop_ready",
            "pdk_marker",
            "workspace_writable",
        )
    )
    return ok, checks


class Handler(BaseHTTPRequestHandler):
    server_version = "ossm-lab-gateway/0.1"

    def do_GET(self) -> None:  # noqa: N802
        if self.path == "/healthz":
            self._health()
            return
        if self.path == "/downloads/latest.zip":
            self._download("latest.zip", "application/zip")
            return
        if self.path == "/downloads/latest.zip.sha256":
            self._download("latest.zip.sha256", "text/plain; charset=utf-8")
            return
        self.send_error(404)

    def do_HEAD(self) -> None:  # noqa: N802
        if self.path == "/healthz":
            self._health(head_only=True)
            return
        self.send_error(404)

    def _health(self, head_only: bool = False) -> None:
        ok, checks = health_report()
        body = json.dumps(
            {"status": "ok" if ok else "not_ready", "checks": checks},
            sort_keys=True,
        ).encode("utf-8")
        self.send_response(200 if ok else 503)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        if not head_only:
            self.wfile.write(body)

    def _download(self, filename: str, content_type: str) -> None:
        path = EXPORTS / filename
        try:
            fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
        except FileNotFoundError:
            self.send_error(404, "No export is available yet")
            return
        except OSError:
            self.send_error(403)
            return

        with os.fdopen(fd, "rb") as source:
            info = os.fstat(source.fileno())
            if not stat.S_ISREG(info.st_mode) or info.st_size > MAX_DOWNLOAD_BYTES:
                self.send_error(413)
                return
            self.send_response(200)
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(info.st_size))
            self.send_header("Content-Disposition", f'attachment; filename="{filename}"')
            self.send_header("Cache-Control", "no-store")
            self.send_header("X-Content-Type-Options", "nosniff")
            self.end_headers()
            while chunk := source.read(1024 * 1024):
                self.wfile.write(chunk)

    def log_message(self, fmt: str, *args: object) -> None:
        print(f"gateway: {self.address_string()} {fmt % args}", flush=True)


if __name__ == "__main__":
    ThreadingHTTPServer(("127.0.0.1", 8000), Handler).serve_forever()

