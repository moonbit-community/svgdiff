# Renderer Conformance Comparison

Status: measurement baseline

Last verified: 2026-07-14

Conformance profile: `svgdiff-renderer-conformance-profile/1`

This evaluation compares `mizchi/svg@0.2.1` with the deterministic Chromium oracle. Its report shape remains `svgdiff-renderer-conformance/1`, independently from the conformance claim identified by `svgdiff-renderer-conformance-profile/1` in the production Comparison Profile.

Fixtures are classified as geometry, paint, alpha, clipping, or compositing. `supported` means the fixture exercises the current complete-eligible contract, `guarded` identifies a measured input that now has a production conformance Diagnostic, and `exploratory` measures behavior without expanding the contract. Both images are normalized to premultiplied RGBA8 before measuring changed pixels, changed-pixel fraction, RMSE, and maximum channel delta.

Run `sh scripts/test-renderer-conformance.sh` to capture Chromium output, render the same sources through the pinned renderer, and compare the deterministic result with `baseline.v1.json`. The baseline records the browser version, DPR, CLI version, and a fixture source-set hash without retaining platform-specific User-Agent text. A baseline divergence is an observation, not an acceptance decision. Every divergence must be handled by the following roadmap item before it may influence the coverage contract.

The MoonBit adapter under `evaluation/renderer_adapter` exports raw pinned-renderer RGBA pixels. The evaluation-local Python decoder intentionally supports only the 8-bit, non-interlaced RGB/RGBA PNG profile already enforced by the browser-oracle validator.

## Divergence dispositions

[`dispositions.v1.json`](dispositions.v1.json) maps every divergent baseline case to a production Diagnostic. The baseline and disposition set both record `svgdiff-renderer-conformance-profile/1`; validation rejects a missing or mismatched identity. Fractional geometry, referenced gradients, and fractional leaf opacity keep numeric source/computed evidence and the pinned-renderer measurement, but rendered coverage is limited. Group opacity remains limited by `group_opacity_compositing_unsupported`.

Run `sh scripts/test-renderer-dispositions.sh` to require a one-to-one disposition for every divergence, execute each guard through the production CLI, and confirm that exact supported fixtures do not acquire a new conformance guard. Other analyzer limitations remain independent. A future versioned conformance profile may replace a guard with a reviewed tolerance or adapter fix.

The separate [alternate-scale QA baseline](../alternate-scale/README.md) measures pinned-renderer scale curves and directional behavior. It is not a browser conformance oracle and cannot change a disposition or canonical report magnitude by itself.
