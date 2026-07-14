# ADR 0053: Separate Cascade Selection from Selector Matching

Status: accepted and implemented for author declaration ordering

## Context

The existing extractor overwrote presentation attributes with parsed inline declarations. That happened to model one common precedence case, but it could not represent `!important`, selector specificity, stylesheet source order, or duplicate declaration priority. Combining stylesheet parsing, selector applicability, cascade ordering, inheritance, and value resolution in each property analyzer would repeat the same precedence logic and make provenance drift likely.

The CSS cascade accepts applicable declarations for one property and returns one cascaded value. Within the current author-origin scope, importance precedes style-attribute precedence, selector specificity, and document order. SVG presentation attributes participate at author level with specificity zero, while style-attribute declarations take precedence over selector-mapped declarations of the same importance. See [CSS Cascading and Inheritance](https://www.w3.org/TR/css-cascade-6/#cascade-sort), [CSS Style Attributes](https://www.w3.org/TR/css-style-attr/#interpret), [Selectors Level 4](https://www.w3.org/TR/selectors-4/#specificity-rules), and [SVG 2 styling](https://www.w3.org/TR/SVG2/styling.html#PresentationAttributes).

## Decision

Create one private pure cascade module. Its interface accepts already applicable candidates and returns the winning declaration for each supported property. Every candidate retains a `DeclaredVisualFact`, importance, selector or inline specificity, declaration-source rank, and absolute source order. Winner selection compares importance, inline/ID/class/type specificity, presentation-versus-stylesheet placement, and source order in that order.

Presentation-attribute and inline-style adapters now create candidates instead of overwriting facts. The inline declaration parser recognizes a terminal case-insensitive `!important`, excludes the annotation from the exact authored value span, retains importance in the candidate, and resolves duplicates through the cascade module. The private renderer input serializes the selected inline winners without changing original source evidence.

Stylesheet text is parsed into source-located rules. Each rule retains its selector text and span, deterministic specificity, and source-located declaration candidates. The admitted parser currently covers simple type, universal, ID, class, attribute, pseudo-class, pseudo-element, compound, list, and combinator syntax needed to calculate ordinary specificity; functional selectors, at-rules, strings, comments, layers, scoping, and other unsupported grammar remain incomplete.

Selector applicability is a separate seam and the next roadmap item. Until a matcher supplies the applicable stylesheet candidates for an element, any nonempty stylesheet remains guarded by `css_cascade_unsupported` and cannot affect a complete computed conclusion.

## Consequences

The cascade module is the single test surface for importance, inline precedence, specificity, and source order. Property analyzers consume only its winners and do not learn priority rules. The later selector matcher can be tested independently, then pass applicable rules into the existing cascade interface without changing precedence logic.

This item does not implement user or user-agent origins, animations, transitions, cascade layers, scope proximity, custom properties, CSS-wide keywords, inheritance expansion, or selector matching. Those capabilities remain explicit roadmap work and must extend candidate metadata or pre-cascade applicability without weakening current provenance.
