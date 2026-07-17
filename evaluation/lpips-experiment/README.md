# LPIPS Optional Experiment

Status: versioned offline experiment; production integration rejected

Last verified: 2026-07-17

This experiment measures the official learned AlexNet LPIPS v0.1 scalar on the thirteen-case SVG corpus under four explicit QA render profiles: 4x and 16x pinned-renderer output, each composited over opaque white and black in linear sRGB. The resulting RGB values are encoded to sRGB and mapped to the official `[-1, 1]` tensor range without TorchVision classifier resizing, cropping, or normalization.

The current 16 by 16 canonical viewport is too small for the AlexNet feature pyramid. Every observation here is therefore alternate-scale QA evidence. It is not Structured Report evidence, equality, coverage, Difference Magnitude, localization, causality, severity, Impact Assessment, Agent input, or a release gate.

## Result

The checked-in result rejects production integration:

- the embedded-raster change is a false identity in every profile because the selected raster source does not paint embedded images;
- exact-equivalent and zero-contribution controls remain zero, but zero is only model response under the selected raster and profile;
- scale and background changes alter nonzero LPIPS values, so the score has no profile-independent meaning;
- every render profile contains inversions or ties against the current single-pass human tiers;
- scalar pooling supplies no SVG subject, property, source span, Difference Region, or Cause Envelope;
- reproducing the value requires Python, PyTorch, TorchVision, the LPIPS package, its learned calibration weights, and separate ImageNet AlexNet backbone weights.

The accepted role is `optional_offline_learned_perceptual_experiment`. Existing exact, geometric, coverage, raw raster, DeltaEOK, FLIP, region, and causal evidence remains authoritative.

## Dependency-free validation

The dedicated repository script validates the checked-in artifact, source hashes, method identities, symmetry, profile coverage, renderer-gap preservation, and rejection decision without importing or installing the neural stack:

```sh
sh scripts/test-lpips-experiment.sh
```

## Opt-in regeneration

Regeneration is deliberately outside default installation and CI. Prepare an isolated Python 3.11.6 environment containing exactly `lpips==0.1.4`, `torch==2.7.1`, `torchvision==0.22.1`, and `numpy==2.4.6`. Place `alexnet-owt-7be5be79.pth` under `$TORCH_HOME/hub/checkpoints/` and verify the SHA-256 identities in [`manifest.v1.json`](manifest.v1.json). Then run:

```sh
moon build --target native --release evaluation/renderer_adapter cmd/svgdiff
TORCH_HOME=/path/to/offline/torch-home \
  /path/to/pinned/python evaluation/lpips-experiment/evaluate.py \
  --adapter _build/native/release/build/Milky2018/svgdiff/evaluation/renderer_adapter/renderer_adapter.exe \
  --cli _build/native/release/build/Milky2018/svgdiff/cmd/svgdiff/svgdiff.exe \
  --update
sh scripts/test-lpips-experiment.sh
```

The evaluator rejects runtime or weight drift and configures CPU-only single-thread inference, evaluation mode, a fixed seed, and deterministic PyTorch algorithms. PyTorch does not promise identical results across releases or platforms, so the artifact is evidence for the recorded environment only.

Primary-source rationale and licensing boundaries are recorded in [the LPIPS research note](../../docs/research/lpips-evaluation.md). The product decision is [ADR 0096](../../docs/adr/0096-keep-lpips-outside-product-semantics.md).
