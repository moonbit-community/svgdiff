# Structured Report Determinism and Local Identifiers

Status: current schema `1.6` contract

Last verified: 2026-07-14

For the same executable, exact before and after SVG bytes, and Comparison Profile, `svgdiff` emits the same Structured Report content, array ordering, report-local identifiers, and serialization bytes on repeated runs. Default formatted JSON and compact Agent JSON have different whitespace but decode to exactly the same report evidence.

This guarantee is report-local. It does not promise that IDs survive an input edit, profile change, component upgrade, or schema migration. Consumers must not persist a report-local ID as global SVG identity.

## Cross-platform executable gate

The current supported determinism matrix is Ubuntu 24.04 x64, Windows Server 2025 x64, and macOS 15 arm64. CI builds one revision in native release mode on every matrix entry and compares exact canonical default and compact report bytes for the versioned eight-case determinism corpus. The compared `svgdiff-determinism-bundle/1` contains only platform-neutral report bytes and their stable manifest; runner identity, local paths, toolchain output, and timestamps cannot create artificial differences.

Aggregation requires all three named platform bundles and rejects missing or extra files, digest mismatches, and byte divergence. A local harness proves those rejection rules with positive, divergent-byte, and missing-file controls. This is a regression gate over the declared corpus, not exhaustive proof for every possible SVG, cross-version identity, or binary-release reproducibility.

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

Every Atomic Difference belongs to exactly one owning Visual Event. A Changed Fact may still be referenced by several Atomic Differences in different events; that is causal fan-out, not duplicate event ownership. Empty reference arrays remain valid when the corresponding evidence needs no target.

## Source-subject identity boundary

`SubjectReference.authored_id`, `ChangedFact.subject_id`, `ChangedFact.affected_subject_ids`, `VisualEvent.primary_subject_id`, `Diagnostic.subject_id`, `FeatureCoverage.subject_id`, and source-resolution subject fields identify authored or derived SVG subjects. Schema `1.6` has no canonical subject table, so these fields are not report-local foreign keys and are not covered by reference closure. Authored IDs may be absent or duplicated in malformed or adversarial source, and generated subject labels are meaningful only under the analyzer that emitted them.

## Ordering boundary

Repeated identical comparisons preserve every emitted array order. Same-domain difference ordering additionally follows [`v2_domain_lexicographic`](domain-ordering.md). This contract does not invent semantic ordering for JSON object members, cross-domain importance, or source subjects that the current alignment model cannot distinguish.

The executable gate is the [determinism evaluation](../evaluation/determinism/README.md). It uses independent release-CLI processes, both JSON modes, a non-default viewport, multi-event output, partial reports, negative integrity controls, and exact bundle comparison across the supported platform matrix.
