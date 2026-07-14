# Evaluation Annotations

Status: hidden benchmark reference data

Last verified: 2026-07-14

Annotation files contain manually authored reference answers for the curated SVG corpus. They are available to benchmark scoring but must not be included in the prompt, context, filenames, or tools exposed to the evaluated text-only agent.

## Main-change labels

`main-changes.v1.json` records:

- a concise reference summary for each corpus case;
- one or more main visual-semantic changes in importance order;
- a one-based within-case rank;
- an ordinal manual tier and rationale;
- acceptable alternative descriptions that should receive equivalent semantic credit.

The current file is an initial single-pass manual reference set. The tiers `none`, `low`, `medium`, and `high` are human-oriented judgments for these cases, not an engine metric, a universal cross-domain scalar, or a release threshold. Raw report magnitudes remain authoritative evidence, and later benchmark work must state how these labels are scored and may add independent reviewer agreement without rewriting the versioned labels.

Equivalent spelling and zero-contribution cases intentionally retain semantic edit descriptions with `none` visual importance. Unsupported cases describe the human-reference visual change even when the current engine correctly returns only partial analysis.

## Validate

```sh
sh scripts/test-annotations.sh
```

The check requires a one-to-one case mapping with the curated corpus and validates IDs, summaries, ranks, tiers, rationales, and alternative descriptions.

## Region labels

`regions.v1.json` records localizable outcomes in comparison CSS-pixel coordinates. Simple filled shapes use `exact_painted_bounds`; quantized micro-geometry and unsupported stroked paths use `conservative_css_bounds` with a containment scoring rule. Equivalent and zero-contribution cases are explicitly `not_applicable` rather than represented by fabricated zero-area regions.

Validate them with:

```sh
sh scripts/test-region-annotations.sh
```

## Actual-cause labels

`actual-causes.v1.json` admits only controlled cases with rendered outcomes and sufficient coverage for Cause Envelope recall evaluation. Actual causes use semantic fact locators instead of report-local IDs. The resource-mediated case intentionally identifies the edited gradient stop as the actual changed cause while allowing downstream computed paint facts to remain conservative false-positive candidates.

Equivalent, zero-contribution, and unsupported cases are explicitly `not_applicable`. Validate corpus coverage and reference integrity with:

```sh
sh scripts/test-cause-annotations.sh
```
