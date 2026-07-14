import importlib.util
import tempfile
import unittest
from pathlib import Path
from unittest import mock


MODULE_PATH = Path(__file__).parents[2] / "gateway" / "lab_gateway.py"
SPEC = importlib.util.spec_from_file_location("lab_gateway", MODULE_PATH)
gateway = importlib.util.module_from_spec(SPEC)
assert SPEC.loader
SPEC.loader.exec_module(gateway)


class GatewayTests(unittest.TestCase):
    def test_closed_tcp_port_is_not_ready(self):
        self.assertFalse(gateway._tcp_ready("127.0.0.1", 9))

    def test_health_requires_every_supervisor_program(self):
        states = {name: "RUNNING" for name in gateway.REQUIRED_PROGRAMS}
        states["xfce"] = "BACKOFF"
        with tempfile.TemporaryDirectory() as directory:
            workspace = Path(directory)
            marker = workspace / "PDK_COMMITS"
            marker.write_text(
                "openrule1um=7b3c4c4d8feca8e94388bb856a42ee4caf8f8763\n",
                encoding="utf-8",
            )
            sentinel = workspace / "desktop-ready"
            sentinel.touch()
            with (
                mock.patch.object(gateway, "WORKSPACE", workspace),
                mock.patch.object(gateway, "EXPORTS", workspace / "exports"),
                mock.patch.object(gateway, "PDK_MARKER", marker),
                mock.patch.object(gateway, "DESKTOP_SENTINEL", sentinel),
                mock.patch.object(gateway, "_supervisor_states", return_value=states),
                mock.patch.object(gateway, "_tcp_ready", return_value=True),
                mock.patch("shutil.which", return_value="/bin/tool"),
            ):
                ok, report = gateway.health_report()
        self.assertFalse(ok)
        self.assertFalse(report["supervisor"]["xfce"])


if __name__ == "__main__":
    unittest.main()

