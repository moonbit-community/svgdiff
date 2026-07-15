# ADR 0062: Resolve Inherited Paint Order and Winding Rules by Active Operation

Status: accepted and implemented for the admitted static shape slice

## Context

`paint-order`, `fill-rule`, and `clip-rule` are inherited properties, but their visual relevance depends on a later semantic context. Different spellings of `paint-order` can expand to the same order, an operation can be inactive, the two fill rules agree on simple contours, and `clip-rule` has an effect only inside a clip-path resource. Comparing raw tokens would therefore overstate many differences, while dropping context-dependent properties would miss real causes and inheritance fan-out.

## Decision

Resolve the three properties through the existing cascade, inheritance, CSS-wide, custom-property, provenance, and dependency pipeline. Canonicalize `paint-order` by appending omitted operations in normal order, then compare only the active fill, stroke, and marker subsequence for each subject. Canonicalize `fill-rule` to inactive when no fill contributes and to one simple-contour value for admitted rectangles, circles, and ellipses; retain the declared winding rule for other fillable geometry.

Track the nearest `clipPath` owner during source extraction. Treat `clip-rule` outside that resource context as inactive. Inside it, report the inherited rule and every affected child, but emit a clipping-semantics Diagnostic until clip resource geometry, host application, bounds, and raster evidence are implemented by the later roadmap item.

Apply the same active-operation normalization to pattern child computed signatures. Preserve authored declarations and Source Spans independently from computed normalization, and materialize resolved properties only in the private renderer input.

## Consequences

Equivalent spellings, inactive operation reorderings, simple-contour fill-rule changes, and ordinary `clip-rule` declarations can now remain source-visible without becoming false visual differences. Active paint-order changes and winding-rule changes on potentially self-intersecting geometry remain reportable with continuous domain-specific evidence and existing renderer guards. Inherited owners, custom-property dependencies, pattern consumers, and clip-path children remain attributable. Complete clip-path evaluation is explicitly deferred rather than approximated.
