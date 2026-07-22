# ADR 0073: Own bounded static filter-offset graphs

- Status: rendering ownership superseded by ADR 0108; source/computed semantics remain accepted
- Date: 2026-07-15
- Decision owners: svgdiff maintainers
- Supersedes: the blanket filter deferral in the v1 scope

## Context

The terminal product goal requires a text-only Agent to distinguish source spelling, computed visual semantics, final raster response, affected location, and every possibly causal fact. Treating `filter` as an opaque unsupported attribute preserves safety but cannot explain a graph edit, quantify a small numeric offset, identify shared consumers, or localize the translated and clipped effect.

The pinned raw renderer does not provide a product-verifiable filter execution path. Chromium confirms the intended output, but browser automation is an evaluation oracle rather than an embeddable deterministic dependency. Implementing every Filter Effects primitive at once would create a broad, weakly tested surface and would obscure the graph, intermediate-surface, bounding, and reporting abstractions that later primitives need.

## Decision

Own a bounded static local filter-graph slice in the private engine and product renderer. Admit one same-document `filter` reference on an explicit-ID, untransformed basic-shape leaf. A complete graph contains only direct static `feOffset` primitives and resolves:

- non-inherited host cascade semantics;
- `filterUnits`, `primitiveUnits`, and the normative `-10% -10% 120% 120%` filter region;
- SourceGraphic, SourceAlpha, an omitted immediately previous input, and a named result from an earlier primitive;
- integer device-pixel offsets after unit resolution;
- a distinct transparent RGBA intermediate for every primitive, with hard filter-region clipping on inputs and outputs;
- a conservative bound for every intermediate and the final output;
- resource presence, units, region, primitive presence, input, result, dx, and dy differences with exact provenance, continuous magnitudes, and consumer fan-out.

A missing or wrong-kind local target deterministically applies no filter, while an empty admitted graph produces transparent black. Graph execution is capped at 256 primitives per graph and 16,777,216 aggregate primitive-surface pixels per source. External, malformed, duplicate, templated, transformed, fractional, dynamic, reused, interacting, over-budget, or unsupported cases retain source evidence behind precise Diagnostics; they do not inherit a broad guessed approximation.

The production renderer identity adds `static-filter-graph-compositor@1`. Four Chromium source/canonical pairs cover user-space offsets, object-bounding-box primitive units, named intermediate chains, and SourceAlpha. The raw dependency divergences remain recorded; executable compositor dispositions require the production source and canonical SVG to compare as complete with zero changed pixels.

## Consequences

The engine now has a reusable ordered-graph and intermediate-surface seam without claiming complete SVG Filter Effects support. Difference Regions and Cause Envelopes can use conservative translated/intersected bounds for admitted graphs, including occupied, vacated, and clipped-empty outcomes. A text-only Agent can report how much an offset changed and which graph edge or shared resource caused it instead of reducing the result to visible/not-visible.

The project owns additional deterministic rendering code, resource budgets, versioned Diagnostics, conformance fixtures, and compatibility identities. Later primitives must define their input/output color and alpha behavior, conservative bound transfer, surface budget, report domains, and Chromium evidence before entering the complete slice. Filter templates, primitive subregions, fractional offsets, transforms, reuse, effect interactions, CSS filter functions, blending, and all other primitives remain explicit future work.

## Rejected alternatives

- Keep every filter guarded: safe but fails the Agent-facing graph, magnitude, and localization requirements.
- Trust raw dependency filter output: contradicted by the Chromium baseline and provides no reviewed product contract.
- Raster-only comparison: detects some output changes but cannot report graph semantics, continuous offsets, source provenance, or causal fan-out.
- Implement the complete Filter Effects specification in one step: too broad to validate or maintain as one roadmap item.

## Evidence

- [`filter_semantics_wbtest.mbt`](../../engine/filter_semantics_wbtest.mbt)
- [`renderer-conformance`](../../evaluation/renderer-conformance/README.md)
- [`filter-offset-change.json`](../../schema/examples/filter-offset-change.json)
- [`ISS-117`](../../issues/ISS-117.md)
