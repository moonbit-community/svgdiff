# SVG Paint Fallback Research

Status: implementation evidence for ISS-105

Last verified: 2026-07-15

## Primary source

The normative source is [SVG 2, Painting, section 13.2](https://www.w3.org/TR/SVG/painting.html#SpecifyingPaint). Its current grammar is `<paint> = none | <color> | <url> [none | <color>]? | context-fill | context-stroke`.

The optional token after a URL is a fallback, not a second composited paint layer. It is selected only when the URL does not resolve to a valid paint server. A missing fallback deterministically produces no paint. This differs from SVG 1.1's error behavior and from CSS background image/color layering.

A local reference is valid only when its target is a paint-server element: `linearGradient`, `radialGradient`, or `pattern` in the current SVG 2 inventory. An existing target of another kind therefore selects the fallback exactly like a missing ID. A valid server remains selected even when its own content later produces no pixels; fallback selection is about reference validity, not the server's painted contribution.

The fallback color uses the ordinary supported CSS Color 3 and `currentColor` rules. Paint opacity and leaf opacity apply after branch selection. The computed CSS value retains its URL and fallback syntax, while svgdiff additionally records the selected used-paint branch needed for visual comparison.

## Admitted deterministic boundary

svgdiff admits one static `fill` or `stroke` paint value containing:

- `none`;
- the existing deterministic solid sRGB slice;
- a same-document URL with optional `none`, supported color, or `currentColor` fallback;
- ASCII whitespace, matching URL quotes, case-insensitive `url`, and percent-decoded fragment IDs under the local-reference grammar.

The analyzer resolves same-document target existence and kind from the bounded XML document. A valid gradient or pattern becomes the active branch. A missing or wrong-kind target selects the fallback, or `none` when the fallback is absent. Only an active `currentColor` fallback creates a dependency on `color`; an inactive fallback remains authored evidence without computed fan-out.

External URLs remain indeterminate even when a fallback is authored because a self-contained input cannot prove whether the external target resolves. `context-fill`, `context-stroke`, malformed URL/fallback syntax, unsupported color profiles, animation, script, and the deferred multi-layer paint proposal remain guarded.

## Renderer ownership

Production resolves the selected branch before rendering and materializes it only in the private renderer-input copy. The original SVG remains authoritative for authored values, cascade origin, dependencies, and Source Spans. Focused Chromium fixtures compare missing-server fallback and no-fallback inputs with canonical selected-paint companions. All four fixtures are exact under both raw `mizchi/svg@0.2.1` and Chromium at DPR `1`, increasing the versioned baseline to 98 cases with 40 exact and 58 divergent observations. No new renderer guard or normalizer disposition is required for this admitted branch-selection slice.
