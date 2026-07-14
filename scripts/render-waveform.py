#!/usr/bin/env python3
import html
import sys
from pathlib import Path

kind, source_name, target_name = sys.argv[1:4]
rows = []
for line in Path(source_name).read_text(encoding="utf-8").splitlines():
    fields = line.split()
    if len(fields) >= 2:
        try:
            values = [float(value) for value in fields]
        except ValueError:
            continue
        rows.append((values[0], values[-1]))
if len(rows) < 2:
    raise SystemExit("waveform contains fewer than two samples")

width, height, pad = 1100, 620, 60
xs = [row[0] for row in rows]
ys = [row[1] for row in rows]
x_min, x_max = min(xs), max(xs)
y_min, y_max = min(ys), max(ys)
if x_min == x_max or y_min == y_max:
    raise SystemExit("waveform range is empty")
points = []
for x, y in rows:
    px = pad + (x - x_min) / (x_max - x_min) * (width - 2 * pad)
    py = height - pad - (y - y_min) / (y_max - y_min) * (height - 2 * pad)
    points.append(f"{px:.2f},{py:.2f}")
title = html.escape(f"PTC06 inverter — {kind}")
svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">
<rect width="100%" height="100%" fill="#101419"/>
<text x="{pad}" y="36" fill="#eef2f5" font-family="sans-serif" font-size="22">{title}</text>
<line x1="{pad}" y1="{height-pad}" x2="{width-pad}" y2="{height-pad}" stroke="#8292a2"/>
<line x1="{pad}" y1="{pad}" x2="{pad}" y2="{height-pad}" stroke="#8292a2"/>
<polyline fill="none" stroke="#78dce8" stroke-width="3" points="{' '.join(points)}"/>
<text x="{width-pad}" y="{height-18}" text-anchor="end" fill="#bcc8d1" font-family="monospace">x {x_min:.3g}..{x_max:.3g}</text>
<text x="{pad}" y="{height-18}" fill="#bcc8d1" font-family="monospace">Vout {y_min:.3g}..{y_max:.3g}</text>
</svg>'''
Path(target_name).write_text(svg, encoding="utf-8")

