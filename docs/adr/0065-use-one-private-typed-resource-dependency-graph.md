# Use one private typed resource dependency graph

Status: accepted and implemented for the bounded static source grammar

## Context

The engine previously had several partial dependency representations. Gradient, pattern, marker, and use semantics performed family-specific lookup, while the pre-render safety pass retained only ID scopes, boolean resource edges, and use-expansion edges. That safety graph could reject cycles, but it discarded the source node, resource kind, relationship kind, nonlocal locator state, and top-level consumer edge needed by later provenance and resource work. Images were not resource nodes, and stylesheet text references were absent.

## Decision

Build one project-owned private graph from the bounded namespace-aware XML stream before renderer parsing. Every source element is a deterministic node with its SVG kind, optional authored ID, source offset, and element span. Every admitted reference is a typed edge with its source node, containing definition scopes, relation, locator class, decoded local target when present, and exact attribute or stylesheet-text Source Span.

The edge taxonomy distinguishes template, paint, marker, clip, mask, filter, use-instance, symbol-template, image, stylesheet-resource, and conservative generic resource dependencies. Locator classes distinguish local fragments, missing local targets through lookup, external locators, data URIs, and invalid empty or malformed locators without fetching or decoding them. Duplicate IDs merge only at conservative target lookup; their individual source nodes remain present. Descendant edges are attached to every containing ID scope.

Cycle detection, transitive use-expansion accounting, and the materialized owner-edge budget consume this graph directly. Deterministic forward and reverse reachability queries support semantic passes and tests. The Structured Report does not serialize the unchanged scene graph: it continues to project only difference-relevant Changed Facts, affected subjects, Atomic Differences, and Diagnostics.

## Consequences

Gradient, pattern, marker, clip, mask, filter, symbol, image, use, inline-style, and static stylesheet references now share one source-level topology. A local image self-cycle fails admission with the existing source-located `reference_cycle_detected` contract before unsupported image semantics or renderer parsing. Supported resource reports are regression-tested against graph reachability.

The graph does not decode images, fetch network resources, resolve caller bundles, implement clip/mask/filter pixels, interpret arbitrary CSS tokenization, or establish contribution weights. Family-specific semantic documents remain responsible for computed values; the graph is their common dependency boundary, not a replacement for value resolution. Those behaviors remain owned by later roadmap items.
