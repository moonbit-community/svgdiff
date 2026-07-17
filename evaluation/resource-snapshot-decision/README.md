# Resource Snapshot Decision Evidence

Status: accepted future boundary; no generalized bundle or prefetcher is implemented

Last verified: 2026-07-17

[`decision.v1.json`](decision.v1.json) makes the [General Resource Snapshot Bundle Boundary](../../docs/general-resource-snapshot-bundles.md) machine-checkable. It preserves current opaque raster bundle behavior, separates rendering snapshots from acquisition provenance, and permanently excludes comparison-time I/O.

The artifact adds no URL resolver, bundle API, prefetcher, decoder, report field, or executable profile. Run its dependency-free validator with:

```sh
sh scripts/test-resource-snapshot-decision.sh
```
