# ADR 0074: Own bounded static blending and isolation

- Status: accepted
- Date: 2026-07-15
- Decision owners: svgdiff maintainers
- Supersedes: the blanket blend-mode deferral in the v1 scope

## Context

Blend modes make the visual result depend on an ordered backdrop rather than only on the foreground element. A text-only Agent therefore needs more than a changed CSS token or a final pixel mask: it must know the categorical mode, the nearest isolation boundary, the foreground, the conservative preceding backdrop set, and every changed fact that could have altered that backdrop. Treating blending as unsupported preserves safety but cannot explain stacking-sensitive output or distinguish `isolation:auto` from `isolate`.

The pinned renderer exports blend helpers but does not apply `mix-blend-mode` or `isolation` while parsing and traversing SVG. Its helpers also truncate separable-mode channels and approximate non-separable modes through HSL, so they are not the product formula oracle. Chromium remains the independent oracle. SVG 2 also defines an exact presentation-attribute list that excludes these two CSS properties, so a same-named XML attribute must not be silently admitted into the CSS cascade.

## Decision

Own a bounded binary-alpha blending slice in the private engine and product renderer:

- resolve the non-inherited `mix-blend-mode` and `isolation` CSS properties from inline declarations and static author stylesheets, including CSS-wide values and bounded custom-property substitution;
- admit all sixteen Level 1 blend-mode keywords, including `normal`, plus `isolation:auto|isolate`;
- implement the Level 1 separable and `Lum`/`Sat`/`SetLum`/`SetSat` non-separable formulas with Chromium-verified channel rounding;
- admit explicit-ID, identity-transformed, integer, non-rounded, opaque solid rectangles without stroke or another active effect;
- composite ordinary groups directly into the current backdrop, but admit explicit `isolation:isolate` only on the root SVG or an authored-ID `g`, render its children against transparent black, and source-over the completed isolated layer once;
- derive the conservative backdrop candidate set from the ordered visual prefix inside the nearest isolation boundary;
- report `compositing.blend_mode` and `compositing.isolation` as categorical differences with no fabricated cross-mode scalar parameter;
- widen complete blend, isolation, and stacking Cause Envelopes to the comparison Changed-Fact universe until finer compositing provenance is proven.

The admitted foreground and every possibly relevant backdrop rectangle has alpha exactly zero or 255 at every pixel. This makes the general compositing equation exact without claiming continuous-alpha or antialiased-edge behavior. Container blend modes, fractional geometry or alpha, curves, strokes, transforms, use instances, dynamic declarations, and clip/mask/filter/opacity interactions retain precise Diagnostics. Work is capped at 64 admitted blend/isolation surfaces and 67,108,864 aggregate viewport-surface pixels per source.

The production renderer identity adds `static-blend-compositor@1`. Chromium source/canonical pairs cover every blend formula, ordinary non-isolated behavior, explicit isolation, and transparent backdrop behavior. Raw dependency observations remain unchanged; executable compositor dispositions require production source/canonical comparisons to be complete with zero changed pixels.

## Consequences

Structural stacking comparisons now use the same product renderer, so reordering a blended foreground can produce measured stacking evidence even when no CSS property changes. Difference Regions use product pixels, and `affected_subject_ids` exposes the conservative foreground/backdrop set to an Agent.

The binary-alpha boundary is intentional. Continuous alpha, antialiasing, container-level blending, effect interaction ordering, and more precise per-region contribution remain future expansions of this compositor seam rather than guessed approximations.

## Rejected alternatives

- Keep blending guarded: safe but cannot explain backdrop- or order-dependent differences.
- Trust raw dependency rendering: it does not apply the properties during SVG traversal.
- Treat modes as numeric parameters: there is no meaningful universal distance between categorical blend formulas.
- Implement continuous alpha and every effect interaction in the same item: too broad to validate as one complete slice.

## Evidence

- [`blend_semantics_wbtest.mbt`](../../engine/blend_semantics_wbtest.mbt)
- [`renderer-conformance`](../../evaluation/renderer-conformance/README.md)
- [`blend-mode-change.json`](../../schema/examples/blend-mode-change.json)
- [`ISS-118`](../../issues/ISS-118.md)
