# OSSM Vol.1 Lab Capsule Specification

Status: draft  
Version: 0.1.0

## Goal

From an Ato staging link, a user can edit the PTC06 CMOS inverter schematic,
run DC and transient simulation, inspect waveforms, open the GDS, run DRC and
LVS, and download a ZIP export.

## Runtime contract

- The only public service is the web gateway on TCP 3000.
- TigerVNC listens on `127.0.0.1:5901`.
- websockify listens on `127.0.0.1:6080`.
- nginx proxies `/websockify` and the fixed gateway endpoints.
- All runtime processes execute as UID/GID 1000.
- Runtime egress is empty.
- `/foss/designs` is the only persistent path.
- State sharing is exclusive; a second concurrent writer is rejected by Ato.

Persistent state is guaranteed only for the same user on the same runner.
Different users on the same runner must receive different state. Runner
migration is outside the v0.1 contract.

## Reproducibility contract

`TOOLCHAIN.lock` pins the base image, Ubuntu snapshot, package versions, and
upstream commits. Upstream setup scripts are reference material and are not
executed wholesale. `apt upgrade`, unpinned clones, and `git pull` are banned.

The Docker context excludes `capsule.toml`, lock files, docs, tests, and Git
metadata. The Dockerfile uses explicit `COPY` statements. Updating the image
digest in `capsule.toml` therefore cannot trigger or change the image build.

`ato.lock.json` is the canonical resolved execution contract.
`capsule.lock.json` remains in release archives only as a legacy archive
verification input. Release packaging requires `SOURCE_DATE_EPOCH`, embeds an
Ed25519 archive-boundary signature, and emits a populated SPDX 2.3 SBOM. A
second detached signature authenticates the immutable GitHub Release asset;
detached signing must not alter the capsule SHA-256.

The declared 10 GB disk requirement includes the OCI image, container writable
layer, persistent workspace, and temporary space needed while creating or
restoring a ready-state snapshot.

## Process model

`tini` starts supervisord. Processes are ordered as Xvnc, dbus/XFCE,
websockify, the Python health/download gateway, then nginx. Dependency wrappers
wait for the prior service instead of treating supervisor start as readiness.

## Health contract

`GET /healthz` checks supervisor state, internal TCP ports, the desktop-ready
sentinel, workspace write/delete, required commands, and the expected PDK
marker. It does not perform a full EDA run.

`labctl doctor --full` additionally checks the X session, noVNC WebSocket
handshake, ngspice batch simulation, PDK files, GDS parsing, and DRC smoke.

## Export contract

`labctl export` accepts no user path. It reads only `chapters`, `projects`, and
`runs`, rejects escaping symlinks, enforces file-count and size limits, writes
to a temporary file, computes SHA-256, and atomically replaces
`exports/latest.zip`. The gateway exposes only `latest.zip` and its digest with
`Content-Disposition: attachment` and `Cache-Control: no-store`.

## Acceptance

1. noVNC supports mouse, keyboard, reconnect, and ten minutes of operation.
2. DC and transient simulations create expected data and visible waveforms.
3. The positive GDS reports zero DRC violations and a unique LVS match.
4. Deliberate spacing and netlist mismatches fail.
5. Export downloads to the host and matches the published SHA-256.
6. UID 1000 can create, update, and read state across stop/start; no state file
   is owned by root.
7. Different users cannot observe each other's workspace.
8. VNC and websockify are not externally reachable.
9. Updating `capsule.toml` with the GHCR digest does not rebuild the image.
