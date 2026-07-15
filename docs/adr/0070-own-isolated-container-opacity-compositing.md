# ADR 0070: Own Isolated Container Opacity Compositing

Status: Accepted, implemented for the admitted static container slice

Date: 2026-07-15

## Context

SVG container opacity is a post-paint compositing operation. Applying a group value independently to every descendant is observably wrong when children overlap: internal source order must first produce one completed group image, and only that image receives the opacity factor. The pinned `mizchi/svg@0.2.1` parser retains container nodes but its renderer ignores their opacity; it also omits `symbol` presentation attributes when instantiating `use`. Chromium therefore differs on 164 of 256 pixels in the focused overlap fixture.

The existing analyzer already owns the author cascade, CSS-wide defaulting, bounded custom-property substitution, strict number/percentage alpha parsing, clamping, transforms, use-instance identity, Difference Regions, and conservative Cause Envelopes. Replacing the whole renderer would expand this item into unrelated paint, clip, mask, filter, and font work.

## Decision

Own a narrow production compositor around the pinned renderer for static `svg`, `g`, `symbol`, and `use` containers. Resolve each container's non-inherited opacity through the existing computed-value model while preserving the winning declaration and Source Span. Render ordered children recursively into a transparent full-viewport layer with ancestor container opacity neutralized, apply the resolved factor once to the completed layer alpha, and source-over composite it into the parent using explicit premultiplied arithmetic with deterministic RGBA8 rounding. When no non-unit container opacity is present, call the pinned renderer unchanged.

Materialize a referenced symbol's computed opacity on each use instance because the pinned parser drops symbol presentation attributes. Combining immediately nested symbol and use opacity factors is valid because no backdrop is inserted between those two completed layers; definition identity and instance transforms remain unchanged.

Report `compositing.opacity` with exact authored facts, before/after resolved values, signed and absolute dimensionless deltas, symmetric-relative magnitude, production rendered evidence, and localized regions bounded by the union of admitted rendered descendants on both sides. Source-over may make changed backdrop facts causal even when the changed declaration belongs to the group, so complete group-opacity Cause Envelopes conservatively retain the comparison-wide Changed Fact set until a narrower transfer proof exists.

Keep the raw Chromium-versus-`mizchi/svg` baseline unchanged as dependency evidence. Record the product path separately as `isolated-group-compositor@1` and validate its disposition through the production CLI plus exact MoonBit RGBA tests. Clips, masks, filters, blend modes, embedded-raster final composition, and other guarded renderer families remain outside this decision.

## Consequences

Overlapping children, nested opacity groups, backgrounds, transforms, sibling ordering, root groups, and admitted symbol/use instances now produce complete measured outcomes instead of `group_opacity_compositing_unsupported`. Equivalent authored spellings remain visible as source differences with an equivalent computed relation and zero changed pixels. Custom-property causes remain the actual Changed Facts rather than synthetic opacity declarations with identical before/after source.

The full-canvas layer implementation is deterministic and simple but can render the same subtree more than once; performance gates therefore remain part of the acceptance contract. Comparison-wide backdrop candidates increase false positives for group-opacity Cause Envelopes, which is intentional under the project's completeness-over-precision policy. More precise tiled contribution transfer can replace this fallback without changing the current soundness guarantee.
