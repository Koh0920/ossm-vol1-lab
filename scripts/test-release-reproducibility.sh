#!/usr/bin/env bash
set -euo pipefail

key=${1:?usage: test-release-reproducibility.sh <publisher-signing-key.json>}
ato_bin=${ATO_BIN:-ato}
epoch=${SOURCE_DATE_EPOCH:-$(git show -s --format=%ct HEAD)}
work=.tmp/reproducibility
first=$work/first.capsule
second=$work/second.capsule

rm -rf "$work"
mkdir -p "$work"

SOURCE_DATE_EPOCH=$epoch node scripts/package-release-capsule.mjs "$first" "$key"
SOURCE_DATE_EPOCH=$epoch node scripts/package-release-capsule.mjs "$second" "$key"

cmp "$first" "$second"
cmp "$work/first.sbom.spdx.json" "$work/second.sbom.spdx.json"

before=$(shasum -a 256 "$first" | awk '{print $1}')
"$ato_bin" sign --key "$key" --out "$work/first.capsule.sig" "$first"
after=$(shasum -a 256 "$first" | awk '{print $1}')
[[ "$before" == "$after" ]] || {
  echo "detached signing mutated the capsule artifact" >&2
  exit 1
}

echo "reproducibility: capsule=$before sbom=$(shasum -a 256 "$work/first.sbom.spdx.json" | awk '{print $1}')"
