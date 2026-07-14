#!/usr/bin/env python3
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

source, target = map(Path, sys.argv[1:3])
text = ET.parse(source).getroot().findtext("text")
if not text:
    raise SystemExit("OpenRule1um DRC deck has no text")
needle = 'report("Output database")'
if needle not in text:
    raise SystemExit("OpenRule1um DRC report declaration changed")
text = text.replace(needle, 'report("OpenRule1um DRC", $report)', 1)
target.write_text("source($input)\n" + text, encoding="utf-8")

