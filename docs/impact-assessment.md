# Raw Magnitudes and Impact Assessment Boundary

Status: current schema `1.21` contract

Last verified: 2026-07-14

Schema `1.21` has no Impact Assessment, severity label, universal similarity score, or cross-domain ranking scalar. The authoritative quantitative evidence is the raw measurement surface retained in the Structured Report:

- `AtomicDifference.magnitude` for continuous parameter, relative, device-space, viewport-relative, presence, and raster observations;
- optional tagged `AtomicDifference.magnitude.transform_effect` for raw translation, rotation, signed-scale, skew, or singular residual-matrix effects;
- optional `AtomicDifference.presence_magnitude` for inserted or deleted subject count, bounds, and isolated painted footprint;
- `VisualEvent.rendered_outcome.magnitude` for the canonical event raster response.

Unavailable observations remain null or explicitly not computed. Numeric zero is a measured result and cannot be replaced by absence, while absence cannot be converted to zero.

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
