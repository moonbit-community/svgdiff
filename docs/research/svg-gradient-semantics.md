# SVG Gradient Semantics Research

Status: implementation reference for schema `1.17`

Last verified: 2026-07-15

## Primary specification

The implementation follows the SVG 2 paint-server chapter: [W3C SVG 2, Paint Servers: Gradients and Patterns](https://www.w3.org/TR/SVG2/pservers.html).

Relevant requirements used by the engine are:

- `linearGradient` and `radialGradient` geometry defaults are semantic values, not merely omitted source text;
- `gradientUnits` selects object-bounding-box or user-space coordinates, while `gradientTransform` is applied in the gradient coordinate system;
- `spreadMethod` defaults to `pad` and also admits `reflect` and `repeat`;
- `href` supplies missing attributes recursively, and the referenced child stop set is used only when the referencing gradient has no child stops;
- gradient properties inherit from the gradient element's ancestors, not from the painted consumer;
- stop offsets are clamped to `[0,1]` and adjusted so later offsets do not precede earlier ones;
- zero stops paint nothing, one stop paints a uniform color, and equal offsets represent an abrupt transition;
- stop color alpha and stop opacity contribute independently to effective stop alpha.

## Engineering interpretation

The analyzer separates authored resource facts, resolved resource semantics, and consumer-specific paint. This is required because `objectBoundingBox` values cannot be converted into a final coordinate matrix until the target geometry is known, and one resource can be referenced by several different targets. Template provenance remains attached to the declaration that supplied the value, while affected consumer IDs express fan-out.

The engine accepts only deterministic static same-document references and sRGB interpolation. External URLs, dynamic content, malformed values, missing target bounds, and non-sRGB interpolation receive explicit Diagnostics. This conservative boundary is intentional: accepting false positives is compatible with the project's complete cause-envelope goal, while silently substituting a plausible value could omit the true cause.

## Renderer evidence

Six Chromium fixtures cover linear and radial gradients, both units, transforms, recursive template inheritance, and multiple stops with opacity. All six diverge from raw `mizchi/svg@0.2.1`, with 87 to 196 changed pixels and maximum channel deltas from 105 to 255. Therefore the project-owned computed model is admitted independently, while `renderer_gradient_raster_unproven` continues to constrain only Rendered Evidence.
