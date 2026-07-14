# Renderer Conformance Comparison

Status: measurement baseline

Last verified: 2026-07-14

This evaluation compares `mizchi/svg@0.2.1` with the deterministic Chromium oracle. It is outside the production engine and does not change Structured Report evidence or completeness claims.

Fixtures are classified as geometry, paint, alpha, clipping, or compositing. `supported` means the fixture exercises the current complete-eligible contract; `exploratory` means the renderer behavior is measured without expanding that contract. Both images are normalized to premultiplied RGBA8 before measuring changed pixels, changed-pixel fraction, RMSE, and maximum channel delta.

Run `sh scripts/test-renderer-conformance.sh` to capture Chromium output, render the same sources through the pinned renderer, and compare the deterministic result with `baseline.v1.json`. The baseline records the browser version, DPR, CLI version, and a fixture source-set hash without retaining platform-specific User-Agent text. A baseline divergence is an observation, not an acceptance decision. Every divergence must be handled by the following roadmap item before it may influence the coverage contract.

The MoonBit adapter under `evaluation/renderer_adapter` exports raw pinned-renderer RGBA pixels. The evaluation-local Python decoder intentionally supports only the 8-bit, non-interlaced RGB/RGBA PNG profile already enforced by the browser-oracle validator.
