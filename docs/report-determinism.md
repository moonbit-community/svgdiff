# Structured Report Determinism and Local Identifiers

Status: current schema `4.0` contract

Last verified: 2026-07-17

For the same executable, exact before and after SVG bytes, exact ordered resource-bundle entries, and Comparison Profile, `svgdiff` emits the same Structured Report content, array ordering, report-local identifiers, and serialization bytes on repeated runs. Default formatted JSON and compact Agent JSON have different whitespace but decode to exactly the same report evidence.

Computed LDR-FLIP maps are part of this byte contract. Their explicit pixels per degree, event-local bounds, uint16 quantization, big-endian ordering, and padded base64 serialization are deterministic; the cross-platform corpus includes one opt-in computed map. This does not make a before-context event map invariant under reversing a comparison or across metric-version changes.

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
| `ImpactFrontierGroup.event_ids[]` | Visual Events |
| `ImpactFrontierGroup.atomic_difference_ids[]` | Atomic Differences |
| `ImpactDominationWitness.dominant_event_id` | one Visual Event |
| `ImpactDominationWitness.dominated_event_id` | one Visual Event |
| `DifferenceRegion.cause_envelope.candidate_changed_fact_ids[]` | Changed Facts |
| `DifferenceRegion.cause_envelope.diagnostic_ids[]` | Diagnostics |
| `FeatureCoverage.diagnostic_ids[]` | Diagnostics |
| `RendererCapabilityGap.diagnostic_ids[]` | Diagnostics |

Every Atomic Difference belongs to exactly one owning Visual Event. A Changed Fact may still be referenced by several Atomic Differences in different events; that is causal fan-out, not duplicate event ownership. Empty reference arrays remain valid when the corresponding evidence needs no target.

For each Impact frontier group, `atomic_difference_ids` is the exact stable de-duplicated union of the differences owned by its listed events. This establishes the summary edge semantically, not merely syntactically. From those events, an Agent reaches Difference Regions and Cause Envelopes; from their differences, it reaches Changed Facts and computed-relation Diagnostics; from each Cause Envelope, it reaches candidate Changed Facts and causal Diagnostics. Impact Assessment does not duplicate those downstream records.

## Source-subject identity boundary

`SubjectReference.authored_id`, `SubjectReference.instance_context`, `ChangedFact.subject_id`, `ChangedFact.affected_subject_ids`, `VisualEvent.primary_subject_id`, `Diagnostic.subject_id`, `FeatureCoverage.subject_id`, and source-resolution subject fields identify authored or derived SVG subjects. Schema `4.0` has no canonical subject table, so these fields are not report-local foreign keys and are not covered by reference closure. Authored IDs may be absent or duplicated in malformed or adversarial source, and generated subject labels are meaningful only under the analyzer that emitted them. A use instance ID is deterministically derived from its outer-to-inner use path plus definition subject ID; it does not replace the corresponding authored ID or Source Span. An opaque filter primitive subject is derived from its filter resource subject plus zero-based direct-child position; insertion may therefore shift later labels and conservatively produce additional differences.

## Ordering boundary

Repeated identical comparisons preserve every emitted array order. Same-domain difference ordering additionally follows [`v2_domain_lexicographic`](domain-ordering.md). Impact frontier groups, tied event IDs, and domination witnesses use MoonBit `String::compare` shortlex event-ID order solely for stable representation; Atomic Difference links inside each group preserve existing report order. Distinct frontier groups remain incomparable and their array position is not a total cross-domain importance ranking. This contract does not invent semantic ordering for JSON object members or source subjects that the current alignment model cannot distinguish.

Rendered entity alignments are emitted first. Equal-cardinality repeated exact visual and reportable source-semantic signatures emit one equivalence-class alignment with endpoints in source traversal order but no pairwise positional meaning. Remaining same-kind candidates are stably sorted by their visual, hierarchy, cumulative-transform, and conservative-bounds signature and source index before the deterministic Hungarian assignment minimizes `rendered_geometry_feature_distance_v1`. Equal costs retain the first candidate in that order, and selected pairs emit by before then after source index. Source-structural entity and resource alignments follow in authored traversal order: recursive semantic-signature classes, authored-ID matches, structural-path matches, stable same-kind matches in sorted kind order, deletions, then insertions. Image resource alignments follow their entity placement alignments. Every tied class or fallback remains explicitly tied and uncalibrated.

The executable gate is the [determinism evaluation](../evaluation/determinism/README.md). It uses independent release-CLI processes, both JSON modes, a non-default viewport, multi-event output, partial reports, negative integrity controls, and exact bundle comparison across the supported platform matrix.

The [terminal operational gate](../evaluation/terminal-operational-gate/README.md) composes this report-byte contract with installation, archive provenance, version dispatch, hostile-input controls, and the fixed CI/release matrix. It does not reinterpret report determinism as bit-identical executable or cross-toolchain reproducibility.
