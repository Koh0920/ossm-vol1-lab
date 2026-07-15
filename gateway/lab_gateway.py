#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import shutil
import socket
import stat
import struct
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


def _recv_exact(connection: socket.socket, size: int) -> bytes:
    data = bytearray()
    while len(data) < size:
        chunk = connection.recv(size - len(data))
        if not chunk:
            raise ConnectionError("RFB peer closed during readiness handshake")
        data.extend(chunk)
    return bytes(data)


def _rfb_ready(host: str, port: int) -> bool:
    """Complete the unauthenticated RFB 3.8 startup handshake.

    A listening TCP port is insufficient after Ready-State restore: Xtigervnc
    can accept a socket and close it before a browser receives ServerInit. The
    public noVNC session is usable only after the same handshake reaches a
    positive framebuffer size.
    """

    try:
        with socket.create_connection((host, port), timeout=1.0) as connection:
            connection.settimeout(1.0)
            server_version = _recv_exact(connection, 12)
            if not server_version.startswith(b"RFB 003.") or not server_version.endswith(
                b"\n"
            ):
                return False

            connection.sendall(b"RFB 003.008\n")
            security_type_count = _recv_exact(connection, 1)[0]
            if security_type_count == 0:
                return False
            security_types = _recv_exact(connection, security_type_count)
            if 1 not in security_types:  # SecurityType None
                return False

            connection.sendall(b"\x01")
            if struct.unpack(">I", _recv_exact(connection, 4))[0] != 0:
                return False

            connection.sendall(b"\x01")  # shared ClientInit
            server_init = _recv_exact(connection, 24)
            width, height = struct.unpack(">HH", server_init[:4])
            name_length = struct.unpack(">I", server_init[20:24])[0]
            if name_length > 1_048_576:
                return False
            _recv_exact(connection, name_length)
            return width > 0 and height > 0
    except (OSError, ConnectionError, struct.error, TimeoutError):
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
    rfb_handshake = _rfb_ready("127.0.0.1", 5901)
    checks: dict[str, object] = {
        "supervisor": {
            name: states.get(name) == "RUNNING" for name in REQUIRED_PROGRAMS
        },
        # Preserve vnc_tcp for existing health consumers while strengthening it
        # from a bare accept() check to a complete RFB ServerInit handshake.
        "vnc_tcp": rfb_handshake,
        "rfb_handshake": rfb_handshake,
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
            "rfb_handshake",
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
