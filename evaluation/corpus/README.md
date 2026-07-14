# Curated SVG Pair Corpus

Status: active evaluation input corpus

Manifest version: `svgdiff-corpus/1`

Last verified: 2026-07-14

This directory contains hand-authored, standalone SVG pairs used as stable inputs for report and text-only-agent evaluation. Every pair is a real SVG document processed through the production `cmd/svgdiff` command; none depends on the removed toy renderer.

## Layout

- `manifest.json` assigns stable case IDs, categories, file paths, comparison viewport, and minimal engine expectations.
- `cases/<case-id>/before.svg` and `after.svg` are immutable input artifacts once benchmark results cite that case ID.
- Later ground-truth items should add versioned annotations alongside the manifest rather than encoding human answers in filenames or SVG metadata.

The initial corpus covers equivalent authored spelling, a subtle continuous geometry delta, a salient paint change, structural insertion, a referenced-resource change, a zero-contribution insertion, and guarded path geometry findings.

## Integrity check

Run:

```sh
sh scripts/test-corpus.sh
```

The check verifies manifest shape and required category coverage, rejects unsafe or duplicate paths and IDs, confirms every SVG file exists, and executes every pair through the production CLI. `expected_analysis_status`, `minimum_atomic_differences`, and `required_diagnostics` are smoke expectations, not human evaluation labels.

## Scope boundary

This corpus item does not provide mutation-generated cases, main-change labels, alternative descriptions, region ground truth, actual-cause ground truth, an agent harness, metrics, or release thresholds. Those remain separate Phase 0 checklist items so input artifacts do not silently become an underspecified answer key.

Deterministic generated cases with independently declared Changed Facts and affected subjects live in the sibling [mutation suite](../mutations/README.md).

Focused false-complete, false-equality, alignment, attribution, and ordering counterexamples live in the sibling [adversarial suite](../adversarial/README.md). They enforce engine invariants and remain outside human-label aggregates unless separately annotated.

Hidden human reference labels for the curated cases live in [`../annotations`](../annotations/README.md). They must never be exposed to the evaluated agent.
