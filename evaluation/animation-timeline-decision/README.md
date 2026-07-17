# Animation Timeline Decision Evidence

Status: accepted future boundary; no timeline is implemented

Last verified: 2026-07-17

[`decision.v1.json`](decision.v1.json) makes the [Animation Timeline Model](../../docs/animation-timeline-model.md) machine-checkable. It preserves the current animation-disabled profile, fixes shared logical time as the default synchronization question, and prevents finite sampling or browser delay from becoming an interval-equality claim.

The artifact adds no evaluator, browser, dependency, report field, or executable profile. Run its dependency-free validator with:

```sh
sh scripts/test-animation-timeline-decision.sh
```
