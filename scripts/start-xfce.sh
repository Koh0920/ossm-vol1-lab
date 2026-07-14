#!/usr/bin/env bash
set -euo pipefail

for _ in $(seq 1 100); do
  if xdpyinfo -display "$DISPLAY" >/dev/null 2>&1; then
    break
  fi
  sleep 0.1
done
xdpyinfo -display "$DISPLAY" >/dev/null

exec dbus-run-session -- bash -c '
  startxfce4 >/run/ossm/xfce.log 2>&1 &
  child=$!
  for _ in $(seq 1 100); do
    if pgrep -u "$(id -u)" -x xfce4-panel >/dev/null; then
      touch /run/ossm/desktop-ready
      break
    fi
    sleep 0.2
  done
  test -e /run/ossm/desktop-ready
  wait "$child"
'

