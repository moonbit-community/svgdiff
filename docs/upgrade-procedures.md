# Dependency and Contract Upgrade Procedures

Status: current maintenance procedure

Last verified: 2026-07-14

Renderer, parser, metric, schema, and ordering-policy versions influence the meaning of a report. They must not be upgraded as isolated dependency edits. This document defines the evidence and synchronized changes required before an upgrade may be merged.

## Current pinned identities

| Component | Current identity | Contract surface |
| --- | --- | --- |
| SVG scene and canonical renderer | `mizchi/svg@0.2.1` | `profile.renderer_id`, rendered magnitudes, Difference Regions, coverage guards |
| Authored XML parser | `Milky2018/xml@0.4.0` | well-formedness, namespaces, entity behavior, UTF-16 Source Spans |
| Baseline pixel comparison | `mizchi/pixelmatch@0.6.1` | connected pixel-mask regions and renderer comparison support |
| Raster metric representation | `linear_srgb_premultiplied_rgba_f64` | `RenderedMagnitude` and `DifferenceMagnitude` numeric meaning |
| JSON Schema | `1.0` | every serialized field, enum, null/absence rule, and top-level invariant |
| Same-domain ordering | `v1_domain_lexicographic` | `DomainOrdering.components` construction and comparison |

The source of dependency versions is `moon.mod`. The source of serialized constants is the public implementation plus [`schema/svgdiff-report.schema.json`](../schema/svgdiff-report.schema.json).

## General upgrade gate

Before changing any component:

1. Start from a clean worktree and record the old component identity.
2. State the reason for the upgrade and the concrete capability, bug, security fix, or conformance result it addresses.
3. Identify affected evidence layers and report fields.
4. Add or identify fixtures that fail or differ under the old version for the intended reason.
5. Run the existing baseline before the edit and preserve its output for comparison.
6. Change only the smallest required layer.
7. Review all changed report values; do not accept snapshot churn without explaining it.
8. Update current-contract documents, the feature coverage matrix, and profile or policy identity when semantics changed.
9. Run the common validation gate at the end of this document.

A successful build is necessary but never sufficient. An upgrade is accepted only when the report meaning and coverage claim remain explicit.

## SVG renderer upgrade

Use this procedure for `mizchi/svg`, a replacement renderer, or a project-owned rendering layer.

### Required evidence

- Run all current complete-eligible fixtures before and after the upgrade.
- Compare geometry, paint, alpha, presence, connected regions, and linear-premultiplied raster metrics.
- Re-run micro-delta cases in both directions around raster boundaries.
- Exercise every known preflight guard, especially inline-style precedence, paint servers, unsupported attributes, and group opacity.
- Add a regression fixture for every upstream bug the new version claims to fix.
- Use an external renderer only as a conformance oracle; do not substitute its output into the production profile without a separate decision.

### Required synchronized changes

- Update the dependency version in `moon.mod` through `moon add` or the supported package command.
- Update `ComparisonProfile::v1_default().renderer_id` when the production renderer identity changes.
- Update the Schema constant for `profile.renderer_id`.
- Reassess Diagnostics whose only purpose was to guard an old renderer defect. Remove a guard only after its negative test is replaced by a positive conformance test.
- Update [`renderer-evaluation.md`](renderer-evaluation.md), [`feature-coverage.md`](feature-coverage.md), and [`v1-scope.md`](v1-scope.md).
- Review Difference Region and magnitude output for intentional numeric drift.

Changing pixels without changing `renderer_id` is a contract bug.

## XML parser upgrade

Use this procedure for `Milky2018/xml` or any replacement source parser.

### Required evidence

- Reject trailing content, mismatched tags, duplicate attributes, unclosed elements, and malformed namespaces.
- Verify namespace-qualified elements and attributes.
- Verify single- and double-quoted attributes, entity expansion limits, and disabled implicit external entities.
- Verify exact authored value recovery from parser spans.
- Verify half-open UTF-16 offsets for ASCII, non-BMP characters, attributes, direct text, and parse errors.
- Confirm that parser-specific types remain private to the Source Semantics adapter.

The regression sources are [`source_adapter_wbtest.mbt`](../engine/source_adapter_wbtest.mbt) and the historical [`milky-xml-evaluation.md`](research/milky-xml-evaluation.md). A new version should receive a dated evaluation follow-up rather than rewriting the historical snapshot.

### Required synchronized changes

- Update `moon.mod` with the supported package command.
- Update parser identity in ownership and evaluation documents.
- Review every Source Span assertion and serialized source-fact fixture.
- Reassess `svg_parse_failed` behavior and any new parser error categories.
- If offset units or source-recovery semantics change, treat that as a report-contract change and follow the Schema procedure.

Parser permissiveness must never silently widen. A newly accepted malformed input requires an explicit correctness decision or a project-side rejection guard.

## Metric upgrade

Use this procedure when changing raster arithmetic, adding a metric, changing a formula, or altering not-computed behavior.

### Required evidence

- State the physical or perceptual question answered by the metric and its units.
- Preserve exact parameter, geometry, coverage, raster, and perceptual channels separately.
- Test identity, symmetry where mathematically expected, monotonic controlled changes, transparent colors, premultiplied alpha, and legitimate zero results.
- Test that unavailable inputs produce absence or `not_computed`, never numeric zero.
- Record algorithm parameters, color interpretation, numeric representation, and external metric version.
- Evaluate same-domain ordering impact without introducing an implicit cross-domain scalar.

Historical metric choices and candidates are described in [`visual-difference-metrics.md`](research/visual-difference-metrics.md). Current implemented fields are defined in [`core-model.md`](core-model.md).

### Required synchronized changes

- Add or change project-owned report fields only with a Schema decision.
- Update `raster_representation` or another explicit metric identity when numeric meaning changes.
- Add assertion tests with hand-explainable controlled cases before adding broad snapshots.
- Update magnitude construction, Domain Ordering components, JSON Schema, agent examples, and feature coverage together.
- Retain the previous metric when consumers need migration comparison; do not silently reuse an old field name for new arithmetic.

## JSON Schema upgrade

Schema `1.0` is a versioned consumer contract. A change to required fields, field meaning, enum values, null/absence behavior, identifier references, or numeric units requires an explicit compatibility review.

### Procedure

1. Describe the old and new JSON shapes with concrete examples.
2. Classify whether old consumers can safely interpret new output without code changes.
3. If interpretation can change or parsing can fail, allocate a new `schema_version`; do not mutate the meaning of `1.0`.
4. Update public MoonBit types and serialization first, then regenerate `.mbti` with `moon info`.
5. Update `schema/svgdiff-report.schema.json` and its `$id`, title, constants, required fields, definitions, and enums.
6. Add validation fixtures for every supported schema version and an explicit migration or rejection test.
7. Update README examples, the core model, status contract, agent guide, and CLI version output when available.
8. Verify that the HTML report consumes the new shape without becoming a second semantic implementation.

Until formal compatibility rules are accepted, prefer a new version for any ambiguous consumer-visible change.

## Domain Ordering policy upgrade

`DomainOrdering` is versioned separately from the JSON Schema because ranking semantics can change without changing field shape.

### Procedure

1. State the affected domain and why the old component tuple is inadequate.
2. Define every component, direction, units, null handling, and deterministic tie-breaker.
3. Add controlled same-domain cases whose intended order is explainable without the implementation.
4. Compare old and new ordering across the evaluation corpus.
5. Allocate a new `policy_id` whenever components, order, direction, or tie-breaking changes.
6. Update report construction, HTML grouping/order behavior, agent interpretation guidance, tests, and the feature coverage matrix.
7. Never compare tuples from different policy IDs as if they shared semantics.

Cross-domain ranking requires its own accepted policy and must not be smuggled into a same-domain upgrade.

## Common validation gate

Run from the repository root:

```sh
moon check --target native --warn-list +73
moon test --target native
sh scripts/test-cli.sh
moon fmt
moon info
jq empty schema/svgdiff-report.schema.json
git diff --check
```

Then review:

- dependency and lock/resolution diffs;
- generated `.mbti` changes;
- profile and policy identities;
- JSON Schema changes;
- changed Diagnostics and analysis statuses;
- numeric and region drift in controlled fixtures;
- current documentation and dated research follow-ups.

Do not publish or merge an upgrade with unexplained report churn, reduced coverage, or an unchanged identity for changed semantics.
