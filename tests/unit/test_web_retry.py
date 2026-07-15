import unittest
from pathlib import Path


INDEX_PATH = Path(__file__).parents[2] / "web" / "index.html"


class WebRetryTests(unittest.TestCase):
    def test_initial_novnc_failure_is_retried_with_bounded_backoff(self):
        html = INDEX_PATH.read_text(encoding="utf-8")

        self.assertIn('id="eda-desktop"', html)
        self.assertIn("noVNC_status_error", html)
        self.assertIn("noVNC_connected", html)
        self.assertIn("const retryDelaysMs = [2000, 4000, 8000, 12000, 16000]", html)


if __name__ == "__main__":
    unittest.main()
