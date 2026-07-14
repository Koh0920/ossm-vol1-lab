import pya

layout = pya.Layout()
layout.dbu = 0.001
cell = layout.create_cell("DRC_NEGATIVE")
metal1 = layout.layer(8, 0)
cell.shapes(metal1).insert(pya.Box(0, 0, 2000, 2000))
cell.shapes(metal1).insert(pya.Box(2500, 0, 4500, 2000))
layout.write(output)

