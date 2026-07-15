# ADR 0061: Select SVG Paint Fallbacks Before Resource Mediation

Status: accepted and implemented for static same-document paint URLs

## Context

An SVG `fill` or `stroke` URL may carry a fallback color or `none`. The fallback is not composited with a valid paint server: it becomes active only when the reference is missing or points to the wrong element kind. Treating every URL as an unresolved resource loses deterministic no-paint and solid-color outcomes; treating every unavailable external target as missing can select a fallback that a browser would never use.

Fallback selection also changes causality. An active `currentColor` fallback depends on the element's computed `color`, while the same token is irrelevant when a valid gradient or pattern is selected. Resource fan-out must therefore consume the selected branch rather than the complete authored token.

## Decision

Parse the SVG 2 `<url> [none | <color>]?` grammar into a typed paint value after cascade and custom-property substitution. Resolve same-document target existence and kind against the bounded XML input. Select an admitted gradient or pattern when valid; otherwise select the optional fallback, or deterministic `none` when it is absent. Preserve the complete authored declaration and Source Span independently from this used-paint selection.

Resolve active fallback colors through the existing CSS Color 3, `currentColor`, inheritance, dependency, and opacity machinery. Do not add dependencies from inactive fallback tokens. Feed gradient and pattern mediation only active local resource references, while still retaining authored references to explain resource insertion, deletion, and target-validity changes.

Materialize the selected branch only in the private renderer-input copy. Keep external URLs, `context-fill`, `context-stroke`, malformed syntax, unsupported color profiles, animation, and multi-layer paint outside the admitted boundary with precise Diagnostics.

## Consequences

Missing and wrong-kind local paint servers can now be compared completely: a fallback color behaves like that solid paint, and a missing fallback behaves like `none`. Inactive fallback edits remain source-visible and computed-equivalent. A resource becoming valid replaces the previous fallback and reaches every affected consumer. External target validity remains deliberately indeterminate rather than being guessed from local absence.
