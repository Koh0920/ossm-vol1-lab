#!/usr/bin/env bash
set -euo pipefail

check() {
  local package=$1 expected=$2 actual
  actual=$(dpkg-query -W -f='${Version}' "$package")
  [[ "$actual" == "$expected" ]] || {
    echo "$package version mismatch: expected=$expected actual=$actual" >&2
    return 1
  }
}

check xschem 3.4.4-1
check ngspice 42+ds-3build1
check klayout 0.28.16-0ubuntu0.24.04.1
check netgen-lvs 1.5.133-1.2
check tigervnc-standalone-server 1.13.1+dfsg-2build2
check novnc 1:1.3.0-2
check websockify 0.10.0+dfsg1-5build2
check nginx-light 1.24.0-2ubuntu7.13
check supervisor 4.2.5-1ubuntu0.1

grep -Fxq 'openeda=0259d6e37202eb6bc6f5053891698f24de12b07d' /opt/ossm/immutable/PDK_COMMITS
grep -Fxq 'openrule1um=7b3c4c4d8feca8e94388bb856a42ee4caf8f8763' /opt/ossm/immutable/PDK_COMMITS
grep -Fxq 'anagix-loader=cb89e35f742e863dde64c7b047e7f369cb1bce0a' /opt/ossm/immutable/PDK_COMMITS
echo 'toolchain: verified'

