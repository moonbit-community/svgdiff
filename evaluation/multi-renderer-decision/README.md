# Multi-Renderer Decision Evidence

Status: accepted experiment semantics; no matrix product mode

Last verified: 2026-07-17

[`decision.v1.json`](decision.v1.json) makes the [multi-renderer and browser profile boundary](../../docs/multi-renderer-profiles.md) machine-checkable. It supports same-target profile sensitivity and same-profile renderer conformance as different edge types, permits full matrices only as collections of those edges, and rejects direct diagonal attribution or majority truth.

The artifact adds no renderer, browser fixture, report field, or executable profile. Run its dependency-free validator with:

```sh
sh scripts/test-multi-renderer-decision.sh
```
