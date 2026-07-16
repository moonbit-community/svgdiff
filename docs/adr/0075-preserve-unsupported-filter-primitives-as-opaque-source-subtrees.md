# ADR 0075: Preserve unsupported filter primitives as opaque source subtrees

- Status: accepted
- Date: 2026-07-15
- Decision owners: svgdiff maintainers
- Extends: ADR 0073

## Context

ADR 0073 executes a bounded graph of direct static `feOffset` primitives and correctly guards every other primitive. The guard prevents false equality, but the filter model previously discarded an unsupported primitive after emitting its Diagnostic. Consequently, changing `stdDeviation`, replacing one unknown primitive with another, or editing nested content could leave no Atomic Difference for a text-only Agent to inspect.

Unknown primitive semantics do not permit safe attribute-level normalization or semantic alignment. A complete renderer for every filter primitive is a separate roadmap expansion, but source changes must remain observable now.

## Decision

Treat every direct unsupported filter primitive as one opaque source-semantic subtree:

- retain its direct-child position, local element name, resource-qualified subject ID, and exact full-subtree Source Span;
- keep only offsets in the internal filter model and slice source text when constructing a Diagnostic or report fact;
- align before and after records by direct-child position;
- when either side at a position is unsupported, compare the byte-preserving complete subtree and emit at most one `resource.filter.primitive.source` difference for that position;
- report insertion, deletion, type, attribute, namespace spelling, nested element, text, comment, and formatting changes conservatively;
- attach every affected filter consumer, but expose only `source_semantics`, an indeterminate computed relation, existing filter Diagnostics, no numeric magnitude, no rendered evidence, and no Difference Region;
- retain fine-grained graph, offset, raster, bounds, and Cause Envelope behavior when both aligned primitives are admitted `feOffset` nodes.

Position alignment is deliberately conservative. Inserting an unknown primitive may shift later positions and produce more than one source difference. This false-positive cost is accepted because an unknown graph cannot justify identity matching that could erase the real changed subtree.

Existing source and structure limits bound retained offsets and eventual report text. Malformed XML remains a failed input rather than a partially captured opaque record. Direct metadata children remain nonvisual and excluded.

## Consequences

A partial filter report now tells a text-only Agent exactly what unknown source changed and which hosts may be affected. It still makes no claim that the change is visible, how large it is, or which pixels it affects. Later support for another primitive may replace its opaque record with finer typed facts only if the new analyzer preserves at least the same source-difference coverage.

Structured Report schema advances to `1.31` for the new domain. The renderer identity and conformance profile remain unchanged because this decision adds no rendering capability.

## Rejected alternatives

- Emit only a Diagnostic: safe against false equality but loses the changed source itself.
- Parse a guessed common attribute set: can miss primitive-specific or nested semantics.
- Canonicalize unknown XML before comparison: risks erasing a source distinction whose visual meaning is unknown.
- Align unknown primitives by element name or authored ID: can silently pair the wrong graph nodes after insertion or reordering.
- Render every primitive in this item: substantially broader than deterministic fail-open source reporting.

## Evidence

- [`filter_semantics_wbtest.mbt`](../../engine/filter_semantics_wbtest.mbt)
- [`unsupported-filter-primitive-change.json`](../../schema/examples/unsupported-filter-primitive-change.json)
- [`ISS-119`](../../issues/ISS-119.md)
