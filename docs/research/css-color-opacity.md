# Deterministic SVG Solid Color and Opacity Evidence

Evidence snapshot: 2026-07-15

## Normative boundary

SVG 2 defines the `<color>` paint component by reference to CSS Color 3. That grammar supplies hexadecimal colors, RGB/RGBA, HSL/HSLA, named colors, `transparent`, `currentColor`, and deprecated system colors. SVG 2 fill and stroke opacity accept numbers or percentages, clamp computed values to `[0,1]`, and inherit. Stop opacity accepts the same numeric forms and clamp but does not inherit. Effective stop alpha multiplies stop-color alpha by stop opacity. CSS `opacity` is non-inherited and applies after painting; group/root opacity therefore requires isolated compositing rather than leaf inheritance.

Primary sources:

- [SVG 2 Painting](https://www.w3.org/TR/SVG/painting.html)
- [CSS Color Module Level 3](https://www.w3.org/TR/css-color-3/)
- [SVG 2 Painting Servers](https://www.w3.org/TR/SVG2/pservers.html)
- [CSS Color Module Level 4](https://www.w3.org/TR/css-color-4/)

## MoonBit dependency audit

An isolated `moon add mizchi/css@0.2.0` audit found a partial value parser rather than a strict computed-color seam. Unknown values can silently become transparent and alpha behavior does not match the required SVG contract. It was not added to the project. A workspace-owned parser is smaller than adapting those permissive semantics and keeps the future wide-gamut/profile boundary explicit.

## Conformance result

The expanded Chromium oracle contains 82 fixtures. The raw `mizchi/svg@0.2.1` baseline records 35 exact and 47 divergent cases. HSL parsing diverges completely in the raw dependency but is byte-identical to canonical sRGB in Chromium. Alpha-bearing color multiplied by paint opacity and inherited paint opacity are also byte-identical to their canonical companions in Chromium; after normalization the pinned renderer retains its known one-level fractional-alpha rounding divergence, so production keeps `renderer_fractional_opacity_unproven`. Negative opacity clamps identically to zero in both renderers.

These results support a project-owned deterministic sRGB normalizer while preserving the existing fractional raster guard. They do not admit broad color management, system palette resolution, or group compositing.
