#!/usr/bin/env bash
set -euo pipefail
input=$1
output=${2:-/foss/designs/runs/gds-report.json}
install -d -m 0700 "$(dirname "$output")"
klayout -b -r /opt/ossm/scripts/check-gds.py -rd input="$input" -rd output="$output"
python3 -c 'import json,sys; data=json.load(open(sys.argv[1])); assert data["top_cells"] and data["layers"]' "$output"
echo "GDS check: ok ($output)"

