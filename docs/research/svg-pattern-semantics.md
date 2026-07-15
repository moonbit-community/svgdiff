# SVG Pattern Semantics Research

Status: implementation reference for schema `1.18`

Last verified: 2026-07-15

## Primary specification

The implementation follows [W3C SVG 2, Patterns](https://www.w3.org/TR/SVG2/pservers.html#Patterns).

The engine relies on these requirements:

- the pattern tile is the rectangle established by `x`, `y`, `width`, and `height`, repeated in both axes;
- `patternUnits` defaults to `objectBoundingBox`, while `patternContentUnits` defaults to `userSpaceOnUse`;
- a valid `viewBox` establishes the content viewport and makes `patternContentUnits` irrelevant;
- `patternTransform` is applied after the implicit object-bounding-box mapping;
- `x`, `y`, `width`, and `height` default to zero; negative dimensions are errors and zero dimensions disable painting;
- `href` may reference another same-document `pattern`; missing pattern attributes inherit recursively, and the nearest referenced non-descriptive child set is cloned only when the referencing pattern has no such children;
- cloned content inherits properties through the referencing pattern host rather than the painted consumer;
- pattern overflow is hidden by default, while visible overflow behavior is not sufficiently bounded for the current contract.

## Engineering interpretation

The analyzer keeps three levels separate: authored resource facts, resolved pattern semantics, and consumer-specific paint. Object-bounding-box coordinates cannot be finalized without target bounds, and user-space coordinates still depend on the consumer's current coordinate system. Consequently one resolved resource can have several consumer signatures.

The admitted child slice is intentionally finite: static `rect`, `circle`, `ellipse`, `line`, `polyline`, and `polygon` content with supported local containers, transforms, cascade/inheritance, solid sRGB paint, and opacity. A template child is reparented only in the computed hierarchy; its declaration origin and Source Span remain attached to the original source node. Unsupported descendants are diagnosed at any depth.

The cause inventory is conservative. Invalid or external references, cycles, dynamic content, visible overflow, unavailable bounds, malformed coordinate values, and arbitrary child resources prevent complete computed equality. This can over-report possible causes, which is compatible with the project's sound-overapproximation goal; it must not omit a modeled true cause.

## Renderer evidence

Six deterministic Chromium fixtures cover object-bounding-box and user-space tiles, object-bounding-box content, `viewBox`, `patternTransform`, and template inheritance. The user-space fixture is exact; the other five differ on 32 to 96 pixels with maximum channel deltas from 89 to 255. All observations are bound to `svgdiff-renderer-conformance-profile/15`, and the divergent modes have executable `renderer_pattern_raster_unproven` dispositions. Because one exact mode does not establish the remaining coordinate, viewport, transform, and template modes, referenced patterns retain that guard for Rendered Evidence only.
