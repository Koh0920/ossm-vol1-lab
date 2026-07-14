#!/usr/bin/env bash
set -euo pipefail

rm -f /tmp/.X1-lock /tmp/.X11-unix/X1
exec /usr/bin/Xtigervnc :1 \
  -rfbport 5901 \
  -localhost \
  -SecurityTypes None \
  -geometry 1440x900 \
  -depth 24 \
  -AlwaysShared \
  -DisconnectClients=0 \
  -desktop "OSSM Vol.1 Lab" \
  -ac

