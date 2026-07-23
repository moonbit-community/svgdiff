# ADR 0108: Delegate proven rendering to Milky2018/svg 0.3.1

- Status: accepted
- Date: 2026-07-21
- Decision owners: svgdiff maintainers
- Supersedes: the renderer-ownership portions of ADRs 0054, 0055, 0056, 0061, 0062, and 0073

## Context

svgdiff previously materialized cascade winners, ordinary inherited values, computed paint values, shape and stroke geometry, mask content, and bounded `feOffset` graphs before calling the renderer. `Milky2018/svg@0.3.1` now implements the tested native forms. Retaining parallel implementations increases drift and can hide upstream regressions.

Focused source/canonical comparisons and product regressions show that 0.3.1 can own the tested cascade, ordinary inheritance, native numeric geometry and dash semantics, mask content paint, missing filter targets, and admitted valid filter graphs. They also reproduce remaining gaps in unsupported CSS Color 3 named colors, fractional and inherited paint opacity, percentage container opacity, authored length units, inline CSS geometry, compact point syntax, mask edge outcomes, detached-branch paint state, backdrop-aware group and mask composition, empty filters, and blend arithmetic.

## Decision

Delegate every passing rendering path above directly to `Milky2018/svg@0.3.1`. Delete the corresponding renderer-input normalizers and the project filter-graph raster evaluator. Keep analyzer-owned source facts, computed semantics, bounds, diagnostics, and causal evidence independent from rendering ownership.

Retain only adapters with a failing negative control under 0.3.1. The production renderer identity names those residual components explicitly. Valid filter graphs render upstream; svgdiff keeps only its empty-filter outcome adapter. Mask content paint also renders upstream, while mode/default/invalid-resource edges and container composition remain local.

The initial change retained profile `/26` as the conservative historical 0.3.0 baseline. A subsequent reproducible 0.3.1 recapture against Chromium 151 established profile `/27` with 94 exact and 47 divergent observations. No renderer Diagnostic is retired solely from an individual fixture becoming exact.

## Consequences

The project owns less duplicate raster code and its renderer identity matches the actual boundary. Upstream improvements can remove additional adapters only after a focused negative control becomes a positive passthrough test. An exposed upstream API is not enough; observed product pixels and report status must remain correct after removal.

Profile `/27` records the actual 0.3.1 dependency and browser identity. The historical `/26` result remains historical evidence rather than being rewritten in place.

## Evidence

- [`renderer_input_wbtest.mbt`](../../modules/svgdiff/engine/internal/rendered/normalization/renderer_input_wbtest.mbt)
- [`filter_semantics_wbtest.mbt`](../../modules/svgdiff/engine/internal/diff/filter_semantics_wbtest.mbt)
- [`group_compositor_wbtest.mbt`](../../modules/svgdiff/engine/internal/diff/group_compositor_wbtest.mbt)
- [`mask_semantics_wbtest.mbt`](../../modules/svgdiff/engine/internal/diff/mask_semantics_wbtest.mbt)
- [`blend_semantics_wbtest.mbt`](../../modules/svgdiff/engine/internal/diff/blend_semantics_wbtest.mbt)
- [Renderer evaluation](../renderer-evaluation.md)
