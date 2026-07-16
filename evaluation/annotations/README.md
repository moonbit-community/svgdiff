# Evaluation Annotations

Status: hidden benchmark reference data

Last verified: 2026-07-15

Annotation files contain manually authored reference answers for the curated SVG corpus. They are available to benchmark scoring but must not be included in the prompt, context, filenames, or tools exposed to the evaluated text-only agent.

The report-only [agent harness](../harness/README.md) deliberately does not read this directory when preparing or running tasks.

## Subject Alignment labels

`subject-alignments.v1.json` records one reviewed corpus representative for one-to-one correspondence, insertion, deletion, split, merge, and safe many-to-many membership. Its expectations are limited to relation, side cardinalities, an optional accepted basis, and the pairwise-identity boundary. In particular, the repeated two-by-two class records pairwise identity as undefined; array positions are not reference pairs.

Validate these labels and their exact correspondence with production corpus expectations using:

```sh
sh scripts/test-alignment-annotations.sh
```

These labels validate the report model. They are not visual main-change answers and are never included in Agent tasks.

## Main-change labels

`main-changes.v1.json` records:

- a concise reference summary for each corpus case;
- one or more main visual-semantic changes in importance order;
- a one-based within-case rank;
- an ordinal manual tier and rationale;
- acceptable alternative descriptions that should receive equivalent semantic credit.

The current file is an initial single-pass manual reference set. The tiers `none`, `low`, `medium`, and `high` are human-oriented judgments for these cases, not an engine metric, a universal cross-domain scalar, or a release threshold. Raw report magnitudes remain authoritative evidence.

The versioned [Impact calibration evaluation](../impact-calibration/README.md) joins these labels to production event measurements without exposing them to the report or Agent harness. Its v1 result rejects production thresholds and total ordering: there is no recorded independent reviewer agreement, only one `low` event, one `high` event lacks rendered inputs, and no scorable case contains multiple ranked events. Future review may add agreement and new versioned cases without rewriting these labels.

Equivalent spelling and zero-contribution cases intentionally retain semantic edit descriptions with `none` visual importance. Unsupported cases describe the human-reference visual change even when the current engine correctly returns only partial analysis.

## Validate

```sh
sh scripts/test-annotations.sh
```

The check requires a one-to-one case mapping with the curated corpus and validates IDs, summaries, ranks, tiers, rationales, and alternative descriptions.

## Region labels

`regions.v1.json` records localizable outcomes in comparison CSS-pixel coordinates. Simple filled shapes use `exact_painted_bounds`, while unsupported stroked paths use `conservative_css_bounds` with a containment scoring rule. Equivalent, zero-contribution, and browser-invisible micro-geometry cases are explicitly `not_applicable` rather than represented by fabricated or nonconformant regions.

Validate them with:

```sh
sh scripts/test-region-annotations.sh
```

## Actual-cause labels

`actual-causes.v1.json` admits only controlled cases with rendered outcomes and sufficient coverage for Cause Envelope recall evaluation. Actual causes use semantic fact locators instead of report-local IDs. Fractional geometry and referenced gradient or pattern cases remain excluded while renderer conformance prevents a complete Cause Envelope guarantee.

Equivalent, zero-contribution, renderer-guarded, and unsupported cases are explicitly `not_applicable`. Validate corpus coverage and reference integrity with:

```sh
sh scripts/test-cause-annotations.sh
```

`ranking-targets.v1.json` maps the manually labeled main changes to accepted top report events or Atomic Difference sets. The guarded path case is scorable because the report now exposes exact parameter differences and one path Visual Event even though its causal guarantee remains partial.
