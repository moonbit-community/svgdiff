# Interaction State Decision Evidence

Status: accepted future profile boundary; not implemented

Last verified: 2026-07-17

[`decision.v1.json`](decision.v1.json) makes the [interaction-state profile boundary](../../docs/interaction-state-profiles.md) machine-checkable. It separates declared checkpoint inputs, derived canonical pseudo-class state, and target-local browser action observations while preserving the current interaction-free report.

The artifact adds no selector grammar, state profile, browser action, report field, or product behavior. Run its dependency-free validator with:

```sh
sh scripts/test-interaction-state-decision.sh
```
