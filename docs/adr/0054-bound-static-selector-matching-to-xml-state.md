# ADR 0054: Bound Static Selector Matching to XML State

Status: accepted and implemented for the deterministic static profile

## Context

The author cascade can select a winner once it receives applicable declarations, but a selector matcher must decide applicability without importing browser state or silently approximating unsupported CSS. A selector such as `#box.paint` is determined entirely by the SVG XML tree, while `:hover`, namespace configuration, escaped identifiers, and functional pseudo-classes require additional grammar or external state. Treating an unsupported selector as either always matching or never matching could produce a false complete result.

Selectors are matched right-to-left over element ancestry and sibling relationships. Type and attribute name matching in an XML SVG document is case-sensitive, and class selectors use whitespace-separated class tokens. See [Selectors Level 4 selector structure](https://www.w3.org/TR/selectors-4/#structure), [combinators](https://www.w3.org/TR/selectors-4/#combinators), and [attribute selectors](https://www.w3.org/TR/selectors-4/#attribute-selectors).

## Decision

Create one private static selector module, separate from cascade ordering. It parses a deliberately bounded grammar into compound-selector parts and indexes the XML document as a flat array retaining each element's local name, unprefixed attributes, parent, preceding element sibling, and source offset. Matching proceeds from the rightmost compound toward its required ancestor or sibling.

The complete static grammar includes ASCII type and universal selectors, ID and class selectors, attribute presence and exact-value selectors with unescaped identifier or quoted values, compound selectors, selector lists, and descendant, child, adjacent-sibling, and general-sibling combinators. Type, ID, class, and attribute comparisons are case-sensitive. `class`, `data-*`, and `aria-*` attributes are admitted as selector metadata; other attributes retain their independent visual-semantics checks.

CSS escapes, namespace selectors, pseudo-classes, pseudo-elements, functional selectors, comments, at-rules, and malformed selectors remain incomplete. Any such syntax retains `css_cascade_unsupported`; the engine does not approximate its match result.

Matched rule candidates retain the specificity, importance, source order, declaration origin, selector span, declaration span, authored value, and normalized value produced by the cascade parser. Source and inheritance analyzers merge those candidates with presentation and inline candidates before invoking the existing winner selector.

The private renderer adapter materializes complete winners as inline declarations on each matched element and removes the redundant stylesheet text from the renderer-input copy. Original SVG text and all report provenance remain unchanged. The adapter is identified as `style-precedence-normalizer@3` and is proven against Chromium canonical pairs for specificity and source-order behavior.

## Consequences

Common deterministic author stylesheets can now participate in complete source, computed, and rendered conclusions without embedding selector traversal in the cascade module. The document index does not depend on authored IDs, so duplicate or absent IDs do not affect structural traversal.

The admitted scope is intentionally smaller than general CSS Selectors. Adding pseudo-classes, namespaces, escapes, attribute operators, or CSS comments requires focused grammar, applicability, provenance, unsupported-input, mutation, and renderer-conformance evidence before removing the corresponding guard. Inheritance expansion, CSS-wide keywords, custom properties, cascade layers, and non-author origins remain separate roadmap work.
