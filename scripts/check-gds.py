import json
import os
import pya

layout = pya.Layout()
layout.read(input)
top_cells = sorted(cell.name for cell in layout.top_cells())
layers = sorted(
    (layout.get_info(index).layer, layout.get_info(index).datatype)
    for index in layout.layer_indexes()
)
if not top_cells:
    raise RuntimeError("GDS has no top cell")
if not layers:
    raise RuntimeError("GDS has no layers")
with open(output, "w", encoding="utf-8") as stream:
    json.dump({"top_cells": top_cells, "layers": layers}, stream, sort_keys=True)

