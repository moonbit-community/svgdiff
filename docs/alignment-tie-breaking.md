# Subject Alignment Tie-Breaking

Status: current v1 policy

Last verified: 2026-07-15

Rendered-shape Subject Alignment minimizes a bounded device-space feature distance within compatible subject kinds after exact visual-signature matching and the current split/merge rules. Source-structural alignment uses a separate deterministic rule chain for groups, text, use hosts, and visual resource definitions. When more than one accepted pairing has the same evidence and cost, v1 chooses one deterministically so identical inputs produce stable report order and IDs.

## Source-structural subjects

Structural subjects pair only within the same SVG kind. The engine first selects the first unused after subject with the same non-empty authored ID, then the first unused subject with the same structural path, then pairs remaining same-kind subjects in source order. Remaining endpoints become insertion or deletion alignments. The bases are `structural_authored_id`, `structural_path`, `stable_kind_order`, and `unmatched_structural_subject`.

Authored IDs, structural paths, and source order are correspondence hints, not identity proof. Repeated candidates report the larger compatible endpoint count as both `candidate_count` and `equal_score_candidate_count`; more than one is `tied`. The stable-order fallback deliberately exposes the limitation addressed by later structural repeated-subject work; rendered-leaf feature scoring does not silently change this separate source inventory.

## Exact visual-signature ties

The engine visits before subjects in source index order. For each subject it selects the first unused after subject, also in source index order, whose kind, hierarchy signature, normalized supported visual-property signature, cumulative-transform completeness and matrix, and conservative device-space painted-bounds signature are identical. Authored `id` values are not part of this signature and do not override the visual tie.

Thus two visually indistinguishable duplicate subjects pair by `(before source_index, after source_index)` in ascending order even if their authored IDs suggest a different pairing. This is deterministic provenance, not authoritative cross-document identity.

## Equal minimum-cost ties

Unmatched subjects are grouped by SVG kind. Each side is sorted first by its exact alignment signature using MoonBit `String::compare` shortlex order and then by source index. The rectangular Hungarian assignment minimizes the total `rendered_geometry_feature_distance_v1`. When reduced candidate costs are equal, iteration retains the first candidate in that stable ordering. Selected pairs are emitted by before source index, then after source index, so internal candidate ordering does not reorder downstream source fan-out.

The feature score is the arithmetic mean of independently available values in `[0, 1]`: conservative painted-bounds center and size displacement normalized by the actual Comparison Viewport diagonal, supported non-geometry appearance-property difference, hierarchy agreement, and device-space normalized path segment difference for paths. Numeric deltas use `d / (1 + d)`. Raw basic-shape geometry is excluded from appearance distance. If both painted bounds are unavailable, four cumulative-transform probes at the viewport corners substitute for the bounds feature; probes are not added when bounds already encode final placement. One-sided bounds or transform availability contributes `1`, while a feature unavailable on both sides is omitted. Complete non-arc paths use transformed endpoint and Bezier-control hulls for conservative bounds; arcs retain unavailable bounds.

The tie-break inputs are therefore:

1. compatible subject kind;
2. normalized visual, hierarchy, cumulative-transform, and bounds signature in MoonBit shortlex order;
3. source index within identical signatures;
4. first stable candidate within an equal-cost assignment.

## Selection evidence

Schema `1.1` adds an optional `evidence` record to each Subject Alignment; current producers always emit it. `score_kind` identifies the selection rule, `selected_score` retains its numeric result when the rule has one, `candidate_count` records the local candidate set, and `equal_score_candidate_count` records candidates with the selected local score. Exact-signature evidence conservatively uses the larger count of indistinguishable before or after endpoints, so duplicate subjects on either side remain visibly tied. `rendered_geometry_feature_distance_v1` evidence counts compatible endpoints on the opposite side of the selected assignment row. Its selected score is bounded and dimensionless, but it is only a versioned correspondence cost: consumers must not interpret it as a Difference Magnitude, perceptual distance, probability, or equality threshold.

`ambiguity` has three values:

- `unique`: exactly one candidate has the selected local score;
- `tied`: two or more candidates have the selected local score and the deterministic tie-break selected one;
- `not_assessed`: the structural, unmatched, or group-specific rule does not expose a comparable numeric candidate set.

These counts are local evidence, not an enumeration of every globally optimal assignment. In particular, `unique` does not prove authoritative cross-document identity or exclude a different global assignment with the same total cost.

## Interpretation boundary

A selected alignment is never made certain merely because it is deterministic. Current producers serialize `confidence: null` and `confidence_status: "not_calibrated"`; no probability or calibration corpus exists. Agents may rely on repeatability and report the local ambiguity, but must not turn `unique` into identity proof, turn `tied` into equality, or invent confidence from candidate counts. Absence of `evidence` in a compatible report means the producer did not report uncertainty evidence, not that the match was unique.

The [report determinism gate](../evaluation/determinism/README.md) checks repeated process-level output. Alignment integration tests separately fix exact-duplicate and equal-cost pair membership, evidence counts, ambiguity status, and null confidence.
