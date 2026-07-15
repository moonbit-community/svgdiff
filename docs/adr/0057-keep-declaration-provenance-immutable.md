# ADR 0057: Keep Declaration Provenance Immutable After Source Adaptation

Status: accepted and implemented for supported author declarations

## Context

Cascade, inheritance, CSS-wide defaulting, custom-property substitution, `currentColor`, shorthand expansion, and renderer normalization all transform how an authored declaration affects computed appearance. Encoding those transformations by changing a declaration's origin or Source Span makes the report point at source text that never existed. In particular, marker inheritance previously manufactured an `inherited_presentation_attribute` origin even though the real declaration remained a presentation attribute on an ancestor.

The report already has separate fields for resolved value, resolution mode, declaration owner, and inheritance depth. Source provenance therefore does not need to carry computed state.

## Decision

Treat every `DeclaredVisualFact` selected by the author cascade as immutable evidence. Its exact authored value, normalized declared value, declaration origin, and half-open UTF-16 Source Span always describe the winning declaration in the original input. Cascade selection returns that fact unchanged regardless of importance, specificity, declaration source, or source order.

Inheritance and computed-value resolution retain the same declaration and express their result through `ResolvedVisualFact.resolved_value`, `resolution`, `declaration_owner_id`, and `inheritance_depth`. Derived marker longhands may replace only the effective property name while retaining the shorthand declaration's remaining provenance. Private renderer-input materialization never becomes report provenance.

Source offsets are evidence rather than visual identity. Moving an otherwise unchanged declaration within the same origin does not create an Atomic Difference; moving it between presentation, inline, and stylesheet origins remains reportable because the cascade origin changed. Every emitted declaration span must slice its associated original input to the exact `authored_value`.

## Consequences

Agents can follow every declaration in an Atomic Difference, Changed Fact, Source Resolution, or Diagnostic back to real source text without interpreting synthetic origins. Local, inherited, initial, and computed behavior remains explicit and queryable without conflating source and computed layers.

The current origin set remains limited to admitted author declarations: presentation attributes, inline styles, and matched stylesheet rules. User, user-agent, animation, transition, cascade-layer, scoped-style, and external stylesheet origins require separate cascade and provenance work before admission.
