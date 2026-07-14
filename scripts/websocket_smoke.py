#!/usr/bin/env python3
import base64
import os
import socket
import sys

host, port = sys.argv[1], int(sys.argv[2])
key = base64.b64encode(os.urandom(16)).decode("ascii")
request = (
    "GET /websockify HTTP/1.1\r\n"
    f"Host: {host}:{port}\r\n"
    "Upgrade: websocket\r\n"
    "Connection: Upgrade\r\n"
    f"Sec-WebSocket-Key: {key}\r\n"
    "Sec-WebSocket-Version: 13\r\n\r\n"
).encode("ascii")
with socket.create_connection((host, port), timeout=3) as connection:
    connection.sendall(request)
    response = connection.recv(4096)
if b" 101 " not in response.split(b"\r\n", 1)[0]:
    raise SystemExit(f"websocket upgrade failed: {response[:160]!r}")

