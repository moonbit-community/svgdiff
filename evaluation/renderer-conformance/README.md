# Renderer Conformance Comparison

Status: measurement baseline

Last verified: 2026-07-15

Conformance profile: `svgdiff-renderer-conformance-profile/12`

This evaluation compares raw `mizchi/svg@0.2.1` with the deterministic Chromium oracle. Its report shape remains `svgdiff-renderer-conformance/1`, independently from the conformance claim identified by `svgdiff-renderer-conformance-profile/12` in the production Comparison Profile. Engine regressions separately prove the project-owned style-precedence, ordinary-inheritance, CSS-computed-value, length used-value, stroke used-geometry, and basic-shape used-geometry normalizers because this adapter deliberately isolates the underlying dependency.

Fixtures are classified as geometry, paint, alpha, clipping, or compositing; geometry includes basic shapes, strokes, markers, transforms, viewport mappings, and authored units, while paint includes cascade precedence, inheritance, and computed CSS values. `supported` means the fixture exercises the current complete-eligible contract, `guarded` identifies a measured input that now has a production conformance Diagnostic, and `exploratory` measures behavior without expanding the contract. Six authored-unit fixtures cover absolute, percentage, viewport-relative, nested-viewport, stroke, and marker lengths; four canonical companions prove the browser equivalence of the first four. Eight cascade fixtures cover presentation-versus-inline origin, inline `!important`, stylesheet specificity, and stylesheet source order; all four authored cases have canonical companions. Inherited-stylesheet, CSS-wide fill, and custom-property/`currentColor` inputs each have a leaf-local canonical companion. The 74-case baseline therefore contains 32 exact and 42 divergent observations. Both images are normalized to premultiplied RGBA8 before measuring changed pixels, changed-pixel fraction, RMSE, and maximum channel delta.

Run `sh scripts/test-renderer-conformance.sh` to capture Chromium output, render the same sources through the pinned renderer, and compare the deterministic result with `baseline.v1.json`. The baseline records the browser version, DPR, CLI version, and a fixture source-set hash without retaining platform-specific User-Agent text. A baseline divergence is an observation, not an acceptance decision. Every divergence must be handled by the following roadmap item before it may influence the coverage contract.

The MoonBit adapter under `evaluation/renderer_adapter` exports raw pinned-renderer RGBA pixels. The evaluation-local Python decoder intentionally supports only the 8-bit, non-interlaced RGB/RGBA PNG profile already enforced by the browser-oracle validator.

## Divergence dispositions

[`dispositions.v1.json`](dispositions.v1.json) maps every divergent baseline case either to a production Diagnostic or to a reviewed production normalizer. The baseline and disposition set both record `svgdiff-renderer-conformance-profile/12`; validation rejects a missing or mismatched identity. Absolute, percentage, viewport-relative, and nested-viewport unit divergences use canonical fixture pairs through `length-used-value-normalizer@1`; presentation/inline origin, inline-important, stylesheet-specificity, and stylesheet-source-order divergences use canonical pairs through `style-precedence-normalizer@3`; the inherited-stylesheet divergence uses `ordinary-inheritance-normalizer@1`; and CSS-wide plus custom-property/`currentColor` divergences use `css-computed-value-normalizer@1`. Chromium must render each source/canonical pair identically, then the CLI must report complete computed equivalence and zero changed pixels. Other known fractional geometry, shape, stroke, marker, gradient, opacity, transform, and compositing divergences retain their dedicated guards.

Run `sh scripts/test-renderer-dispositions.sh` to require a one-to-one disposition for every divergence, execute each Diagnostic or normalizer proof through the production CLI, and confirm that exact supported fixtures do not acquire a new conformance guard. Other analyzer limitations remain independent. A future versioned conformance profile may replace a guard with a reviewed tolerance or adapter fix.

The separate [alternate-scale QA baseline](../alternate-scale/README.md) measures pinned-renderer scale curves and directional behavior. It is not a browser conformance oracle and cannot change a disposition or canonical report magnitude by itself.
