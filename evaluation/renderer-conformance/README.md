# Renderer Conformance Comparison

Status: measurement baseline

Last verified: 2026-07-15

Conformance profile: `svgdiff-renderer-conformance-profile/8`

This evaluation compares raw `mizchi/svg@0.2.1` with the deterministic Chromium oracle. Its report shape remains `svgdiff-renderer-conformance/1`, independently from the conformance claim identified by `svgdiff-renderer-conformance-profile/8` in the production Comparison Profile. Engine regressions separately prove the project-owned style-precedence, length used-value, stroke used-geometry, and basic-shape used-geometry normalizers because this adapter deliberately isolates the underlying dependency.

Fixtures are classified as geometry, paint, alpha, clipping, or compositing; the geometry category includes basic shapes, strokes, markers, coordinate transforms, viewport mappings, and authored length units. `supported` means the fixture exercises the current complete-eligible contract, `guarded` identifies a measured input that now has a production conformance Diagnostic, and `exploratory` measures behavior without expanding the contract. The transform set independently exercises `matrix`, `translate`, `scale`, quadrant `rotate`, `skewX`, and `skewY`; the first four integer axis-transform fixtures are exact and admitted, while the two skew fixtures remain guarded. Root `none`, meet, slice, and nested viewport fixtures are exact. Zero-radius circle, fill-only line, and zero-width stroke behavior are exact; positive circle, ellipse, rounded-rectangle, filled polyline/polygon, active caps/joins/dashes, transformed non-scaling-stroke pixels, and marker fixtures diverge and are guarded. Six authored-unit fixtures cover absolute, percentage, viewport-relative, nested-viewport, stroke, and marker lengths; four canonical user-unit companions independently prove the browser equivalence of the first four. The 60-case baseline therefore contains 25 exact and 35 divergent observations. Both images are normalized to premultiplied RGBA8 before measuring changed pixels, changed-pixel fraction, RMSE, and maximum channel delta.

Run `sh scripts/test-renderer-conformance.sh` to capture Chromium output, render the same sources through the pinned renderer, and compare the deterministic result with `baseline.v1.json`. The baseline records the browser version, DPR, CLI version, and a fixture source-set hash without retaining platform-specific User-Agent text. A baseline divergence is an observation, not an acceptance decision. Every divergence must be handled by the following roadmap item before it may influence the coverage contract.

The MoonBit adapter under `evaluation/renderer_adapter` exports raw pinned-renderer RGBA pixels. The evaluation-local Python decoder intentionally supports only the 8-bit, non-interlaced RGB/RGBA PNG profile already enforced by the browser-oracle validator.

## Divergence dispositions

[`dispositions.v1.json`](dispositions.v1.json) maps every divergent baseline case either to a production Diagnostic or to a reviewed production normalizer. The baseline and disposition set both record `svgdiff-renderer-conformance-profile/8`; validation rejects a missing or mismatched identity. Absolute, percentage, viewport-relative, and nested-viewport unit divergences use canonical fixture pairs: Chromium must render each pair identically, then the CLI must report complete computed equivalence and zero changed pixels through `length-used-value-normalizer@1`. Fractional geometry, curved shapes, filled point shapes, active stroke outlines/joins/dashes/non-scaling-stroke, marker placement/rasterization, referenced gradients, fractional leaf opacity, and general affine transform rasterization keep numeric source/computed evidence and the pinned-renderer measurement, but rendered coverage is limited. Group opacity remains limited by `group_opacity_compositing_unsupported`.

Run `sh scripts/test-renderer-dispositions.sh` to require a one-to-one disposition for every divergence, execute each Diagnostic or normalizer proof through the production CLI, and confirm that exact supported fixtures do not acquire a new conformance guard. Other analyzer limitations remain independent. A future versioned conformance profile may replace a guard with a reviewed tolerance or adapter fix.

The separate [alternate-scale QA baseline](../alternate-scale/README.md) measures pinned-renderer scale curves and directional behavior. It is not a browser conformance oracle and cannot change a disposition or canonical report magnitude by itself.
