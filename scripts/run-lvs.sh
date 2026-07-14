#!/usr/bin/env bash
set -euo pipefail

directory=$1
mode=${2:-}
runs=/foss/designs/runs
report="$runs/lvs-report.log"
layout="$directory/layout.spice"
install -d -m 0700 "$runs"
if [[ "$mode" == "--negative" ]]; then
  layout="$directory/layout-mismatch.spice"
fi

rm -f "$report"
netgen -batch lvs \
  "$directory/reference.spice inverter" \
  "$layout inverter" \
  nosetup "$report" >/dev/null
test -s "$report"

if [[ "$mode" == "--negative" ]]; then
  if grep -q 'Circuits match uniquely' "$report"; then
    echo "negative LVS fixture unexpectedly matched" >&2
    exit 1
  fi
  echo "LVS negative test: mismatch detected"
else
  grep -q 'Circuits match uniquely' "$report" || { echo "LVS mismatch; report=$report" >&2; exit 1; }
  echo "LVS: circuits match uniquely"
fi

