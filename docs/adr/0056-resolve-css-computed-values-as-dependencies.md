# ADR 0056: Resolve CSS Computed Values as Dependencies Without Rewriting Source Facts

Status: accepted and implemented for supported SVG values

## Context

Cascade winners are not necessarily property-ready values. CSS-wide keywords select inheritance or initial-value behavior, custom properties defer substitution through `var()`, and `currentColor` depends on the same element's computed `color`. Treating those spellings as literal paint or geometry would create false differences; replacing the authored declaration with its result would destroy the causal evidence that an agent needs.

CSS Cascading and Inheritance defines `initial`, `inherit`, `unset`, and `revert`; CSS Custom Properties defines case-sensitive inherited custom properties, substitution, fallback, cycles, and invalid-at-computed-value behavior; CSS Color defines `currentColor` from computed `color`. The current profile admits author declarations only, so `revert` has no lower user or user-agent origin to expose. See [CSS Cascading and Inheritance Level 5](https://www.w3.org/TR/css-cascade-5/#defaulting-keywords), [CSS Custom Properties Level 1](https://www.w3.org/TR/css-variables-1/), and [CSS Color Level 4](https://www.w3.org/TR/css-color-4/#currentcolor-color).

## Decision

Insert one private computed-value seam after author cascade selection and ordinary inheritance, but before paint, geometry, stroke, marker, and resource-color used-value parsing. Keep each winning `DeclaredVisualFact` unchanged. A separate computed resolution carries the effective value and an explicit dependency set naming the consuming declaration plus any custom-property and `color` declarations that determined it.

Resolve `inherit`, `initial`, and `unset` for every currently supported inherited and non-inherited property. Under the author-only profile, resolve `revert` by discarding all author declarations for that property and applying ordinary defaulting. Keep `revert-layer` guarded by `css_revert_layer_unsupported` until cascade layers exist. The deterministic initial value of inherited `color` is sRGB black. Resolve `currentColor` for `fill`, `stroke`, and admitted `stop-color`; `color: currentColor` behaves as inherited color.

Admit case-sensitive custom properties from inline declarations and matched stylesheet rules. They inherit by default and may feed every currently supported SVG property through balanced `var()` functions, nested references, and nested fallbacks. Missing references without fallback, cycles, and substituted values invalid for the consuming property produce the CSS invalid-at-computed-value result, so that consuming declaration behaves as `unset`. These valid CSS outcomes do not create limitation Diagnostics.

Bound recursive substitution to 64 active references and 65,536 output bytes. Emit `css_variable_expansion_limit` when either limit is crossed. The admitted deterministic parser excludes CSS strings, escapes, comments, registered custom properties, animation taint, and other complete-token-stream behavior; malformed or excluded variable syntax emits `css_variable_syntax_unsupported`. Custom-property definitions are CSS declarations, not SVG presentation attributes, although presentation attributes may consume `var()`.

Build Changed Facts from authored declarations and compute `affected_subject_ids` from the dependency graph. A changed custom property or `color` value is reportable only when a supported scene leaf or admitted resource color consumes it. Unused custom-property changes produce no visual event. The renderer boundary materializes complete effective values only in private renderer-input copies through `css-computed-value-normalizer@1`; source text, Source Spans, origin, authored value, and declared value remain authoritative and unchanged.

## Consequences

An authored `var(--paint)`, `currentColor`, or CSS-wide keyword can differ from a canonical literal while its computed relation is `equivalent` and rendered changed-pixel count is zero. Conversely, one ancestor `color` or custom-property declaration can causally fan out to several leaves without inventing leaf-owned source declarations.

The implementation covers currently supported geometry, fill, stroke, stroke geometry, opacity, vector effect, marker attachment, and admitted gradient stop colors. It does not imply complete CSS syntax, cascade layers, non-author origins, registered custom properties, animation or transition values, system colors, complete color syntax, or complete gradient semantics. Each newly admitted consuming property must add its initial value, inheritance classification, substituted-value validator, dependency propagation, renderer behavior or guard, and focused regression evidence together.
