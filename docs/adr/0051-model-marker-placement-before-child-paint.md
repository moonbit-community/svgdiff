# ADR 0051: Model marker placement before marker child paint

Status: accepted

Date: 2026-07-15

## Context

SVG markers combine several separable semantic layers: attachment properties on a host shape, vertices and path directions, marker viewport and reference-point mapping, repeated marker instances, marker child paint/cascade, and final renderer pixels. Treating that stack as one unsupported feature would lose exact source and geometry differences. Treating the pinned renderer as authoritative would be unsafe: focused Chromium fixtures show divergences for attachment roles, automatic orientation, marker units, viewport mapping, and zero-size suppression.

## Decision

The engine owns a renderer-independent marker placement model for the deterministic static slice. It retains authored `marker` shorthand and longhand facts, resolves only local fragment references, extracts canonical unitless marker resource properties, derives SVG start/mid/end vertices and automatic directions from equivalent paths, and composes placement, orientation, units, viewport mapping, reference offset, and subject transforms. Default hidden overflow makes the transformed marker viewport a conservative instance envelope.

Marker resource and attachment changes remain typed even when later evidence is guarded. Unreferenced resource changes are source-only. Missing, wrong-kind, external, malformed, invalid, or unsupported references and resource values emit source-located Diagnostics rather than implying equality.

Marker child paint, cascade/inheritance, `context-fill`/`context-stroke`, external references, non-unitless marker lengths, and visible overflow remain outside this slice. Referenced content emits `marker_content_semantics_unsupported`. Raw pinned-renderer output remains independently limited by `renderer_marker_raster_unproven`; conservative marker envelopes localize possible differences when raster evidence is unavailable.

## Consequences

- Agents receive exact authored and placement-level marker differences without requiring image understanding.
- Conservative regions may over-report because they bound the clipped marker viewport rather than exact child paint.
- A future marker-content implementation can deepen the resource module without changing attachment or placement semantics.
- Renderer conformance profile `/7` records five divergent marker fixtures; no browser-conformance claim is inferred from the dependency API.

## References

- [SVG 2 Markers](https://www.w3.org/TR/SVG2/painting.html#Markers)
- [SVG 2 Paths and marker direction](https://www.w3.org/TR/SVG2/paths.html)
- [SVG 2 basic-shape equivalent paths](https://www.w3.org/TR/SVG2/shapes.html)
