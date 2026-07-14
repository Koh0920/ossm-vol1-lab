#!/usr/bin/env bash
set -euo pipefail

input=$1
mode=${2:-}
runs=/foss/designs/runs
report="$runs/drc-report.lyrdb"
log="$runs/drc.log"
install -d -m 0700 "$runs"

if [[ "$mode" == "--negative" ]]; then
  input="$runs/drc-negative.gds"
  klayout -b -r /opt/ossm/scripts/write-negative-gds.py -rd output="$input"
fi

rm -f "$report" "$log"
KLAYOUT_HOME=/home/ato/.klayout klayout -b \
  -r /opt/ossm/immutable/openrule.drc \
  -rd input="$input" \
  -rd report="$report" >"$log" 2>&1
test -s "$report"
count=$(/opt/ossm/scripts/count-drc.py "$report")

if [[ "$mode" == "--negative" ]]; then
  (( count > 0 )) || { echo "negative DRC fixture was not detected" >&2; exit 1; }
  echo "DRC negative test: detected $count violation(s)"
else
  (( count == 0 )) || { echo "DRC failed: $count violation(s); report=$report" >&2; exit 1; }
  echo "DRC: zero violations"
fi

