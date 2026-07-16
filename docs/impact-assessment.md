# Raw Magnitudes and Impact Assessment Boundary

Status: current schema `1.42` contract

Last verified: 2026-07-16

Schema `1.42` has no Impact Assessment, severity label, universal similarity score, or cross-domain ranking scalar. The authoritative quantitative evidence is the raw measurement surface retained in the Structured Report:

- `AtomicDifference.magnitude` for continuous local parameter, exact CSS-pixel parameter, viewport-diagonal, entity-relative, symmetric painted-boundary displacement, alpha-only painted-coverage difference, geometry-outcome, presence, and raster observations;
- optional tagged `AtomicDifference.magnitude.transform_effect` for raw translation, rotation, signed-scale, skew, or singular residual-matrix effects;
- optional `AtomicDifference.presence_magnitude` for inserted or deleted subject count, bounds, and isolated painted footprint;
- `VisualEvent.rendered_outcome.magnitude` for the canonical event raster response;
- `VisualEvent.rendered_outcome.perceptual_color` for event-local changed-pixel mean DeltaEOK;
- optional `VisualEvent.rendered_outcome.perceptual_flip` for an event-local spatial LDR-FLIP map plus separately pooled canvas, selected-event, response-tail, maximum, and explicit-threshold-area evidence under recorded Viewing Conditions.

Unavailable observations remain null or explicitly not computed. Numeric zero is a measured result and cannot be replaced by absence, while absence cannot be converted to zero.

`ComparisonProfile.perceptual_background`, `flip_viewing_conditions`, and `flip_error_threshold` are explicit measurement inputs, not impact signals. Supplying them does not alter transparent-canvas raw rendering. The background enables event-local changed-pixel mean DeltaEOK and, when pixels per degree are also present, event-local LDR-FLIP plus unquantized pooled statistics after both sides are composited over exactly that color in linear sRGB. The optional threshold enables only strict-above area. Missing inputs or raw rendering remain explicitly not computed.

The parameter fields are not interchangeable normalizations. `parameter_viewport_fraction` and `parameter_entity_fraction` share the exact `parameter_abs_css_px` numerator but use the Comparison Viewport diagonal and the maximum nonzero per-side entity-bounds diagonal respectively. They describe scale, not visibility, salience, confidence, or severity. Outcome-oriented geometry and raster fields remain independent observations.

`painted_boundary_displacement` is likewise not a severity score. When two-sided isolated painting is available, it reports the symmetric nearest-boundary-pixel sample counts and the arithmetic mean, nearest-rank p95, and maximum distance in CSS pixels. It remains null when the bounded isolation measurement is unavailable. The measurement is raster-boundary evidence, not continuous Hausdorff distance, semantic point correspondence, signed motion, soft coverage, color difference, or perceptual importance.

`painted_coverage_difference` retains absolute CSS area as well as a normalized alpha-union fraction. The ratio alone cannot distinguish a one-pixel disjoint change from a full-canvas replacement, and zero means equal alpha coverage rather than equal color. It therefore remains one raw channel beside boundary, event raster, and perceptual color evidence.

Changed-pixel mean DeltaEOK is likewise not severity. It ignores unchanged pixels by design and has no spatial-frequency model. A small high-distance sample and a large high-distance event can share the same mean, so agents must quote sample count and independent area evidence.

The event-local LDR-FLIP map is spatial perceptual evidence, not severity. It depends on the recorded pixels per degree and alternating-image LDR protocol and may spread outside exact changed pixels through its filters. Its pooled statistics deliberately retain separate domains: whole-canvas mean, selected-event mean, complete-response p95, response maximum, and optional strict-above-threshold whole-canvas area. Consumers must not compare their denominators as if interchangeable, reconstruct them from the quantized map, or treat an explicit threshold as a calibrated visibility boundary.

`AtomicDifference.domain_ordering` is a versioned derived view for ordering only differences from the exact same domain. Every component of `v2_domain_lexicographic` is copied from a named retained raw magnitude field, in the order defined by the [Domain Ordering Policy](domain-ordering.md). Transform component domains deliberately retain different leading units and are incomparable with one another. The tuple does not contain a hidden score and is never more authoritative than its source fields.

The `none`, `low`, `medium`, and `high` tiers in the [human annotations](../evaluation/annotations/README.md) are hidden evaluation labels, not report evidence. Corpus directory names such as `subtle` or `salient` likewise do not enter production reports and must not be inferred as engine classifications.

## Future Impact Assessment requirements

Any future Impact Assessment must be additive and derived. It must:

1. retain every raw magnitude and availability state unchanged;
2. identify an opaque versioned policy ID;
3. state the exact input measurements, normalization, weights, thresholds, and tie-breaking rules;
4. identify the calibration corpus, label version, metric versions, and required Comparison Profile fields;
5. remain unable to create or erase an Atomic Difference, establish equality, or override coverage and Diagnostics;
6. preserve links from every assessment result to the contributing Visual Events and Atomic Differences;
7. allocate a new policy identity whenever interpretation changes.

Until those requirements and the separate roadmap policy and calibration items are complete, agents should quote named raw measurements and disclose any cross-domain interpretation instead of inventing a severity label.

[ADR 0039](adr/0039-do-not-adopt-a-universal-cross-domain-scalar.md) rejects a universal cross-domain scalar. A future Impact Assessment should begin as a structured, traceable policy result that permits ties or incomparability; scalar adoption can be reconsidered only after a concrete Agent task demonstrates that such a result is insufficient and a calibrated proposal satisfies the recorded evidence requirements.
