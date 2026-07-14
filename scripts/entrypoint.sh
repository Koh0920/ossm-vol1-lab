#!/usr/bin/env bash
set -euo pipefail

umask 077

# The OCI runtime normally enters as uid/gid 1000, while Ready-State compose
# import starts the image entrypoint as root and lets supervisord drop to `ato`.
# Fresh tmpfs mounts are root-owned, so normalize only the writable runtime
# surfaces before that privilege drop. Immutable image content stays untouched.
if [[ "$(id -u)" == "0" ]]; then
  install -d -o 1000 -g 1000 -m 0755 /run/ossm
  install -d -o 1000 -g 1000 -m 0700 \
    "$XDG_RUNTIME_DIR" \
    "$HOME" \
    "$HOME/.config" \
    "$OSSM_WORKSPACE"
  # supervisord re-opens /dev/fd/{1,2} after dropping to `ato`. Ready-State's
  # guest agent creates those backing log files as root, so hand ownership of
  # the inherited output descriptors to the runtime uid as well.
  chown 1000:1000 "/proc/$$/fd/1" "/proc/$$/fd/2" 2>/dev/null || true
else
  install -d -m 0700 "$XDG_RUNTIME_DIR" "$HOME/.config" "$OSSM_WORKSPACE"
fi

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
