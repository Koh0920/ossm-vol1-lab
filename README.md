# Open Source Silicon Magazine Vol.1 Lab

An Ato capsule for learning the CMOS inverter flow with Xschem, ngspice,
KLayout, Netgen, and the OpenRule1um PDK in a browser-based desktop.

The first release is intentionally limited to `linux/amd64` and the PTC06
inverter exercise. The runtime has no external network access and runs as UID
1000. Only `/foss/designs` is persistent.

## Development

```bash
docker build --platform linux/amd64 -t ossm-vol1-lab:dev .
docker run --rm --platform linux/amd64 -p 3000:3000 ossm-vol1-lab:dev
curl --fail http://127.0.0.1:3000/healthz
```

Open <http://127.0.0.1:3000> after the health check succeeds.

## Capsule checks

```bash
ato validate .
ato lock .
ato build .
```

`ato.lock.json` is the canonical resolved execution contract and pins the OCI
image used by Ato. `capsule.lock.json` is retained only for compatibility with
the current archive verifier; it must not be used as runtime resolution input.
The capsule requests 10 GB of runner disk so the OCI image, writable layer,
workspace state, and snapshot staging area have explicit headroom.

## GitHub Source release artifact

The Store imports releases from GitHub Source. The release uses two signatures
with separate responsibilities:

- embedded `signature.json` authenticates `capsule.toml` and
  `payload.tar.zst` at the capsule archive boundary;
- detached `.capsule.sig`, produced by `ato sign`, authenticates the immutable
  GitHub Release asset for GitHub Source verification.

Detached signing never mutates the capsule. The recipe artifact remains small;
the OCI image stays external and digest-pinned in `capsule.toml`. Packaging also
writes a standalone `.sbom.spdx.json` release asset containing the OCI/base
image digests, pinned Ubuntu packages, and upstream PDK commits.

```bash
SOURCE_DATE_EPOCH="$(git show -s --format=%ct HEAD)" \
  node scripts/package-release-capsule.mjs \
  .tmp/ossm-vol1-lab-0.1.4-linux-amd64.capsule \
  ~/.ato/keys/publisher-signing-key.json
ato sign --key ~/.ato/keys/publisher-signing-key.json \
  .tmp/ossm-vol1-lab-0.1.4-linux-amd64.capsule

scripts/test-release-reproducibility.sh \
  ~/.ato/keys/publisher-signing-key.json
```

See `docs/rfcs/draft/OSSM_VOL1_LAB_SPEC.md` for the complete contract and
acceptance criteria.

Browser-based Open Source Silicon Magazine Vol.1 CMOS design lab for Ato
