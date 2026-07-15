# ADR 0060: Resolve Static Patterns as Resource and Consumer Semantics

Status: accepted and implemented for the admitted static same-document child slice

## Context

An SVG pattern is neither just source text nor a single raster image. The resource owns a repeating tile, a content coordinate system, optional viewport mapping, template references, and a child subtree. Each fill or stroke consumer supplies the current user space and, for `objectBoundingBox`, the target bounds. One resource edit can therefore affect many entities, while an unreferenced edit affects no rendered entity at all.

Raw renderer comparison cannot supply this missing causal model. The pinned renderer remains independently unproven for patterns, and a pixel difference cannot identify whether the true cause was a tile coordinate, template, transform, viewport, or child fact.

## Decision

Own a renderer-independent model for deterministic static same-document `pattern` resources. Resolve `x`, `y`, `width`, `height`, `patternUnits`, `patternContentUnits`, `patternTransform`, `viewBox`, `preserveAspectRatio`, and recursive `href`/`xlink:href` inheritance before computing consumer-specific tile and content matrices. A valid `viewBox` replaces the `patternContentUnits` mapping. Zero tile dimensions and empty content are explicit no-paint modes.

Admit pattern children only through the existing static basic-shape, transform, cascade/inheritance, solid-sRGB-paint, and opacity machinery. Template-provided children are reparented to the referencing pattern host for inherited properties while retaining their original declaration facts and Source Spans. Child transforms are evaluated relative to the content-providing pattern, not the source document root.

Emit resource Atomic Differences for every changed field, normalized matrix, template reference, child property, child signature, and child presence. Emit a separate mediated `paint.fill` or `paint.stroke` outcome for every consumer, with one resource Changed Fact listing all affected consumers. Source-visible direct/template or normalized viewport rewrites may be computed-equivalent. Unreferenced pattern changes remain resource-only.

Keep `renderer_pattern_raster_unproven` until measured conformance justifies a stronger raster claim. Use precise guards for external, invalid, cyclic, or dynamic references; malformed lengths, units, transforms, and viewports; missing object bounds; visible overflow; and children outside the admitted slice.

## Consequences

Text-only agents can distinguish authored pattern differences from resolved paint consequences, enumerate all modeled candidate causes, and follow resource fan-out without image access. The model deliberately accepts conservative partial results for arbitrary SVG child trees rather than silently omitting a possible cause. Images, text, nested child resources, markers, clips, masks, filters, scripts, animation, external bundles, and visible-overflow compositing remain future work.
