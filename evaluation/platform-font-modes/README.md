# Platform Font Mode Decision Evidence

Status: accepted boundary; no platform backend

Last verified: 2026-07-17

[`decision.v1.json`](decision.v1.json) makes the [platform-native font rendering boundary](../../docs/platform-native-font-modes.md) machine-checkable. It distinguishes the future project canonical runtime, closed-bundle external platform observations, ambient exploratory captures, and the permanently rejected canonical platform mode.

The artifact contains no native rendering output and does not add a platform profile. Run its dependency-free validator with:

```sh
sh scripts/test-platform-font-modes.sh
```

The gate also rejects any platform font backend, native font dependency, report-schema field, CLI option, or default-CI integration in the current product.
