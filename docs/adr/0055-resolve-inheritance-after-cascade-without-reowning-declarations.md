# ADR 0055: Resolve Ordinary Inheritance After Cascade Without Reowning Declarations

Status: accepted and implemented for supported visual properties

## Context

Cascade and inheritance answer different questions. Cascade selects one specified declaration on an element; ordinary inheritance supplies an absent inherited property from the parent. The report must then explain both the declaration that changed and every rendered leaf whose used appearance changed. Copying an ancestor declaration into each leaf as a new source fact would make computation convenient but would falsely attribute one authored change to many leaf-local changes.

The CSS cascade defines inheritance over the result of cascading, with the root using each property's initial value when no declaration supplies a value. SVG identifies which presentation properties inherit and applies them through the element tree. See [CSS Cascading and Inheritance Level 6](https://www.w3.org/TR/css-cascade-6/#inheriting) and [SVG 2 styling](https://www.w3.org/TR/SVG2/styling.html).

The pinned renderer inherits fill, stroke paint, stroke width, color, and marker attachments, but its inherited-style stack does not carry every supported stroke-detail property. Using its partial inheritance as the source-semantics model would therefore make report completeness depend on a dependency implementation detail.

## Decision

Keep declaration ownership and leaf computation separate. The source hierarchy resolves presentation attributes, inline declarations, and matched stylesheet declarations through the author cascade, then walks the nearest admitted ancestor for every supported inherited property. A `SourceResolutionPair` retains the winning declaration, owner, resolution kind, inheritance depth, origin, authored value, and exact Source Span. One owner-level `ChangedFact` lists every affected supported scene leaf.

The leaf subject analyzer receives effective inherited fill, stroke, stroke width, line cap, line join, miter limit, dash array, and dash offset before resolving used stroke geometry. Marker longhands continue through the existing marker inheritance model. These effective facts are private computational inputs: they retain their original declaration provenance and never become leaf-owned Changed Facts.

`opacity`, `vector-effect`, and geometry properties remain non-inherited. Missing inherited declarations use their documented initial values. CSS-wide keywords, `currentColor`, custom properties, paint servers, and non-author cascade origins remain guarded and belong to later roadmap items.

At the renderer boundary, a private `ordinary-inheritance-normalizer@1` materializes only complete admitted inherited winners on supported scene leaves after style-precedence normalization and before length and stroke used-value normalization. It changes only renderer-input copies. Original SVG text remains authoritative for provenance and presentation. Unsupported inheritance syntax is not rewritten.

Marker resource children are excluded from scene-leaf inheritance enumeration; marker content paint remains independently guarded. Existing stroke and marker renderer-conformance guards remain in force even when source and computed inheritance are complete.

## Consequences

Equivalent declaration moves between a leaf and an ancestor retain a visible source/provenance difference while producing computed equivalence and zero changed pixels. Ancestor value changes fan out to all affected leaves with computed relations, numeric deltas where defined, and rendered measurements where no independent guard applies.

The hierarchy remains the single authority for causal ownership, while generic leaf computation remains the single authority for used-value relations. Adding a future inherited property requires updating the explicit property table, initial value, leaf computation, renderer admission or guard, mutation coverage, and conformance evidence together.
