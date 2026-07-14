# Historical Influence Provenance Prototype

Status: archived experiment; production logic is implemented in `engine`

Last reviewed: 2026-07-14

This package answered the original design question and is retained as executable evidence. It is not a production interface and must not be treated as the current report contract. Current definitions live in [`docs/influence-provenance.md`](../../docs/influence-provenance.md) and [`docs/core-model.md`](../../docs/core-model.md).

Run the historical scenarios with:

```sh
moon run --target native prototype/influence_provenance
```

## Question answered

Can conservative Changed Fact token propagation produce a Cause Envelope that contains every injected actual cause across direct paint, before/after movement, filter expansion, compositing, and unknown-operation fallback, while refusing to claim completeness when coverage is incomplete?

The prototype answered yes for its modeled operations. It demonstrated the required widening discipline and showed that unsupported operations must revoke the completeness claim.

## Contents

- Scenarios 1 through 6 use a deterministic six-tile toy renderer to exercise direct paint, movement, filter expansion, compositing, unknown-operation fallback, and unsupported coverage.
- Scenario 7 is an early integration spike using `mizchi/svg@0.2.1` and `mizchi/pixelmatch@0.6.1`.
- [`NOTES.md`](NOTES.md) preserves the experimental observations and historical limitations.

The toy renderer does not parse or render SVG. The integration scenario validates early parser-to-scene-to-render-to-region plumbing, not complete renderer conformance or exact attribution.

No new product behavior should be added here. Future work belongs in `engine`, an explicit renderer experiment, or the project roadmap.
