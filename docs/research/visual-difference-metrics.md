# Visual Difference Metrics for SVG Comparison

Status: research note

Evidence snapshot: 2026-07-16

This note surveys available metrics and target design. Schema `1.36` implements exact scalar parameters, Schema `1.37` adds painted-boundary distributions, Schema `1.38` adds alpha-only coverage difference, Schema `1.39` records an optional explicit opaque sRGB Perceptual Background, Schema `1.40` adds event-local changed-pixel mean DeltaEOK, Schema `1.41` adds optional event-local LDR-FLIP maps under explicit pixels-per-degree Viewing Conditions, Schema `1.42` adds separately pooled canvas, selected-event, response-tail, maximum, and explicit-threshold-area statistics, and Schema `1.43` adds an uncalibrated Pareto frontier over common event-rendered magnitude fields. Continuous vector correspondence and a supportable calibrated Impact Assessment remain roadmap work.

## Conclusion

There are mature mechanisms for measuring particular kinds of visual difference, but there is no accepted universal scalar that means "how different are these two SVGs?" Geometry displacement, changed painted area, pixel error, color perception, and perceptual image error answer different questions. SVG Diff should preserve them as a score vector and derive any `0..1` ranking score from an explicit, versioned policy.

For a change such as `1.0 -> 0.99999`, a fixed-resolution pixel metric alone is insufficient: the computed geometry is certainly different, while the target rendering may be identical or nearly identical after sampling. The report should say both things rather than forcing one to erase the other.

## Mature building blocks

### 1. Exact parameter and device-space displacement

For corresponding scalar geometry, the exact absolute difference is the least ambiguous measurement. It should be reported in authored user units and, after applying the cumulative transform, in CSS pixels. A relative source-value delta can be useful for diagnostics, but it is not a visual measure: moving `x=1` to `x=2` and moving `x=1000` to `x=1001` both displace the result by one unit even though their source-relative changes differ radically.

This layer therefore needs no opaque similarity algorithm. For a displacement `d` it should retain at least `abs_user_units`, `abs_css_px`, `viewport_fraction = abs_css_px / viewport_diagonal`, and, when meaningful, `entity_fraction = abs_css_px / entity_characteristic_size`. Transform changes should be decomposed into translation, rotation, scale, and skew before scoring; a Euclidean distance between raw matrix coefficients has no stable visual interpretation. Schema `1.36` implements the four scalar scales for admitted entity geometry and decomposed translation, using the maximum nonzero per-side conservative-bounds diagonal as the entity characteristic size. It leaves unavailable mappings null and retains typed angle, scale, and residual-matrix effects without fabricating CSS displacement; perceptual scoring remains future policy work.

### 2. Contour distance and changed coverage

When two entities do not share comparable parameters, compare their painted geometry. Hausdorff distance is a mature contour-distance mechanism. OpenCV exposes both L1/L2 contour Hausdorff distance and a ranked partial Hausdorff variant; the latter reduces the domination of the ordinary maximum by a single outlier ([OpenCV `HausdorffDistanceExtractor`](https://docs.opencv.org/3.4/d0/de1/classcv_1_1HausdorffDistanceExtractor.html)).

SVG Diff Schema `1.37` samples pinned-raster alpha-support boundaries in device space and reports the symmetric nearest-boundary arithmetic mean, nearest-rank p95, maximum, and per-side sample counts after DPR normalization. This is a deterministic partial-Hausdorff-style observation for cases without pointwise correspondence; it loses direction and can match the wrong repeated contour. Continuous vector correspondence remains future work. Schema `1.38` complements it with a bounded soft coverage difference:

```text
coverage_difference = sum(abs(coverage_before - coverage_after))
                    / sum(max(coverage_before, coverage_after))
```

Schema `1.38` implements this over isolated pinned-renderer RGBA8 alpha, retaining each side's coverage, absolute difference, and union in CSS square pixels beside the normalized fraction. This is `0` for equal coverage and `1` for disjoint coverage. Boundary displacement explains how far an edge moved; coverage difference explains how much painted area changed. Neither measures color or salience.

### 3. Pixel energy and perceptual color difference

MSE/RMSE over aligned pixels is mature, cheap, and physically interpretable, but the original SSIM paper notes that MSE and PSNR are poorly matched to perceived visual quality ([Wang et al., 2004](https://ece.uwaterloo.ca/~z70wang/publications/ssim.pdf)). It is useful as raw raster evidence, not as the final severity judgment.

Pixel arithmetic must respect color and alpha semantics. CSS defines a linear-light sRGB space ([CSS Color 4, `srgb-linear`](https://www.w3.org/TR/css-color-4/#predefined-sRGB-linear)), while the compositing specification defines coverage through alpha and the premultiplied result of source-over compositing ([Compositing and Blending Level 1, simple alpha compositing](https://www.w3.org/TR/compositing-1/#simplealphacompositing)). Accordingly, retain coverage error separately and compute linear premultiplied-RGBA error. For a human-facing color error, composite both samples onto the profile background and then compare their visible colors.

CIEDE2000 is an international standard intended to make numerical color distance better reflect relative perceived color difference ([ISO/CIE 11664-6:2022](https://www.cie.co.at/publications/colorimetry-part-6-ciede2000-colour-difference-formula-1)). CSS Color 4 also specifies DeltaEOK and currently uses `0.02` DeltaEOK or `2` DeltaE2000 as a just-noticeable-difference reference in its gamut-mapping procedure ([CSS Color 4, local MINDE](https://www.w3.org/TR/css-color-4/#css-gamut-mapping-to-an-rgb-destination)). These are useful profile defaults, not universal visibility thresholds: spatial context, alpha, background, and viewing conditions still matter.

### 4. SSIM and MS-SSIM

SSIM is a mature full-reference quality metric based on local luminance, contrast, and structural comparison. It produces a local quality map and commonly pools that map to a mean ([Wang et al., 2004](https://ece.uwaterloo.ca/~z70wang/publications/ssim.pdf)). MS-SSIM repeatedly low-pass filters and downsamples, combining measurements across scales to account better for resolution and viewing-condition variation ([Wang, Simoncelli, and Bovik, 2003](https://ece.uwaterloo.ca/~z70wang/publications/msssim.pdf)).

SSIM is suitable as a secondary whole-image structural summary. It should not be canonical for SVG Diff: its original role is reference-versus-distortion image quality, mean pooling can dilute a small but important local change, and its local windows do not explain which SVG entity or property changed. MS-SSIM's downsampling pyramid is not a substitute for exact Computed Appearance measurements of geometry that may not affect pixels under the Comparison Profile.

### 5. FLIP

FLIP is the strongest existing candidate for the rendered-perception component because it was designed specifically to produce a spatial error map for differences between rendered images. Its authors describe the map as approximating the difference perceived while alternating the two images and report a supporting user study ([Andersson et al., 2020](https://research.nvidia.com/publication/flip)). The maintained NVIDIA implementation supports LDR- and HDR-FLIP, records pixels per degree, and emits pooled values as well as the error map ([NVlabs/flip](https://github.com/NVlabs/flip)). The authors now recommend mean FLIP when one pooled number is unavoidable, although the map remains the more useful artifact.

FLIP should be the default spatial perceptual channel, not the definition of equality. Its result depends on viewing assumptions such as pixels per degree, its LDR form assumes the alternating-image viewing protocol, and a canvas-wide mean can understate a spatially small event. Schema `1.41` therefore makes LDR-FLIP opt-in, records pixels per degree, preserves one event-local map, and retains unrelated pixels only as filtering context. Schema `1.42` pools the unquantized internal map into explicitly separate whole-canvas mean, raw-different selected-event mean, complete-response nearest-rank p95, response maximum, and optional strict-above-threshold whole-canvas area. It does not assign perceptual meaning to the caller-supplied threshold.

### 6. Learned perceptual metrics

LPIPS is mature and has an official implementation calibrated with human perceptual judgments; it measures distance between image patches using deep network activations ([Zhang et al., 2018 and official implementation](https://github.com/richzhang/PerceptualSimilarity)). It is not recommended for the initial canonical score because it adds model/version dependencies and has not been validated as an exact SVG-regression detector. It can remain an optional experimental channel rather than a correctness oracle.

## Recommended score vector

Each Atomic Difference and Visual Event should carry measurements rather than only a scalar:

```json
{
  "magnitude": {
    "parameter": {
      "abs_user_units": 0.00001,
      "symmetric_relative": 0.00001000005
    },
    "geometry": {
      "displacement_css_px": { "mean": 0.00001, "p95": 0.00001, "max": 0.00001 },
      "viewport_fraction": 0.00000001,
      "coverage_difference": 0.0
    },
    "raster": {
      "changed_pixel_fraction": 0.0,
      "linear_premultiplied_rgba_rmse": 0.0,
      "delta_e": { "formula": "deltaEOK", "mean": 0.0, "p95": 0.0, "max": 0.0 }
    },
    "perceptual": {
      "metric": "FLIP",
      "canvas_mean": 0.0,
      "event_region_mean": 0.0,
      "response_p95": 0.0,
      "response_maximum": 0.0,
      "area_above_threshold": null
    }
  }
}
```

The numbers above illustrate `1.0 -> 0.99999` under an identity transform and an `800 x 600` viewport; raster values are examples, not guaranteed results. A renderer may produce a minute coverage change even at the target scale.

Alternate-scale rerendering may still be useful while testing a rasterizer, particularly around quantization boundaries. It is an internal QA technique rather than report evidence: exact Computed Appearance measurements already preserve small geometric distinctions, while the canonical Render Observation measures their response under the Comparison Profile.

## Optional ranking policy

Do not make a scalar score or visibility boolean the source of truth. The Render Observation should retain continuous measurements, including exact zero values. If callers need labels or ordering, expose them only as a versioned optional policy:

- a Domain-specific ordering value may be derived from the measurements most relevant to that Domain;
- a human-facing label may summarize configured thresholds without determining whether the Difference exists;
- an indeterminate measurement remains distinct from a measured zero.

Prefer lexicographic ordering by Domain-relevant measurements over adding incommensurate values with arbitrary weights. If a single `0..1` number or label is later required, it must include `policy_id`, threshold values, calibration corpus, and metric versions in the report.

## Recommendation

Adopt a layered `Difference Magnitude` abstraction with exact parameter/device-space measurements, painted-boundary and coverage measurements, raw raster/color evidence, and FLIP as the default spatial perceptual map under one Comparison Profile. Schema `1.41` implements that map boundary, Schema `1.42` adds explicitly named pooling directly from the unquantized internal map, and Schema `1.43` exposes a traceable two-dimensional main-event frontier without weights or labels. Treat SSIM/MS-SSIM, LPIPS, and alternate-scale rerendering as development diagnostics. Calibrate severity thresholds on a curated SVG corpus with human labels before claiming that any composite score represents "major visual difference."

## 2026-07-16 calibration follow-up

The first versioned calibration study evaluated changed-pixel fraction, linear premultiplied-RGBA RMSE, FLIP canvas mean, and a two-field lexicographic total order against the current thirteen-case corpus. It rejected every production candidate. The labels have no recorded independent reviewer agreement, only one event occupies the `low` tier, one `high` event lacks rendered inputs, and the twelve scorable cases contain no multi-event ranking pair.

Changed-pixel fraction can perfectly separate the eleven measured events when fitted and tested on the same data, but leave-one-case-out evaluation predicts only ten of twelve labeled events and gets nine correct. RMSE and FLIP canvas mean have overlapping or inverted tier ranges, so monotonic four-tier cutpoints are not trainable. The existing Pareto frontier recalls the accepted top target in all twelve scorable cases, but that result establishes only frontier inclusion, not a total order or tier calibration.

Therefore the evidence supports retaining `event_rendered_pareto/v1` as `not_calibrated`, not emitting `none`/`low`/`medium`/`high` or `subtle`/`major`, and repeating calibration only after the prerequisites recorded in the [evaluation artifact](../../evaluation/impact-calibration/README.md) are met.

## 2026-07-16 SSIM/MS-SSIM follow-up

A versioned thirteen-case evaluation implemented the original SSIM local-statistics formula and five-level MS-SSIM product weights under explicit QA method identities. The original [SSIM guidance](https://ece.uwaterloo.ca/~z70wang/research/ssim/) states that useful scale depends on resolution and viewing distance, while the [MS-SSIM design](https://www.ece.uwaterloo.ca/~z70wang/publications/msssim.pdf) repeatedly filters and downsamples with calibrated cross-scale weights. The current 16×16 canonical raster is too small for five levels of an 11×11 window, so the MS-SSIM experiment necessarily used a separately identified 16× enlarged raster.

The result rejects canonical integration. Canonical and enlarged SSIM differed by up to `0.9779354872328625`; the embedded-raster change became false identity under a known renderer gap; one MS-SSIM product was unavailable due to a non-positive component; and every score produced human-tier inversions or ties. Global pooling also supplies no report IDs, regions, or causes.

SSIM and MS-SSIM therefore remain optional development observations for a fixed raster source and scale. They do not enter Difference Magnitude, equality, coverage, Impact Assessment, Agent tasks, or severity. See the [reproducible evaluation](../../evaluation/ssim-diagnostics/README.md) and [ADR 0090](../adr/0090-keep-ssim-out-of-canonical-report-semantics.md).
