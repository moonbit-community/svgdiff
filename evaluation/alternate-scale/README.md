# Alternate-Scale Renderer QA

Status: renderer QA baseline

Last verified: 2026-08-19

This evaluation rerenders focused SVG pairs through `Milky2018/svg@0.5.2` at integer output scales 1, 2, 4, and 8. It records premultiplied-RGBA8 response curves and compares positive-versus-negative micro-movements in the separate `svgdiff-alternate-scale-renderer-qa/1` artifact. The checked-in measurements record the current response at each scale without entering canonical report semantics.

Run `sh scripts/test-alternate-scale-qa.sh` to reproduce [`baseline.v1.json`](baseline.v1.json). Exact-equivalent inputs are required to remain exact at every scale; other curves are observations whose drift requires review. The baseline is bound to `svgdiff-renderer-conformance-profile/28` and hashes every fixture source.

The artifact always records `canonical_report_evidence: false`. Magnifying the output changes sampling and can exaggerate small geometry changes, so no alternate-scale measurement enters `StructuredReport`, Difference Magnitude, or Domain Ordering. Canonical Rendered Evidence remains the single DPR `1` observation declared by the Comparison Profile; exact Computed Appearance preserves subpixel parameter differences independently.

The separate [SSIM diagnostics evaluation](../ssim-diagnostics/README.md) uses a fixed 16× QA raster only because the standard five-level MS-SSIM window does not fit the 16×16 canonical corpus raster. Its measured scale sensitivity reinforces this same non-canonical boundary.
