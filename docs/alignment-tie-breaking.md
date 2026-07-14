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

## Interpretation boundary

A selected alignment with the same minimum cost as an alternative is not proven unique or high-confidence. Schema `1.0` records `basis` but has no ambiguity, alternatives, or confidence fields. Agents may rely on repeatability, not infer certainty from the tie-break. Explicit ambiguity evidence remains a separate roadmap item and may require an additive Schema change.

The [report determinism gate](../evaluation/determinism/README.md) checks repeated process-level output. Alignment integration tests separately fix exact-duplicate and equal-cost pair membership.
