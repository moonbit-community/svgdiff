# LPIPS Optional Experiment Evaluation

Status: research note

Evidence snapshot: 2026-07-17

This note evaluates LPIPS as an offline development diagnostic. It does not change the Structured Report, Comparison Profile, equality, Difference Magnitude, Impact Assessment, Agent protocol, or release gates.

## Conclusion

LPIPS is suitable for one bounded experiment, but not as an equality oracle or production score in SVG Diff.

The method compares normalized intermediate activations from a fixed image-classification network, applies learned per-channel weights, averages over space, and sums over layers. Those weights were calibrated against human judgments on the BAPPS patch dataset. This can provide useful evidence about whether one rendered change looks more perceptually substantial than another, but it does not prove that two SVG renderings are equal, preserve exact geometry, or differ for a particular source-level reason ([CVPR paper, Equation 1 and training variants](https://openaccess.thecvf.com/content_cvpr_2018/papers/Zhang_The_Unreasonable_Effectiveness_CVPR_2018_paper.pdf), [official implementation](https://github.com/richzhang/PerceptualSimilarity/blob/082bb24f84c091ea94de2867d34c4544f68e0963/lpips/lpips.py#L112-L144)).

Any experiment should therefore remain a separately identified QA artifact with `canonical_report_evidence: false`. A scalar screening study can stop before spatial-map integration if scale, background, renderer coverage, dependency, or ranking evidence already rejects product use. A later spatial study would still be only an auxiliary rendered-image observation and could make no threshold, equality, severity, or source-attribution claim.

## What LPIPS measures

For each selected network layer, LPIPS unit-normalizes activations across channels, computes the squared difference between the two feature tensors, applies a learned `1 x 1` channel weighting, spatially averages the result, and sums across layers. The official implementation also offers `spatial=True`, which bilinearly upsamples each layer response to the input dimensions before summing it ([paper, Section 3](https://openaccess.thecvf.com/content_cvpr_2018/papers/Zhang_The_Unreasonable_Effectiveness_CVPR_2018_paper.pdf), [official scalar and spatial paths](https://github.com/richzhang/PerceptualSimilarity/blob/082bb24f84c091ea94de2867d34c4544f68e0963/lpips/lpips.py#L112-L144)). Higher output means more different and lower output means more similar; the official project does not define a universal visibility or equality threshold ([official README](https://github.com/richzhang/PerceptualSimilarity/blob/082bb24f84c091ea94de2867d34c4544f68e0963/README.md#L52-L96)).

The learned calibration is empirical, not an SVG semantics model. BAPPS uses `64 x 64` natural-image patches, traditional photometric, noise, blur, spatial, and compression distortions, CNN-generated distortions, and outputs from super-resolution, frame interpolation, deblurring, and colorization systems. Its judgments are two-alternative preference and same/different JND tasks ([paper, dataset and distortion design](https://openaccess.thecvf.com/content_cvpr_2018/papers/Zhang_The_Unreasonable_Effectiveness_CVPR_2018_paper.pdf)). The paper intentionally chose patches to emphasize lower-level similarity and reduce high-level semantic ambiguity. It does not validate exact vector-graphics regression, transparent compositing, source equivalence, one-pixel SVG changes, or attribution to SVG entities and properties.

## Input and model contract

The experiment must pin the following contract rather than recording only the name `LPIPS`:

| Field | Required value for the minimum experiment | Rationale |
| --- | --- | --- |
| Input tensor | Equal-sized `N x 3 x H x W` RGB tensors | This is the official API shape; alpha is not accepted. |
| Pixel range | Encoded sRGB values mapped directly from `[0, 1]` to `[-1, 1]` | The wrapper expects `[-1, 1]`, or performs this mapping only when `normalize=True`. |
| Alpha policy | Composite both raw RGBA renderings over the same explicit opaque sRGB Perceptual Background before RGB conversion | LPIPS has no transparent-image or alpha semantics; no background may be guessed. |
| Spatial preparation | Render a separate fixed `64 x 64`, DPR `1` QA observation; do not resize, crop, or apply TorchVision classifier transforms afterward | The official examples and BAPPS use `64 x 64` patches. A separate render avoids silently enlarging the current `16 x 16` canonical raster. |
| LPIPS variant | `lpips==0.1.4`, `net="alex"`, `version="0.1"`, `lpips=True`, pretrained calibration, evaluation mode | AlexNet is the official default forward metric; v0.0 has a documented normalization bug. |
| Calibration weights | The packaged `weights/v0.1/alex.pth`, content-addressed in the experiment manifest | LPIPS loads this file separately from its backbone. At upstream commit `082bb24`, its SHA-256 is `df73285e35b22355a2df87cdb6b70b343713b667eddbda73e1977e0c860835c0`. |
| Backbone | Exact TorchVision AlexNet ImageNet-1K v1 weights, stored in the offline bundle and content-addressed | The LPIPS code calls `torchvision.models.alexnet(pretrained=True)` and therefore requires an additional pretrained backbone, not only the small LPIPS calibration file. |

The official wrapper applies its own v0.1 scaling layer after the `[-1, 1]` input conversion. The ordinary TorchVision AlexNet resize, center crop, and ImageNet normalization recipe is classifier preprocessing and must not be applied on top of LPIPS preprocessing ([LPIPS input and scaling source](https://github.com/richzhang/PerceptualSimilarity/blob/082bb24f84c091ea94de2867d34c4544f68e0963/lpips/lpips.py#L112-L154), [TorchVision AlexNet weights documentation](https://docs.pytorch.org/vision/main/models/generated/torchvision.models.alexnet.html)).

Two independent model artifacts are required. The LPIPS package includes v0.0 and v0.1 linear calibration files, but its network wrapper obtains the ImageNet trunk from TorchVision ([LPIPS package data](https://github.com/richzhang/PerceptualSimilarity/blob/082bb24f84c091ea94de2867d34c4544f68e0963/setup.py#L5-L17), [backbone construction](https://github.com/richzhang/PerceptualSimilarity/blob/082bb24f84c091ea94de2867d34c4544f68e0963/lpips/pretrained_networks.py#L56-L94)). The official package declares only lower bounds for PyTorch and TorchVision, so an unpinned installation is not a reproducible metric definition.

## Symmetry and directionality

LPIPS is mathematically symmetric for a fixed deterministic model and preprocessing contract: swapping inputs leaves the squared feature difference unchanged. The official implementation processes both inputs with the same network and computes `(feats0 - feats1) ** 2` before the shared weighting and pooling ([official implementation](https://github.com/richzhang/PerceptualSimilarity/blob/082bb24f84c091ea94de2867d34c4544f68e0963/lpips/lpips.py#L117-L144)).

It is not directional. The scalar cannot say that the `before` rendering is better, worse, added, removed, or moved; it only reports feature-space separation. The experiment should nevertheless compute both `d(before, after)` and `d(after, before)` and record their absolute difference. A nonzero symmetry gap indicates an implementation, preprocessing, device, or reproducibility problem, not meaningful SVG direction.

The BAPPS 2AFC task is directional at the task level because it asks which of two distortions is closer to a reference. That ranking setup does not make the pairwise LPIPS distance directional ([paper, psychophysical task](https://openaccess.thecvf.com/content_cvpr_2018/papers/Zhang_The_Unreasonable_Effectiveness_CVPR_2018_paper.pdf)).

## Determinism and offline reproducibility

PyTorch explicitly does not guarantee complete reproducibility across releases, commits, platforms, or CPU and GPU execution. It provides deterministic-algorithm controls only for a fixed environment and warns that deterministic execution may be slower ([PyTorch reproducibility guidance](https://docs.pytorch.org/docs/stable/notes/randomness.html)). Consequently, an LPIPS float cannot participate in SVG Diff's cross-environment canonical serialization contract.

The offline experiment should:

- use CPU inference only, one worker, one thread, `eval_mode=True`, `torch.inference_mode()`, a fixed seed, and `torch.use_deterministic_algorithms(True)`;
- pin Python, `lpips`, PyTorch, TorchVision, NumPy, operating system, architecture, and the upstream LPIPS commit;
- install from a locked local wheelhouse and load both model artifacts from a content-addressed local cache with network access disabled;
- record all package versions, artifact SHA-256 values, render profile, Perceptual Background, input raster hashes, tensor-conversion method, device, thread count, and deterministic flags;
- run each pair at least ten times in fresh processes and preserve exact float bit patterns, not only rounded decimal text;
- execute the swapped-input check and an identical-input control for every raster;
- treat any within-environment drift, non-finite result, failed symmetry check, or missing artifact as experiment failure rather than substituting a score.

Passing these checks establishes repeatability only for the recorded environment. It does not establish portability to another PyTorch version, CPU architecture, GPU, or model artifact.

## Licensing and distribution boundary

The official LPIPS repository is BSD-2-Clause, and its package configuration distributes the learned linear calibration files with the Python package. Redistribution requires preserving the license's source or binary notices ([LPIPS license](https://github.com/richzhang/PerceptualSimilarity/blob/082bb24f84c091ea94de2867d34c4544f68e0963/LICENSE), [packaged weights](https://github.com/richzhang/PerceptualSimilarity/blob/082bb24f84c091ea94de2867d34c4544f68e0963/setup.py#L14-L20)). TorchVision code is BSD-3-Clause, but TorchVision separately warns that pretrained models may have their own licenses or terms derived from their training datasets and makes users responsible for determining permitted use ([TorchVision license](https://github.com/pytorch/vision/blob/main/LICENSE), [pretrained-model license notice](https://github.com/pytorch/vision#pre-trained-model-license)).

Therefore the first experiment may use locally cached artifacts, but SVG Diff should not vendor or redistribute PyTorch, TorchVision, or the AlexNet backbone weights in its module, binary package, or release assets until their complete distribution obligations have been reviewed. LPIPS must remain outside the MoonBit runtime and ordinary installation path.

## Why LPIPS cannot be an equality oracle

1. The learned feature representation is many-to-one and pooled. Identical RGB tensors produce zero by construction, but neither the paper nor implementation promises the converse: zero or a small value does not prove equal pixels, equal computed appearance, or equal SVG semantics.
2. The official evidence concerns perceptual judgments on bounded natural-image patches and image-processing distortions, not exact SVG regression. Applying it to antialiased vector edges, flat colors, transparency, and sparse semantic changes is domain transfer that must be measured, not assumed.
3. The output depends on the network family, LPIPS version, calibration weights, backbone weights, input scale, background, preprocessing, dependency versions, and execution platform. The official README itself requires callers to identify the LPIPS version and exposes AlexNet, VGG, and SqueezeNet variants.
4. Spatial averaging can dilute a small but important change. `spatial=True` retains an upsampled response map, but that map still supplies no SVG subject, property, source span, or Cause Envelope.
5. RGB-only input necessarily discards alpha after a chosen background composite. A score under one background is not evidence under every possible display background.
6. LPIPS cannot preserve exact computed differences that quantize to the same raster. Those remain authoritative in SVG Diff's parameter, geometry, coverage, source, and causal evidence even when LPIPS is zero.

Raw byte/pixel identity and the current layered semantic/raster evidence must therefore remain authoritative. LPIPS may only answer the narrower experimental question: under this separately recorded render and model profile, how large is the learned feature-space response?

## Candidate extended offline experiment

Use the existing curated SVG corpus and labels, plus explicit controls for identical renderings, source-only equivalent spellings, a one-pixel change, a subpixel geometry change, flat-color replacement, opacity, overlap/blend, and an embedded-raster change.

For every case:

1. Produce before and after RGBA8 images from the pinned production renderer at a separate `64 x 64`, DPR `1` QA profile and record that these pixels are not canonical report evidence.
2. Require one explicit opaque sRGB Perceptual Background, composite both images through the project's existing linear-sRGB background rule, encode the visible result as sRGB8 RGB, and hash both tensors.
3. Run pinned AlexNet LPIPS v0.1 in scalar and spatial modes without post-render resize or crop.
4. Record scalar `d(before, after)`, scalar `d(after, before)`, symmetry gap, repeated-run bit stability, the spatial-map artifact hash, whole-map mean, maximum, p95, and means over existing Difference Regions. Region statistics are diagnostic joins to already established regions, not LPIPS localization or attribution.
5. Join the result with changed-pixel fraction, linear premultiplied-RGBA RMSE, DeltaEOK, FLIP, existing human tier, and the current main-event target. Preserve missing inputs rather than imputing zero.
6. Report rank correlation and all ordering inversions against the existing labels, plus profile sensitivity for at least white and black explicit backgrounds. Do not fit a production threshold on this corpus.

The experiment passes only as an optional diagnostic if it is bit-stable in the pinned CPU environment, symmetric under input swap, contains no non-finite results, and exposes no new false identity in the curated raw-different controls. Passing does not authorize equality, severity labels, Impact ordering, or Structured Report integration. Any result that requires a changed canonical renderer, an implicit background, online weight download, unpinned dependencies, or relaxed reproducibility checks rejects the experiment instead.

## 2026-07-17 bounded scalar result

The implemented screening study ran the official learned AlexNet LPIPS v0.1 scalar on every curated case under four explicitly separate profiles: 4x and 16x QA rerenders over white and black. It pinned Python 3.11.6, `lpips==0.1.4`, PyTorch 2.7.1, TorchVision 0.22.1, NumPy 2.4.6, CPU execution, deterministic algorithms, and both model-weight hashes. Each raw RGBA8 raster was composited onto the declared background in linear sRGB, encoded to sRGB8, mapped to `[-1, 1]`, and passed to the LPIPS wrapper without classifier resize, crop, or normalization.

All 52 observations were exactly symmetric under input reversal and bit-identical under repeated inference in the recorded environment. That reproducibility did not rescue product meaning: the mean absolute scale delta was `0.0559021375195768`, the maximum scale delta was `0.27395099401474`, and background changes reached `0.6048315763473511`. Every profile inverted or tied human-tier pairs. The embedded-raster case was zero in every profile because the selected raster source does not paint it, while the unsupported-path case also became zero over black.

These results reject canonical integration before spatial-map or event-region pooling work would add useful evidence. LPIPS remains only an optional offline learned-perceptual experiment. The neural stack and weights are absent from the MoonBit module, default installation, canonical report, Impact Assessment, Agent transport, and release gates. The complete artifact and dependency-free validator live in the [LPIPS experiment](../../evaluation/lpips-experiment/README.md); [ADR 0096](../adr/0096-keep-lpips-outside-product-semantics.md) records the product boundary.

## Recommendation

Run the bounded offline study once. Keep the result in a versioned evaluation directory with its manifest, environment lock, local-artifact hashes, inputs, and outputs. Unless it demonstrates a clear complementary ranking benefit over the existing raw raster, DeltaEOK, and event-local FLIP channels without unacceptable scale, background, dependency, or domain sensitivity, stop there and retain LPIPS only as a documented rejected or inconclusive alternative.
