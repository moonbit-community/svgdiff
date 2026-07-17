# ADR 0105: Require a deterministic host-language engine for foreign content

- Status: accepted, not implemented
- Date: 2026-07-17
- Decision owners: svgdiff maintainers
- Supersedes: none

## Context

SVG defines the outer `foreignObject` integration geometry but delegates descendants to another namespace or host language. Static XHTML can still require UA defaults, CSS cascade, formatting contexts, fonts, line breaking, replaced resources, painting, overflow, and cross-boundary compositing. Comparing only XML or the outer rectangle loses visual semantics, while a browser capture has target-local rather than canonical authority.

The current profile parses standalone SVG as XML, performs no implicit I/O, uses no system fonts, runs no scripts, declares no interaction or animation state, and guards every `foreignObject`.

## Decision

General canonical support for XHTML inside `foreignObject` requires a deterministic HTML/CSS host-language engine integrated into a separately versioned `svgdiff-foreign-object-layout-profile/1`. “Integrated” means that the exact engine semantics and build are part of product execution identity; it does not require a complete browser or same-process execution.

Permit a smaller project-owned or pinned evaluator for a deliberately closed XHTML/CSS/layout subset. Select `svgdiff-foreign-object-xhtml-rect-slice/1` as the first candidate: XML XHTML `div` trees with no text or resources, explicit finite CSS-pixel absolute rectangles, inline style, solid backgrounds/borders, fixed clipping, source-over alpha, and independently admitted outer SVG composition. It remains an engine for that subset and cannot claim general HTML/CSS support. Unknown foreign namespaces require separate named handlers and remain unsupported otherwise.

Keep browser-specific rendering in `svgdiff-foreign-object-observation/1`. Preserve XML parsing mode, host-language tree, computed style, layout fragments, text and resources, rendered surfaces, final SVG compositing, coverage, and causality as separate evidence.

No dependency or product implementation is selected. Use the existing smallest-failing-layer ownership gate when a concrete Agent task justifies implementing the rectangular tracer. Text-bearing work additionally waits for deterministic font and line-layout prerequisites.

## Consequences

Svgdiff can eventually admit useful foreign content without importing a whole ambient browser environment or overclaiming unsupported layout. General support is expensive by definition; bounded slices must fail closed at every grammar and integration edge. External browser observations remain useful for conformance but cannot complete canonical evidence.

No parser, layout engine, browser, dependency, profile field, Schema, public API, Diagnostic, fixture, CLI option, CI job, or release asset changes through this decision.

## Rejected alternatives

- Compare only the XML subtree: source difference is not computed layout or visual outcome.
- Treat the outer rectangle as the content bounds: overflow, descendants, text, resources, clipping, and effects invalidate that shortcut.
- Use a browser screenshot as canonical evidence: browser, OS, UA styles, fonts, parsing mode, resources, and platform behavior remain target-specific.
- Call a CSS parser or DOM implementation a layout engine: neither establishes box generation, line layout, painting, or SVG integration.
- Treat unknown namespaces as XHTML or empty content: namespace identity selects semantics and missing handlers reduce coverage.
- Embed a complete browser before a task requires it: it expands security, dependency, state, and causal-provenance obligations beyond the smallest necessary seam.
