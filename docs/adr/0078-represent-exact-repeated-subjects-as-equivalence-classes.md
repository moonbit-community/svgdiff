# Represent exact repeated subjects as equivalence classes

## Context

The alignment model permits sets on both sides, but exact rendered duplicates were emitted as arbitrary one-to-one pairs in source order. Source-structural subjects likewise preferred authored IDs and structural paths, then paired repeated same-kind subjects by source order. Those rules were deterministic, but they manufactured pairwise identity where the available visual or source-semantic evidence could not distinguish individual subjects.

Truly indistinguishable duplicates have no recoverable one-to-one identity without external evidence. Authored IDs may be renamed or exchanged, and sibling position is provenance rather than cross-document identity. A useful report must preserve every endpoint and expose ambiguity without hiding insertions, deletions, or changed subjects.

## Decision

After exact use-instance-path matching, group an equal-cardinality repeated rendered class with one transform- and bounds-aware exact signature and the same currently reportable declaration, path-command, and transform-chain source semantics into one correspondence alignment. The source-semantic guard is required because a multi-endpoint class cannot carry pairwise Atomic Differences: visually equivalent but differently authored subjects, such as `red` and `#ff0000`, retain one-to-one alignments and every source difference. The before and after arrays retain source traversal order only for provenance and deterministic serialization; their positions do not pair endpoints. The class records exact score zero, candidate and equal-score counts equal to its cardinality, `tied` ambiguity, and null uncalibrated confidence.

Give structural subjects a recursive semantic signature over SVG kind, order-independent attributes, direct text for text subjects, and ordered child signatures. Ignore the subject's own `id`, sibling ordinal, attribute order, unprefixed `aria-*` and `data-*`, and namespace declaration spelling. Preserve child order because it may affect stacking and semantics. Equal-cardinality matching semantic classes become one set alignment; a one-member class is locally unique. When signatures differ, retain authored-ID, structural-path, and stable-kind-order fallbacks so changed subjects remain traceable.

Do not group unequal-cardinality or mixed-change rendered clusters in this slice. Doing so without an accepted aggregation and difference-construction contract could hide presence or property differences. They retain the existing deterministic fallbacks and explicit ambiguity until the benchmark-wide many-to-many item fixes broader invariants.

## Consequences

Repeated exact subjects no longer acquire false pair identity merely because two arrays share an order. Renamed and reordered structurally distinct groups can match by their subtrees, while identical structural duplicates remain one tied set. The recursive signature is correspondence evidence, not computed equality, rendered equality, resource attribution, or confidence.

This adds the closed `structural_semantic_signature` score kind and changes the interpretation of repeated alignment arrays, advancing Structured Report schema to `1.34` and module version to `0.5.14`. Renderer identity and conformance profile `/25` remain unchanged because pixel execution is unchanged.
