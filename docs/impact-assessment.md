# Raw Magnitudes and Impact Assessment Boundary

Status: current schema `1.44` contract

Last verified: 2026-07-17

Schema `1.44` retains every raw measurement and adds one required top-level `ImpactAssessment`. The assessment identifies the current main Visual Events without replacing the evidence that produced them. It is not a severity label, universal similarity score, visibility judgment, equality rule, or total cross-domain ranking.

This required assessment is the machine-readable main-event summary for the Agent-oriented Structured Report. The complete `events` and `atomic_differences` arrays remain authoritative inventories; no second summary surface is defined.

## Authoritative measurement surface

The Structured Report retains:

- `AtomicDifference.magnitude` for continuous local parameter, exact CSS-pixel parameter, viewport-diagonal, entity-relative, symmetric painted-boundary displacement, alpha-only painted-coverage difference, geometry-outcome, presence, and raster observations;
- optional tagged `AtomicDifference.magnitude.transform_effect` for raw translation, rotation, signed-scale, skew, or singular residual-matrix effects;
- optional `AtomicDifference.presence_magnitude` for inserted or deleted subject count, bounds, and isolated painted footprint;
- `VisualEvent.rendered_outcome.magnitude` for the canonical event raster response;
- `VisualEvent.rendered_outcome.perceptual_color` for event-local changed-pixel mean DeltaEOK;
- optional `VisualEvent.rendered_outcome.perceptual_flip` for an event-local spatial LDR-FLIP map plus separately pooled canvas, selected-event, response-tail, maximum, and explicit-threshold-area evidence under recorded Viewing Conditions.

Unavailable observations remain null or explicitly not computed. Numeric zero is a measured result and cannot be replaced by absence, while absence cannot be converted to zero.

`ComparisonProfile.perceptual_background`, `flip_viewing_conditions`, and `flip_error_threshold` are explicit measurement inputs, not impact signals. Parameter, boundary, coverage, DeltaEOK, and FLIP channels retain their own units and denominators. The Impact Assessment does not silently normalize or combine them.

`AtomicDifference.domain_ordering` remains a separate versioned view for ordering only differences from the exact same domain. Its tuples are not cross-domain scores and do not determine the Impact Assessment.

## `event_rendered_pareto/v1`

The current policy evaluates every emitted Visual Event using exactly two common whole-canvas fields:

1. `events[].rendered_outcome.magnitude.changed_pixel_fraction`;
2. `events[].rendered_outcome.magnitude.linear_premultiplied_rgba_rmse`.

The report repeats these field paths in `impact_assessment.input_fields`. Both values are nonnegative raw rendered measurements with a shared canvas context, but they remain distinct dimensions.

Event A dominates event B only when A is greater than or equal to B in both dimensions and strictly greater in at least one. The main-event frontier contains every event not dominated by another event. This makes the frontier complete for the declared two-dimensional rule without inventing weights or thresholds.

Exact measured vectors form one tie group. Different non-dominated vectors remain separate incomparable groups. An event whose rendered magnitude is unavailable remains in a separate incomparable group with `measurements: null`; it is never treated as zero and cannot be dominated through fabricated evidence. If any candidate lacks the required measurements, `status` is `partial`; otherwise it is `complete`. An empty event inventory is `not_applicable`.

`frontier_relation` summarizes only the frontier representation:

- `not_applicable`: there are no candidate events;
- `unique`: one frontier group contains one event; inspect `status` and `measurements` to distinguish measured from unavailable evidence;
- `tied`: one measured frontier group contains multiple events with the same vector;
- `incomparable`: multiple frontier groups each contain one event;
- `mixed`: multiple frontier groups and at least one contains an exact measured tie.

Missing evidence is expressed independently through `status: "partial"` and a group's null `measurements`; it does not receive a fabricated relation category.

Each `frontier_group` lists its Visual Event IDs and the complete Atomic Difference IDs contributed by those events. IDs are representation links, not new causes. Groups and witnesses use MoonBit `String::compare` shortlex event-ID order solely for deterministic serialization; Atomic Difference IDs preserve their existing report order.

The [M3 compact-summary traceability gate](../evaluation/m3-summary-traceability-gate/README.md) recomputes that exact ordered event-to-difference union and then follows the existing typed report references to regions, Cause Envelopes, Changed Facts, Subject Alignments, and Diagnostics. Those transitive links are the lossless summary seam; the assessment deliberately does not duplicate downstream evidence.

Every dominated event has exactly one `domination_witness`. The witness names the first event under that same shortlex order among all events that dominate it and records rule `both_rendered_metrics_no_less_and_one_greater`. The witness explains exclusion from the frontier; it is not a claim that the chosen dominator is the only or closest cause.

The assessment declares `calibration_status: "not_calibrated"`. Corpus tiers such as `none`, `low`, `medium`, and `high` remain hidden evaluation labels and do not enter production reports. The first versioned [calibration study](../evaluation/impact-calibration/README.md) rejected all evaluated production threshold and total-order candidates. A later retry may define calibrated thresholds or ordering only after its recorded evidence prerequisites are met, and it must allocate a new policy identity rather than changing this policy in place.

## Agent procedure

For a request about the main visual differences:

1. reject or explicitly migrate an unknown `policy_id`;
2. read every `frontier_group`, not just the first serialized group;
3. describe exact ties as ties and distinct frontier groups as incomparable under this policy;
4. disclose `partial` status and null measurements instead of treating missing evidence as small impact;
5. follow the linked Visual Events and Atomic Differences for domains, subjects, source evidence, regions, causes, raw magnitudes, coverage, and Diagnostics;
6. avoid translating the frontier into low, medium, high, visible, invisible, important, or unimportant without a separate explicit policy.

For a request that additionally names a caller concern, first enumerate the complete `events` and `atomic_differences` inventories. Resolve the concern only through context supplied by the caller and report evidence such as a subject, event, difference, Changed Fact, source location, or Difference Region. Every matching item must be reported even when its event is absent from the frontier; use a domination witness only to explain that context-free exclusion. Authored identifiers may locate a caller-named target, but they do not create the importance judgment.

If the caller's phrase cannot be resolved to report evidence, state that its semantic importance or identity is unknown and still enumerate every reported difference. Never use pixel thresholds or frontier membership to suppress the complete inventory. The focused [semantic-concern evaluation](../evaluation/semantic-concern/README.md) verifies that a dominated one-pixel event remains recoverable through both normal and Agent JSON.

## Policy evolution requirements

Any future Impact Assessment remains additive and derived. It must retain every raw magnitude and availability state, identify an opaque versioned policy ID, state all inputs and rules, preserve event and difference links, and remain unable to create or erase an Atomic Difference, establish equality, or override coverage and Diagnostics.

A calibrated policy must additionally identify its calibration corpus, label version, metric versions, required Comparison Profile fields, thresholds or learned parameters, and deterministic tie behavior. Changing candidate selection, inputs, normalization, dominance, missing-value behavior, grouping, witness selection, thresholds, labels, weights, or ordering requires a new policy ID under the [versioning contract](versioning.md#impact-assessment-policy-compatibility).

[ADR 0039](adr/0039-do-not-adopt-a-universal-cross-domain-scalar.md) rejects a universal cross-domain scalar, [ADR 0088](adr/0088-define-an-uncalibrated-event-impact-frontier.md) defines the current structured frontier, [ADR 0089](adr/0089-reject-impact-calibration-from-the-v1-corpus.md) records why the current labels cannot yet justify a calibrated production policy, and [ADR 0091](adr/0091-separate-query-concern-from-context-free-impact.md) keeps caller concern outside context-free Impact.
