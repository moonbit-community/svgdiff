# Adversarial SVG Pair Corpus

Status: active safety regression suite

Manifest version: `svgdiff-adversarial-corpus/1`

Last verified: 2026-07-14

This suite contains one focused pair for each current adversarial failure mode: malformed-transform false complete, invalid-viewport false complete, false equality, source-order alignment, attribution leakage, same-domain magnitude misordering, and unsafe local-reference graphs. The cases are small counterexamples with executable invariants, not a claim of general adversarial robustness.

Run `sh scripts/test-adversarial.sh`. The validator executes every pair through the production release CLI, writes a versioned result artifact with fixture and report hashes, and runs twice to prove deterministic reports and assertions.

The suite is separate from the [human-labeled curated corpus](../corpus/README.md). Adversarial cases test engine safety properties directly; they do not automatically receive main-change, region, or actual-cause labels and do not enter agent benchmark aggregates unless a later annotation item admits them.

## Failure modes

| Failure mode | Counterexample | Required invariant |
| --- | --- | --- |
| False complete | Self-comparison containing a malformed transform list | Status remains `partial` with `transform_syntax_unsupported`; identical invalid syntax does not invent a diff. |
| Viewport false complete | Self-comparison containing a zero-width `viewBox` | Status remains `partial` with `viewport_semantics_unsupported`; identical invalid viewport syntax does not invent equality or a diff. |
| False equality | Changed guarded path geometry | Status remains `partial`; exact parameter findings do not establish complete path equality. |
| Wrong alignment | Two unlabelled rectangles swap source order only | Correspondences cross source indices and the report remains complete with no differences. |
| Attribution leakage | Two separated rectangles change paint independently | Each region's Cause Envelope contains only its event's Changed Fact. |
| Magnitude ordering | Two position changes have magnitudes 4 and 1 | Geometry differences are emitted in descending order under `v2_domain_lexicographic`. |
| Reference cycle | A symbol directly instantiates itself through `<use>` | Analysis fails before renderer parsing with source-located `reference_cycle_detected` Diagnostics and no partial inventory. |
| Reference expansion | An acyclic 18-level binary `<use>` DAG has about 60 authored elements but an expansion bound above 1,000,000 | Analysis fails before renderer parsing with `reference_expansion_limit_exceeded` and no partial inventory. |
