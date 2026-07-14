# ADR 0052: Resolve SVG Lengths with Explicit Context

Status: accepted and implemented for deterministic absolute and viewport-relative units

## Context

An authored SVG length has at least two independently useful meanings: its exact source spelling and its used numeric value under a coordinate context. Treating `96`, `96px`, and `1in` as unrelated strings loses computed equivalence. Replacing the source spelling with `96` loses the distinction an Agent needs to explain. Percentages add a second ambiguity because horizontal, vertical, and other lengths use different nearest-SVG-viewport bases, while CSS viewport units use the initial containing block represented by the Comparison Profile.

SVG 2 defines unitless values and `px` in the current user coordinate system, resolves viewport percentages by horizontal, vertical, or normalized-diagonal directionality, and fixes CSS absolute-unit conversion through 96 px per inch. CSS Values defines `vw`, `vh`, `vmin`, and `vmax` from the initial viewport. See [SVG 2 coordinate systems and units](https://www.w3.org/TR/SVG2/coords.html#Units) and [CSS Values and Units Level 4](https://www.w3.org/TR/css-values-4/#lengths).

## Decision

Keep every supported authored length as an exact `DeclaredVisualFact`, including its origin and Source Span. Resolve a separate canonical `Double` in local user units through one strict project-owned parser. The admitted units are unitless values, `px`, `in`, `cm`, `mm`, `Q`, `pt`, `pc`, `%`, `vw`, `vh`, `vmin`, and `vmax`.

CSS absolute units use their exact normative ratios to 96 CSS px per inch. SVG percentages use the nearest established SVG viewport: width for horizontal properties, height for vertical properties, and `sqrt(width^2 + height^2) / sqrt(2)` for unspecified directionality. The four admitted viewport units use the explicit initial Comparison Viewport, not a nested SVG viewport. A valid `viewBox` establishes the nearest child percentage basis in its user dimensions.

The shared resolver supplies used values for basic-shape coordinates, sizes, and radii; stroke width, dash entries, and dash offset; root and nested SVG viewport declarations; and marker viewport and reference-point lengths. Path data and point lists retain their SVG number-list grammars. Number-only controls such as stroke miter limit remain numbers.

Private renderer-input copies materialize the same canonical used values after style precedence and before stroke and basic-shape normalization. Original inputs, source facts, Diagnostics, and HTML source displays are never rewritten. Real geometry changes retain local parameter deltas and transform-aware CSS-pixel displacement evidence; equivalent unit spellings remain Source Semantics differences with computed equivalence.

## Consequences

Font-relative units (`em`, `rem`, `ex`, and related units), writing-mode-relative viewport units, small/large/dynamic viewport variants, container-query units, arithmetic functions such as `calc()`, and environment-dependent values remain unsupported. They continue to emit the existing source-located geometry, stroke, viewport, or marker limitation Diagnostic rather than receiving an assumed environment.

The fixed profile makes the admitted viewport units deterministic. A future CSS layout or font model may extend the shared parser with explicit context, but it must not infer ambient browser state or weaken authored provenance.
