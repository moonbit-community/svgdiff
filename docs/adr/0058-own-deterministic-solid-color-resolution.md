# ADR 0058: Own Deterministic Solid Color and Paint Opacity Resolution

Status: accepted and implemented for the deterministic sRGB slice

## Context

SVG 2 delegates solid `<color>` values to CSS Color 3 and defines independent numeric opacity factors for elements, fills, strokes, and gradient stops. The pinned SVG dependency does not parse the complete deterministic color grammar and can silently substitute another color. It also cannot preserve the distinction between authored syntax, canonical sRGB channels, and the alpha factors that contribute to a leaf paint. The audited `mizchi/css@0.2.0` parser was unsuitable because unknown values can become transparent and its alpha behavior is not a strict SVG computed-value contract.

The later color-profile roadmap phase owns Display-P3, ICC and other wide-gamut or environment-dependent interpretation. Group opacity also remains a separate isolated-compositing operation. Neither boundary should prevent deterministic sRGB solid colors and leaf paint opacity from being compared now.

## Decision

Own a small workspace `css_color` package that strictly parses case-insensitive CSS Color 3 named, hexadecimal, legacy RGB(A), and HSL(A) forms into straight-alpha sRGB, plus `transparent`, `currentColor`, and the already admitted four/eight-digit alpha hex extension. Recognize deprecated system colors without resolving them. Reject malformed and out-of-profile functions instead of substituting black or transparent.

Resolve `opacity`, inherited `fill-opacity`, inherited `stroke-opacity`, and non-inherited `stop-opacity` from number or percentage syntax and clamp their computed values to `[0,1]`. Effective leaf fill and stroke alpha is color alpha multiplied by paint opacity and leaf opacity. Effective stop alpha is stop-color alpha multiplied by stop opacity. Preserve each winning `DeclaredVisualFact` unchanged and record canonical values only as computed evidence.

At the renderer boundary, `css-color3-opacity-normalizer@1` writes canonical opaque sRGB channels and folds color alpha into the corresponding paint opacity in a private input copy. Fractional-alpha raster output retains `renderer_fractional_opacity_unproven`; group and root opacity retain `group_opacity_compositing_unsupported`.

## Consequences

Equivalent authored color spellings can be reported as source differences with one computed value and zero rendered change. Opacity changes retain continuous numeric deltas even when raster evidence is guarded. Invalid color syntax, system colors, and out-of-profile color functions produce separate source-located Diagnostics.

The supported slice does not include system palette selection, CSS Color 4 functional syntax beyond alpha hex, wide-gamut conversion, ICC profiles, perceptual backgrounds, group isolation, paint-server fallback lists, or complete gradient interpolation. Those remain explicit roadmap work.
