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

## GitHub Source release artifact

The Store imports releases from GitHub Source. Build the small signed recipe
artifact below; the OCI image remains external and digest-pinned in
`capsule.toml`.

```bash
SOURCE_DATE_EPOCH="$(git show -s --format=%ct HEAD)" \
  node scripts/package-release-capsule.mjs \
  .tmp/ossm-vol1-lab-0.1.1-linux-amd64.capsule \
  ~/.ato/keys/publisher-signing-key.json
ato sign --key ~/.ato/keys/publisher-signing-key.json \
  .tmp/ossm-vol1-lab-0.1.1-linux-amd64.capsule
```

See `docs/rfcs/draft/OSSM_VOL1_LAB_SPEC.md` for the complete contract and
acceptance criteria.

Browser-based Open Source Silicon Magazine Vol.1 CMOS design lab for Ato
