# Subject Alignment Tie-Breaking

Status: current v1 policy

Last verified: 2026-07-14

Subject Alignment minimizes supported visual-property distance within compatible subject kinds after exact visual-signature matching and the current split/merge rules. When more than one accepted pairing has the same evidence and cost, v1 chooses one deterministically so identical inputs produce stable report order and IDs.

## Exact visual-signature ties

The engine visits before subjects in source index order. For each subject it selects the first unused after subject, also in source index order, whose kind, hierarchy signature, and normalized supported visual-property signature are identical. Authored `id` values are not part of this signature and do not override the visual tie.

Thus two visually indistinguishable duplicate subjects pair by `(before source_index, after source_index)` in ascending order even if their authored IDs suggest a different pairing. This is deterministic provenance, not authoritative cross-document identity.

## Equal minimum-cost ties

Unmatched subjects are grouped by SVG kind. Each side is sorted first by its visual signature using MoonBit `String::compare` shortlex order and then by source index. The rectangular Hungarian assignment minimizes total supported property distance. When reduced candidate costs are equal, iteration retains the first candidate in that stable ordering. Pair emission follows the stable assignment column order.

The tie-break inputs are therefore:

1. compatible subject kind;
2. normalized visual and hierarchy signature in MoonBit shortlex order;
3. source index within identical signatures;
4. first stable candidate within an equal-cost assignment.

## Selection evidence

Schema `1.1` adds an optional `evidence` record to each Subject Alignment; current producers always emit it. `score_kind` identifies the selection rule, `selected_score` retains its numeric result when the rule has one, `candidate_count` records the local candidate set, and `equal_score_candidate_count` records candidates with the selected local score. Exact-signature evidence conservatively uses the larger count of indistinguishable before or after endpoints, so duplicate subjects on either side remain visibly tied. Property-distance evidence counts compatible endpoints on the opposite side of the selected assignment row.

`ambiguity` has three values:

- `unique`: exactly one candidate has the selected local score;
- `tied`: two or more candidates have the selected local score and the deterministic tie-break selected one;
- `not_assessed`: the structural, unmatched, or group-specific rule does not expose a comparable numeric candidate set.

These counts are local evidence, not an enumeration of every globally optimal assignment. In particular, `unique` does not prove authoritative cross-document identity or exclude a different global assignment with the same total cost.

## Interpretation boundary

A selected alignment is never made certain merely because it is deterministic. Current producers serialize `confidence: null` and `confidence_status: "not_calibrated"`; no probability or calibration corpus exists. Agents may rely on repeatability and report the local ambiguity, but must not turn `unique` into identity proof, turn `tied` into equality, or invent confidence from candidate counts. Absence of `evidence` in a compatible report means the producer did not report uncertainty evidence, not that the match was unique.

The [report determinism gate](../evaluation/determinism/README.md) checks repeated process-level output. Alignment integration tests separately fix exact-duplicate and equal-cost pair membership, evidence counts, ambiguity status, and null confidence.
