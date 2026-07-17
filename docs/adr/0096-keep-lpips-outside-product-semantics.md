# ADR 0096: Keep LPIPS outside product semantics

- Status: accepted
- Date: 2026-07-17
- Decision owners: svgdiff maintainers
- Supersedes: none

## Context

LPIPS compares normalized deep-network activations under learned per-channel weights calibrated on human judgments over image patches. It may be useful when investigating rendered-image similarity, but it does not model SVG source facts, computed geometry, subject correspondence, regions, or causes. The official learned AlexNet configuration also requires a Python neural runtime, LPIPS calibration weights, and separate ImageNet backbone weights.

The canonical corpus renders at 16 by 16 pixels, below the AlexNet feature-pyramid input size. A versioned experiment therefore evaluated the official `lpips==0.1.4` AlexNet v0.1 scalar only on separately identified 4x and 16x QA rerenders. Each scale was composited over explicit white and black backgrounds in linear sRGB, encoded to sRGB8, and normalized to the official tensor range. CPU inference pinned Python 3.11.6, PyTorch 2.7.1, TorchVision 0.22.1, NumPy 2.4.6, both weight hashes, one thread, evaluation mode, and deterministic algorithms.

Across thirteen cases and four profiles, input reversal was exactly symmetric and repeat inference was bit-identical in the recorded environment. The mean absolute scale response change was `0.0559021375195768` and the maximum was `0.27395099401474`; background changes reached `0.6048315763473511`. Every profile had human-tier inversions or ties. The embedded-raster change was zero in every profile because the selected renderer does not paint it, and the unsupported-path change also became zero over black. These are profile and coverage effects, not learned evidence of SVG equality.

## Decision

Accept LPIPS only as a versioned optional offline learned-perceptual experiment.

Do not add LPIPS to Structured Report, Comparison Profile, Difference Magnitude, equality, completeness, same-domain ordering, Impact Assessment, Agent tasks, benchmark acceptance, release gates, the MoonBit module, default installation, or distributed release assets. Do not derive visibility, severity, a universal threshold, source attribution, or a unique cause from its scalar.

Any experiment must identify the official implementation commit, network family, LPIPS version, calibration and backbone weight hashes, runtime versions, device, deterministic settings, raster source, output scale, explicit background, alpha compositing, RGB encoding, input normalization, source hashes, and renderer coverage. Missing weights or runtime drift fail regeneration. A learned score never repairs unavailable or partial rendering.

The checked-in result may be validated without the neural stack. Regeneration remains deliberately opt-in and offline; PyTorch's cross-release and cross-platform reproducibility limitations prevent its floats from entering canonical serialization.

## Consequences

Developers retain one reproducible artifact for studying scale, background, ranking, identity, and renderer-gap behavior. Existing exact parameter, geometry, coverage, raw raster, DeltaEOK, FLIP, Difference Region, and Cause Envelope evidence remains authoritative.

The early scalar experiment already rejects product integration, so no LPIPS spatial map, event-region pooling, threshold, or comparison with the production Impact frontier is added. Such work would require a concrete Agent task not answered by existing evidence and a separately accepted proposal.

Structured Report Schema `1.44`, module version `0.5.30`, renderer identity, conformance profile `/25`, Impact policy, canonical reports, and public MoonBit interfaces remain unchanged.

## Rejected alternatives

- Use zero LPIPS as equality: pooled learned features and renderer gaps do not preserve exact SVG or pixel identity.
- Add LPIPS beside FLIP in every report: this would add undeclared model, runtime, scale, background, and licensing dependencies without demonstrated Agent benefit.
- Vendor the neural runtime and weights: unnecessary for the accepted offline role and not covered by the MoonBit distribution contract.
- Fit a severity threshold on the current corpus: the labels and profile sensitivity are insufficient, and current Impact calibration already rejects that methodology.

## Evidence

- [`LPIPS optional experiment`](../../evaluation/lpips-experiment/README.md)
- [`LPIPS results`](../../evaluation/lpips-experiment/results.v1.json)
- [`LPIPS research note`](../research/lpips-evaluation.md)
- [`ISS-149`](../../issues/ISS-149.md)
