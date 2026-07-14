# OSSM Vol.1 workspace

Start with `chapters/01-inverter`.

- Open `inverter.sch` with Xschem.
- Run `labctl simulate dc` and `labctl simulate transient`.
- Open `inverter.gds` with KLayout.
- Run `labctl check drc` and `labctl check lvs`.
- Run `labctl export`, then use the download button above the desktop.

Only this workspace persists. Installed tools and PDK configuration are reset
from the immutable image each time the capsule starts.

