# SSIM and MS-SSIM Diagnostics

Status: versioned QA-only evaluation

Last verified: 2026-07-20

This evaluation measures what single-scale SSIM and five-level MS-SSIM can contribute as secondary raster diagnostics. It deliberately does not add either metric to Structured Report, Difference Magnitude, equality, Impact Assessment, Agent tasks, or release acceptance.

The native adapter implements the original local SSIM formula with `K1 = 0.01`, `K2 = 0.03`, an 11×11 Gaussian window with sigma `1.5`, valid-window mean pooling, and dynamic range `255`. Opaque grayscale input uses BT.601 coefficients after sRGB8 source-over compositing onto explicit white. Exact sample identity is clamped to the mathematical identity maximum `1`.

Five-level MS-SSIM uses the published product weights `0.0448`, `0.2856`, `0.3001`, `0.2363`, and `0.1333`, with disjoint 2×2 box averaging between levels. A 16×16 canonical raster cannot retain an 11×11 window through five levels, so MS-SSIM runs only on a separately identified 16× enlarged QA raster. This changed output scale is not canonical report evidence.

## Result

The thirteen-case corpus supports only a QA-only role. Its ordinal tiers remain an initial single-pass evaluation reference, not product truth:

- exact-equivalent and zero-contribution direct-renderer pairs remain at identity;
- the subtle-geometry `low` case is falsely identical because both `0.99999` and `1.0` quantize to the same pixels, matching the production fractional-geometry guard;
- the embedded-raster `high` case is falsely identical because svgdiff has not yet connected its bounded resource bundle to the dependency's host image resolver, matching the production `raster.embedded_images` capability gap;
- canonical and enlarged SSIM differ by `0.2677904201327124` on average and by as much as `0.9779354872328625`;
- the unsupported-path five-level product is not computed because a final component is non-positive;
- canonical SSIM dissimilarity agrees with only `36/59` different-tier pairs, enlarged SSIM with `39/59`, and MS-SSIM with `31/50`; the remaining pairs are inverted or tied;
- whole-canvas pooling supplies no subject, region, changed fact, or cause link.

SSIM and MS-SSIM are therefore accepted only as optional development observations for a fixed, fully recorded raster source and scale. They must inherit renderer coverage, and their values may help characterize structural raster drift. They cannot prove equality, replace raw pixel or vector evidence, rank human importance, localize a change, identify a cause, or enter the current Impact policy.

The checked-in [`results.v1.json`](results.v1.json) records all scores, source hashes, production analysis status, capability gaps, scale deltas, pair-order evaluation, method identities, and the evaluation adapter implementation hash.

## Reproduce

```sh
sh scripts/test-ssim-diagnostics.sh
```

To intentionally regenerate the artifact after an accepted corpus, renderer, algorithm, or profile change:

```sh
moon build --target native --release modules/svgdiff/evaluation/ssim_adapter modules/svgdiff/cmd/svgdiff
python3 evaluation/ssim-diagnostics/evaluate.py \
  --adapter _build/native/release/build/Milky2018/svgdiff/evaluation/ssim_adapter/ssim_adapter.exe \
  --cli _build/native/release/build/Milky2018/svgdiff/cmd/svgdiff/svgdiff.exe \
  --update
sh scripts/test-ssim-diagnostics.sh
```

The algorithm configuration follows the original [SSIM paper and author guidance](https://ece.uwaterloo.ca/~z70wang/research/ssim/) and [MS-SSIM paper](https://www.ece.uwaterloo.ca/~z70wang/publications/msssim.pdf). The MoonBit implementation is an independent implementation of the published formulas under the method identities in the manifest.
