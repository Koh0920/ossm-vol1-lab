#!/usr/bin/env bash
set -euo pipefail

umask 077
install -d -m 0700 "$XDG_RUNTIME_DIR" "$HOME/.config" "$OSSM_WORKSPACE"

rm -rf "$HOME/.xschem" "$HOME/.klayout"
cp -a "$OSSM_ROOT/immutable/home/.xschem" "$HOME/.xschem"
cp -a "$OSSM_ROOT/immutable/home/.klayout" "$HOME/.klayout"
install -d -m 0755 "$HOME/Desktop"
cp -a "$OSSM_ROOT/templates/Desktop/." "$HOME/Desktop/"
chmod 0755 "$HOME/Desktop"/*.desktop

install -d -m 0700 \
  "$OSSM_WORKSPACE/chapters" \
  "$OSSM_WORKSPACE/projects" \
  "$OSSM_WORKSPACE/runs" \
  "$OSSM_WORKSPACE/exports"

if [[ ! -e "$OSSM_WORKSPACE/.ossm-workspace-v1" ]]; then
  cp -an "$OSSM_ROOT/upstream-templates/chapters/." "$OSSM_WORKSPACE/chapters/"
  cp -an "$OSSM_ROOT/templates/chapters/." "$OSSM_WORKSPACE/chapters/"
  printf '%s\n' 'ossm-vol1-workspace-v1' > "$OSSM_WORKSPACE/.ossm-workspace-v1"
fi

cp "$OSSM_ROOT/templates/WORKSPACE_README.md" "$OSSM_WORKSPACE/README.md"
rm -f /run/ossm/desktop-ready

exec /usr/bin/supervisord -n -c "$OSSM_ROOT/supervisor/supervisord.conf"
