# Validate safe alignment cardinalities in the production corpus

## Context

One-to-one, insertion, deletion, split, merge, and exact repeated set alignments had MoonBit seam tests, but the curated Agent benchmark did not require all six cardinality shapes from production CLI reports. The missing evaluation layer allowed a relationship to regress into noisy presence pairs or false positional identity without changing the benchmark gate.

The report can safely represent an exact repeated N-to-N class because no member-level Atomic Difference needs a fabricated pair. It cannot yet aggregate an unequal-cardinality or mixed-change repeated cluster without losing or misassigning member source differences.

## Decision

Give curated corpus cases optional `required_subject_alignments` containing only relation, before and after cardinalities, and an optional accepted basis. Execute every expectation through the production CLI, and require the corpus as a whole to cover 1-to-1, 0-to-1, 1-to-0, 1-to-N, N-to-1, and N-to-N shapes.

Use an exact two-to-two repeated equivalence class for the many-to-many case. Its hidden reference records pairwise identity as undefined, and neither source order nor array position identifies members. Keep mixed-change and unequal-cardinality repeated clusters on the existing conservative one-to-one and presence fallbacks until a report contract can enumerate all member differences without invented identity.

Keep alignment labels separate from visual main-change, ranking, region, and actual-cause labels. The Agent never receives hidden labels. Every new curated pair still receives the ordinary visual annotations so evaluation metrics remain corpus-complete.

## Consequences

The benchmark now detects cardinality, basis, membership, and pair-identity regressions in production output. Split and merge must remain set alignments rather than addition/deletion noise, and exact repeated subjects must remain one tied class. This is evaluation coverage for existing Structured Report semantics, so module version, report schema, renderer identity, and renderer conformance profile do not change.

The benchmark does not claim support for arbitrary changed N-to-M aggregation. That boundary remains explicit rather than being hidden behind a coarse structural difference that could omit source changes.
