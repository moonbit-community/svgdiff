# Foreign Content Decision Evidence

Status: accepted future boundary; no foreign-content layout is implemented

Last verified: 2026-07-17

[`decision.v1.json`](decision.v1.json) makes the [Static foreignObject Layout Boundary](../../docs/foreign-object-layout-boundary.md) machine-checkable. It requires a deterministic host-language engine for general canonical support while allowing a smaller closed evaluator without confusing it with general XHTML/CSS or browser authority.

The artifact adds no parser, layout engine, browser, dependency, report field, or executable profile. Run its dependency-free validator with:

```sh
sh scripts/test-foreign-content-decision.sh
```
