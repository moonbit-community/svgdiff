# Structured Report Determinism Evaluation

Status: current executable contract

Last verified: 2026-07-14

This suite verifies the [Structured Report determinism contract](../../docs/report-determinism.md) through independent release-CLI processes. Its versioned matrix covers equivalent, changed, inserted, deleted, resource-mediated, unsupported, multi-event, and non-default-viewport comparisons.

For each case, the validator runs default JSON and compact Agent JSON three times. Bytes must match within each output mode, both modes must decode to the same evidence, every report-local object ID must be globally unique, every declared report-local reference must resolve to exactly one object of the required kind, and every Atomic Difference must belong to exactly one Visual Event.

The suite includes negative controls for a duplicate ID, a dangling reference, a duplicate reference, a revoked Cause Envelope that omits one Changed Fact from its comparison fallback, and a complete event-region envelope contaminated by another event's valid fact. It does not claim cross-version or cross-platform byte identity, and it does not treat source-subject identity fields as report-local foreign keys.

Run:

```sh
sh scripts/test-report-determinism.sh
```
