#!/usr/bin/env bash
set -euo pipefail

for script in scripts/*.sh scripts/labctl; do
  bash -n "$script"
done
python3 -m compileall -q gateway scripts tests
python3 -m unittest discover -s tests/unit -v

if grep -Eq '^COPY[[:space:]]+\.[[:space:]]' Dockerfile; then
  echo 'Dockerfile must not use COPY . .' >&2
  exit 1
fi
for ignored in capsule.toml capsule.lock.json docs/ .git/ tests/; do
  grep -Fxq "$ignored" .dockerignore || { echo ".dockerignore misses $ignored" >&2; exit 1; }
done

expected=$(shasum -a 256 schemas/workspace-v1.json | awk '{print $1}')
grep -Fq "schema_id = \"sha256:$expected\"" capsule.toml

if grep -A30 '^  push:' .github/workflows/build-image.yml | grep -q 'capsule.toml'; then
  echo 'capsule.toml must not trigger the image workflow' >&2
  exit 1
fi
echo 'static tests: ok'

