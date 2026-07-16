# Structured Report Determinism Evaluation

Status: current executable contract

Last verified: 2026-07-16

This suite verifies the [Structured Report determinism contract](../../docs/report-determinism.md) through independent release-CLI processes. Its versioned matrix covers equivalent, changed, inserted, deleted, resource-mediated, unsupported, multi-event, and non-default-viewport comparisons.

For each case, the validator runs default JSON and compact Agent JSON three times. Bytes must match within each output mode, both modes must decode to the same evidence, every report-local object ID must be globally unique, every declared report-local reference must resolve to exactly one object of the required kind, every Atomic Difference must belong to exactly one Visual Event, and the Impact Assessment frontier plus domination witnesses must partition all candidate events.

The suite includes negative controls for a duplicate ID, a dangling reference, a duplicate reference, a dangling Impact Assessment event reference, a valid but wrong Impact Atomic Difference reference, a resource difference attached to an entity alignment, a revoked Cause Envelope that omits one Changed Fact from its comparison fallback, and a complete event-region envelope contaminated by another event's valid fact. It does not treat source-subject identity fields as report-local foreign keys.

CI additionally builds the same revision in native release mode on the supported determinism matrix: Ubuntu 24.04 x64, Windows Server 2025 x64, and macOS 15 arm64. Each runner writes a platform-neutral `svgdiff-determinism-bundle/1` containing the exact default and compact bytes for all eight cases. The aggregation job requires all three named bundles and compares the manifest, complete inventory, digests, and file bytes. Platform identity and toolchain observations remain outside the compared bundle.

This gate establishes byte identity for the versioned corpus across the declared matrix. It is not exhaustive proof over arbitrary SVG input or a cross-version guarantee. The release workflow reuses the same bundle protocol as a publication gate; release packaging and provenance remain separate evidence rather than being inferred from report identity.

Run:

```sh
sh scripts/test-report-determinism.sh
sh scripts/test-cross-platform-determinism.sh
```
