#!/usr/bin/env bash
set -euo pipefail

"$OSSM_ROOT/scripts/wait-port.py" 127.0.0.1 6080 30
"$OSSM_ROOT/scripts/wait-port.py" 127.0.0.1 8000 30
install -d -m 0700 /run/ossm/client_temp /run/ossm/proxy_temp
exec /usr/sbin/nginx -c "$OSSM_ROOT/supervisor/nginx.conf" -g 'daemon off;'

