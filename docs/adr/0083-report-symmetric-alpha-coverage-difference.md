# Report symmetric alpha-coverage difference

## Context

Final changed pixels and RGBA error conflate geometry, alpha coverage, RGB color, and compositing. Painted-boundary displacement reports how far sampled support edges move but not how much painted alpha area changes. The research metric already recommends alpha-only L1 difference normalized by alpha union.

## Decision

Add nullable `painted_coverage_difference` evidence to Difference Magnitude. A measured object uses method ID `symmetric_alpha_coverage_l1_over_union/v1` and records before coverage, after coverage, absolute alpha difference, and alpha union in CSS square pixels plus their bounded ratio.

For every isolated pinned-renderer RGBA8 pixel, normalize alpha to `[0, 1]`. Sum each side's alpha, `abs(alpha_before - alpha_after)`, and `max(alpha_before, alpha_after)`, then divide the area sums by Comparison DPR squared. The fraction is absolute difference divided by union, or measured zero when the union is zero. Swapping inputs swaps only the named before/after areas; absolute difference, union, and fraction remain unchanged. Equal alpha coverage is zero regardless of RGB color, while disjoint or one-empty coverage is one.

Reuse one bounded isolated before/after render pair to compute both painted-boundary and coverage observations for an alignment. Attach coverage evidence to supported two-sided entity differences with a different computed outcome. Resource-role, presence, unaligned, unsupported-isolation, dimension-mismatch, and budget-exhausted cases remain null. The object is quantized alpha evidence, not analytic vector area, continuous isocontour integration, color error, visibility, or importance.

## Consequences

Agents can distinguish unchanged coverage under a color-only change from changed painted area under geometry or alpha changes. Absolute CSS area remains available beside the normalized fraction, preventing a tiny and a canvas-sized disjoint change from collapsing to the same evidence vector.

The required nullable object advances Structured Report schema to `1.38` and module version to `0.5.18`. Renderer identity, conformance profile `/25`, ordering policy, Diagnostics, and v2 ordering tuples remain unchanged. Event-local perceptual color remains a separate roadmap item.
