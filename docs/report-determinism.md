# Structured Report Determinism and Local Identifiers

Status: current schema `1.1` contract

Last verified: 2026-07-14

For the same executable, exact before and after SVG bytes, and Comparison Profile, `svgdiff` emits the same Structured Report content, array ordering, report-local identifiers, and serialization bytes on repeated runs. Default formatted JSON and compact Agent JSON have different whitespace but decode to exactly the same report evidence.

This guarantee is report-local and run-repeatability scoped. It does not promise that IDs survive an input edit, profile change, component upgrade, schema migration, or execution on a different supported platform. Consumers must not persist a report-local ID as global SVG identity.

## Report-local object namespace

Within one report, the following object IDs are nonempty and globally unique:

- `SubjectAlignment.id`;
- `ChangedFact.id`;
- `AtomicDifference.id`;
- `VisualEvent.id`;
- `DifferenceRegion.id`;
- `Diagnostic.id`.

The prefixes are human-readable conventions, not separate namespaces. A duplicate is invalid even if it occurs on different record kinds.

## Reference closure

The following fields are report-local references and must contain no duplicate targets:

| Reference | Required target |
| --- | --- |
| `AtomicDifference.subject_alignment_id` when non-null | one Subject Alignment |
| `AtomicDifference.changed_fact_ids[]` | Changed Facts |
| `AtomicDifference.computed_relation.diagnostic_ids[]` | Diagnostics |
| `VisualEvent.atomic_difference_ids[]` | Atomic Differences |
| `DifferenceRegion.cause_envelope.candidate_changed_fact_ids[]` | Changed Facts |
| `DifferenceRegion.cause_envelope.diagnostic_ids[]` | Diagnostics |
| `FeatureCoverage.diagnostic_ids[]` | Diagnostics |
| `RendererCapabilityGap.diagnostic_ids[]` | Diagnostics |

Every Atomic Difference belongs to exactly one Visual Event. Empty reference arrays remain valid when the corresponding evidence needs no target.

## Source-subject identity boundary

`SubjectReference.authored_id`, `ChangedFact.subject_id`, `ChangedFact.affected_subject_ids`, `VisualEvent.primary_subject_id`, `Diagnostic.subject_id`, `FeatureCoverage.subject_id`, and source-resolution subject fields identify authored or derived SVG subjects. Schema `1.1` has no canonical subject table, so these fields are not report-local foreign keys and are not covered by reference closure. Authored IDs may be absent or duplicated in malformed or adversarial source, and generated subject labels are meaningful only under the analyzer that emitted them.

## Ordering boundary

Repeated identical comparisons preserve every emitted array order. Same-domain difference ordering additionally follows [`v1_domain_lexicographic`](domain-ordering.md). This contract does not invent semantic ordering for JSON object members, cross-domain importance, or source subjects that the current alignment model cannot distinguish.

The executable gate is the [determinism evaluation](../evaluation/determinism/README.md). It uses independent release-CLI processes, both JSON modes, a non-default viewport, multi-event output, partial reports, and negative integrity controls.
