# Renderer Conformance Comparison

Status: measurement baseline

Last verified: 2026-07-22

Conformance profile: `svgdiff-renderer-conformance-profile/27`

This evaluation compares raw `Milky2018/svg@0.3.1` with the deterministic Chromium oracle. Its report shape remains `svgdiff-renderer-conformance/1`, independently from the conformance claim identified by `svgdiff-renderer-conformance-profile/27` in the production Comparison Profile. Engine regressions separately prove the project-owned normalizers, compositors, and guards because this adapter deliberately isolates the underlying dependency.

This is the current same-profile cross-target precedent, not an implemented [multi-renderer matrix](../../docs/multi-renderer-profiles.md). Its exact fixture pairs and reviewed dispositions inform one conformance profile; they do not establish renderer majority, cross-profile invariance, or a product-level cross-browser comparison.

Fixtures are classified as geometry, paint, alpha, clipping, or compositing. `supported` means the fixture exercises the current complete-eligible contract and `guarded` identifies a measured input that has a production Diagnostic. The 141-case `Milky2018/svg@0.3.1` baseline contains 94 exact and 47 divergent observations against Chromium 151. Compared with profile `/26`, nine formerly divergent fixtures are exact and none regress: 90-degree rotation, two basic pattern mappings, inherited and canonical paint order, butt and square stroke caps, dash arrays, and non-scaling stroke. Gradients, remaining patterns, embedded PNG/JPEG composition, fractional alpha, polygon clip rules, curved/point/stroke/marker rasterization, skew, and authored-unit handling remain divergent. Both images are normalized to premultiplied RGBA8 before measuring changed pixels, changed-pixel fraction, RMSE, and maximum channel delta. Declared browser source/canonical pairs normally require byte equality; the blend-grid exclusion companion alone declares a one-channel rounding allowance because current Chromium produces red `0x90` while the project compositor's W3C calculation produces `0x8f`.

Run `sh scripts/test-renderer-conformance.sh` to capture Chromium output, render the same sources through the pinned renderer, and compare the deterministic result with `baseline.v1.json`. The baseline records the browser version, DPR, CLI version, and a fixture source-set hash without retaining platform-specific User-Agent text. A baseline divergence is an observation, not an acceptance decision. Every divergence must be handled by the following roadmap item before it may influence the coverage contract.

The MoonBit adapter under `modules/svgdiff/evaluation/renderer_adapter` exports raw pinned-renderer RGBA pixels. The evaluation-local Python decoder intentionally supports only the 8-bit, non-interlaced RGB/RGBA PNG profile already enforced by the browser-oracle validator.

## Divergence dispositions

[`dispositions.v1.json`](dispositions.v1.json) maps every divergent baseline case to a production Diagnostic, reviewed normalizer, or reviewed product compositor. The baseline and disposition set both record `svgdiff-renderer-conformance-profile/27`; validation rejects a missing or mismatched identity. The profile retains conservative transform, pattern, and stroke guards even where individual fixtures became exact; broader claims require broader proof. PNG and JPEG remain explicitly unavailable for final rendering even though the dependency exposes a host image resolver and production separately decodes their intrinsic pixels; wiring the bounded resource bundle into that resolver is future work. Other known fractional geometry, gradient, pattern, clip, shape, stroke, marker, and transform divergences retain their dedicated guards.

Run `sh scripts/test-renderer-dispositions.sh` to require a one-to-one disposition for every divergence, execute each Diagnostic, normalizer, or compositor proof through the production CLI, and confirm that exact supported fixtures do not acquire a new conformance guard. Other analyzer limitations remain independent. A future versioned conformance profile may replace a guard with a reviewed tolerance or adapter fix.

The aggregate [M2 renderer and coverage safety gate](../m2-renderer-coverage-gate/README.md) additionally checks that these dispositions connect to encountered capability metadata, coverage proof, status composition, and unsupported-input equality guards. This baseline alone cannot close that product claim.

The separate [alternate-scale QA baseline](../alternate-scale/README.md) measures pinned-renderer scale curves and directional behavior. It is not a browser conformance oracle and cannot change a disposition or canonical report magnitude by itself.
