# SVG Resource Dependency Graph Notes

Status: implementation-grounded design note

Last verified: 2026-07-15

## Why the admission graph was insufficient

The graph introduced for cycle and expansion safety answered only whether an ID scope could reach another accepted scope. It intentionally merged resource kinds into a boolean and retained edges only under ID-bearing owners. That is enough for fail-closed admission, but not for a causal model: a top-level shape consuming a gradient, an image with a data URI, and a filter primitive consuming an image need distinct nodes, edge roles, locator states, and provenance.

The current graph therefore retains all source elements and all accepted reference edges. Direct local lookup remains conservative for duplicate IDs. Forward traversal follows a consumer into template or nested resource dependencies; reverse traversal follows a changed resource back through containing definitions to every possible source consumer. Encounter order plus unique insertion makes both traversals deterministic.

## Accepted source grammar

- `href` on `use`, gradient, pattern, marker, clipPath, mask, filter, symbol, image, and `feImage` creates a typed edge;
- every case-insensitive `url(...)` token in an attribute creates a typed edge classified from the attribute name;
- `url(...)` tokens in static `style` element text or CDATA create stylesheet-resource edges;
- local fragments decode the same percent escapes as the pinned renderer boundary;
- external strings, data URIs, empty locators, missing local targets, and malformed URL quoting remain distinguishable without I/O;
- references nested under an ID-bearing source are attached to every containing ID scope.

This is intentionally a conservative token grammar, not complete CSS Syntax parsing. Unsupported or ambiguous syntax remains guarded by the existing cascade, paint, resource, or visual-attribute Diagnostics. False-positive dependency candidates are acceptable; silently dropping a reference inside the admitted grammar is not.

## Report projection

The complete graph is private because a diff report should not force an Agent to process every unchanged scene edge. Supported semantic passes continue to emit resource Changed Facts and list affected consumers. Unsupported effects keep precise Diagnostics and partial coverage. The graph supplies topology and safety; later clip, mask, filter, image, external-bundle, and compositing items supply the corresponding computed and rendered transfer rules.
