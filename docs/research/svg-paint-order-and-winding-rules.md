# SVG Paint Order and Winding Rule Research

Status: implementation evidence for ISS-106

Last verified: 2026-07-15

## Primary sources

[SVG 2 Painting](https://www.w3.org/TR/SVG2/painting.html) defines `paint-order` as `normal | [ fill || stroke || markers ]`, with initial order `fill stroke markers`. The property is inherited. An omitted operation is appended after the listed operations in normal order, so `stroke` and `stroke fill markers` have the same computed order.

The same specification defines `fill-rule` as `nonzero | evenodd`, initial `nonzero`, and inherited. It selects the inside test for fillable geometry; it does not create a fill when no fill operation is active. A single non-self-intersecting simple contour such as the admitted rectangle, circle, or ellipse has the same interior under both rules.

[CSS Masking Level 1](https://www.w3.org/TR/css-masking-1/#the-clip-rule) defines inherited `clip-rule` with the same two keywords and `nonzero` initial value. It affects a graphics element while that element is a child of a `clipPath`; setting it on the graphics element that references a clip path has no clipping effect.

## Semantic model

svgdiff resolves all three properties after cascade, ordinary inheritance, CSS-wide keyword handling, and bounded custom-property substitution. It preserves the winning authored declaration, Source Span, owner, and dependencies separately from the canonical computed value.

`paint-order` is first expanded to its full three-operation order and then projected to operations that can contribute for the subject. Reordering an inactive fill, stroke, or marker operation is computed-equivalent. Reordering two active operations is a computed difference. Active marker order remains guarded until marker child paint and compositing are modeled.

`fill-rule` is normalized to an inactive value when no fill operation contributes and to one simple-contour value for admitted rectangles, circles, and ellipses. Point or path contours retain `nonzero` or `evenodd`; point-shape and path raster evidence remains subject to its existing guard.

`clip-rule` is inactive outside a `clipPath`. Inside a `clipPath`, the rule and its inherited owner are retained. This research originally left resource construction, host application, bounds, and raster conformance to a later milestone; [ADR 0071](../adr/0071-resolve-static-rectangular-clips-and-effect-bounds.md) now admits the one-rectangle subset and keeps more general contours partial. This avoids both silently ignoring a real rule change and claiming complete general clipping semantics.

## Renderer ownership

Production materializes the resolved inherited declarations into a private renderer-input copy while retaining original source evidence. Browser fixtures separately test inherited/canonical paint order, inherited/canonical fill rule, inherited/canonical clip rule, and both winding rules on a self-intersecting polygon. Any raw renderer divergence must be bound to a reviewed normalizer or an encountered Diagnostic before the renderer-conformance profile advances.
