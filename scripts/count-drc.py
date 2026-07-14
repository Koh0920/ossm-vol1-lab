#!/usr/bin/env python3
import sys
import xml.etree.ElementTree as ET

root = ET.parse(sys.argv[1]).getroot()
print(sum(1 for element in root.iter() if element.tag.rsplit("}", 1)[-1] == "item"))

