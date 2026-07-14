# Milky XML 0.4.0 Evaluation

Status: adopted for authored XML parsing

Evidence snapshot: 2026-07-13

This note preserves the dependency evaluation. Current ownership and support boundaries are summarized in [`../renderer-evaluation.md`](../renderer-evaluation.md) and [`../v1-scope.md`](../v1-scope.md).

`Milky2018/xml@0.4.0` was installed from Mooncakes and evaluated against the Source Semantics requirements. It rejects trailing content, mismatched tags, duplicate attributes, unclosed elements, and unsafe external entity references. Its namespace-aware event stream preserves explicit element boundaries and supplies half-open UTF-16 Source Spans for events, attributes, attribute names, and unquoted attribute values. Normalized values such as `A&B` can therefore coexist with recoverable authored spelling such as `A&amp;B`.

Parse failures carry contextual Source Spans. Mismatched tags and duplicate attributes cover relevant authored input, while an unclosed-element failure points to the unmatched opening tag. A trailing-content failure may use a zero-width span at the first illegal character; this is sufficient for core v1 diagnostics but does not by itself highlight the entire trailing token.

The published package passed five project integration cases covering authored spelling, namespace-qualified elements, explicit start/end events, malformed-input spans, non-BMP offsets, and disabled external entity resolution. The upstream native suite passed 845 of 845 tests. SVG Diff therefore removes its custom XML parser and consumes `NamespaceReader` directly through private Source Semantics helpers.
