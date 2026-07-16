# Subject Alignment Tie-Breaking

Status: current v1 policy

Last verified: 2026-07-15

Rendered-shape Subject Alignment minimizes a bounded device-space feature distance within compatible subject kinds after exact visual-signature matching and the current split/merge rules. Source-structural alignment uses a separate deterministic rule chain for groups, text, use hosts, and visual resource definitions. When more than one accepted pairing has the same evidence and cost, v1 chooses one deterministically so identical inputs produce stable report order and IDs.

## Source-structural subjects

Structural subjects pair only within the same SVG kind. The engine first groups an equal-cardinality class with the same recursive semantic signature. That signature ignores the subject's own authored ID, sibling ordinal, attribute order, unprefixed `aria-*`/`data-*`, and namespace declaration spelling while preserving SVG kind, other attributes, direct text for text subjects, and ordered child signatures. Remaining subjects select the first unused after subject with the same non-empty authored ID, then the same structural path, then stable same-kind source order. Remaining endpoints become insertion or deletion alignments. The bases are `structural_semantic_signature`, `structural_authored_id`, `structural_path`, `stable_kind_order`, and `unmatched_structural_subject`.

An equal semantic class retains every endpoint in one set alignment. A one-member class is locally `unique`; a larger class is `tied` with its cardinality in both candidate counts. Authored IDs, structural paths, and source order remain weaker correspondence hints, not identity proof. Unequal-cardinality and mixed-change clusters can still reach those fallbacks until broader many-to-many invariants are accepted.

## Exact visual-signature ties

The engine visits before subjects in source index order and identifies unused after subjects whose kind, hierarchy signature, normalized supported visual-property signature, cumulative-transform completeness and matrix, and conservative device-space painted-bounds signature are identical. Authored `id` values are not part of this signature and do not override the visual evidence.

When the same exact visual signature and the same currently reportable declaration, path-command, and transform-chain source semantics occur more than once with equal cardinality on both sides, the engine emits one `exact_visual_equivalence_class` alignment containing all endpoints. The source-semantic guard keeps visually equivalent authoring differences in ordinary one-to-one alignments where Atomic Differences can report them. Array order is deterministic source provenance only: consumers must not zip the arrays or infer pairwise correspondence. A one-member exact class retains the ordinary `exact_visual_signature` basis. Unequal-cardinality classes retain the current deterministic fallback so insertions, deletions, and changed subjects are not silently collapsed.

## Equal minimum-cost ties

Unmatched subjects are grouped by SVG kind. Each side is sorted first by its exact alignment signature using MoonBit `String::compare` shortlex order and then by source index. The rectangular Hungarian assignment minimizes the total `rendered_geometry_feature_distance_v1`. When reduced candidate costs are equal, iteration retains the first candidate in that stable ordering. Selected pairs are emitted by before source index, then after source index, so internal candidate ordering does not reorder downstream source fan-out.

The feature score is the arithmetic mean of independently available values in `[0, 1]`: conservative painted-bounds center and size displacement normalized by the actual Comparison Viewport diagonal, supported non-geometry appearance-property difference, hierarchy agreement, and device-space normalized path segment difference for paths. Numeric deltas use `d / (1 + d)`. Raw basic-shape geometry is excluded from appearance distance. If both painted bounds are unavailable, four cumulative-transform probes at the viewport corners substitute for the bounds feature; probes are not added when bounds already encode final placement. One-sided bounds or transform availability contributes `1`, while a feature unavailable on both sides is omitted. Complete non-arc paths use transformed endpoint and Bezier-control hulls for conservative bounds; arcs retain unavailable bounds.

The tie-break inputs are therefore:

1. compatible subject kind;
2. exact repeated equivalence-class extraction where cardinalities agree;
3. normalized visual, hierarchy, cumulative-transform, and bounds signature in MoonBit shortlex order;
4. source index within unresolved signatures;
5. first stable candidate within an equal-cost assignment.

## Selection evidence

Schema `1.1` adds an optional `evidence` record to each Subject Alignment; current producers always emit it. `score_kind` identifies the selection rule, `selected_score` retains its numeric result when the rule has one, `candidate_count` records the local candidate set, and `equal_score_candidate_count` records candidates with the selected local score. Exact rendered equivalence classes retain score zero and their full cardinality. `structural_semantic_signature` is candidate-only exact source-semantic evidence with a null score. `rendered_geometry_feature_distance_v1` evidence counts compatible endpoints on the opposite side of the selected assignment row. Its selected score is bounded and dimensionless, but it is only a versioned correspondence cost: consumers must not interpret it as a Difference Magnitude, perceptual distance, probability, or equality threshold.

`ambiguity` has three values:

- `unique`: exactly one candidate has the selected local score;
- `tied`: two or more candidates have the selected local score and the deterministic tie-break selected one;
- `not_assessed`: the structural, unmatched, or group-specific rule does not expose a comparable numeric candidate set.

These counts are local evidence, not an enumeration of every globally optimal assignment. In particular, `unique` does not prove authoritative cross-document identity or exclude a different global assignment with the same total cost.

## Interpretation boundary

A selected alignment is never made certain merely because it is deterministic. Current producers serialize `confidence: null` and `confidence_status: "not_calibrated"`; no probability or calibration corpus exists. Agents may rely on repeatability and report the local ambiguity, but must not turn `unique` into identity proof, turn `tied` into equality, or invent confidence from candidate counts. Absence of `evidence` in a compatible report means the producer did not report uncertainty evidence, not that the match was unique.

The [report determinism gate](../evaluation/determinism/README.md) checks repeated process-level output. Alignment integration tests separately fix exact-duplicate class membership, semantic structural matching, equal-cost pair membership, evidence counts, ambiguity status, and null confidence.
