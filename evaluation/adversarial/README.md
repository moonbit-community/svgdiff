# Adversarial SVG Pair Corpus

Status: active safety regression suite

Manifest version: `svgdiff-adversarial-corpus/1`

Last verified: 2026-07-14

This suite contains one focused pair for each current adversarial failure mode: false complete, false equality, source-order alignment, attribution leakage, and same-domain magnitude misordering. The cases are small counterexamples with executable invariants, not a claim of general adversarial robustness.

Run `sh scripts/test-adversarial.sh`. The validator executes every pair through the production release CLI, writes a versioned result artifact with fixture and report hashes, and runs twice to prove deterministic reports and assertions.

The suite is separate from the [human-labeled curated corpus](../corpus/README.md). Adversarial cases test engine safety properties directly; they do not automatically receive main-change, region, or actual-cause labels and do not enter agent benchmark aggregates unless a later annotation item admits them.

## Failure modes

| Failure mode | Counterexample | Required invariant |
| --- | --- | --- |
| False complete | Self-comparison containing an unsupported transform | Status remains `partial` with the transform Diagnostic. |
| False equality | Changed unsupported path with no current Atomic Difference | Status remains `partial`; an empty difference list cannot establish equality. |
| Wrong alignment | Two unlabelled rectangles swap source order only | Correspondences cross source indices and the report remains complete with no differences. |
| Attribution leakage | Two separated rectangles change paint independently | Each region's Cause Envelope contains only its event's Changed Fact. |
| Magnitude ordering | Two position changes have magnitudes 4 and 1 | Geometry differences are emitted in descending order under `v1_domain_lexicographic`. |
