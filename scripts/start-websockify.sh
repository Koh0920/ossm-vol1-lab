#!/usr/bin/env bash
set -euo pipefail

"$OSSM_ROOT/scripts/wait-port.py" 127.0.0.1 5901 30
exec /usr/bin/websockify --web=/usr/share/novnc 127.0.0.1:6080 127.0.0.1:5901

