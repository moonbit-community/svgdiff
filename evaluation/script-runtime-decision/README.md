# Script Runtime Decision Evidence

Status: accepted canonical non-goal; external observation not implemented

Last verified: 2026-07-17

[`decision.v1.json`](decision.v1.json) makes the [SVG script execution boundary](../../docs/script-execution-boundary.md) machine-checkable. It preserves the current secure-static no-execution profile, separates sandbox security from determinism, and permits only a future target-local external observation with closed identity and replay evidence.

The artifact adds no runtime, browser, dependency, report field, or executable profile. Run its dependency-free validator with:

```sh
sh scripts/test-script-runtime-decision.sh
```
