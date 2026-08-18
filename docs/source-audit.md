# Nonvisual Source Audit

Status: current source-audit schema `1.0` contract

Last verified: 2026-07-16

`svgdiff` keeps its default Structured Report focused on visual semantics. Purely descriptive source changes do not become visual Atomic Differences, do not receive visual magnitudes or regions, and do not appear in Visual Events. Callers that also need those changes can invoke the separate `audit_nonvisual_metadata(before_svg, after_svg)` library operation.

## Audited facts

The source-only audit inventories two deliberately narrow fact families:

- exact authored inner content of outermost SVG `title`, `desc`, and `metadata` elements;
- exact authored values of unprefixed `aria-*` and `data-*` attributes outside an already captured descriptive subtree.

This is not a byte diff, full XML tree audit, RDF interpretation, accessibility conformance check, or browser accessibility-tree comparison. It does not silently classify `id`, `class`, `style`, namespace declarations, resource locators, arbitrary unknown attributes, comments, or processing instructions as nonvisual metadata.

## Identity and alignment

Each fact has a namespace-expanded element path. A segment uses Clark notation when a namespace URI exists and a same-expanded-name sibling ordinal, for example `/{http://www.w3.org/2000/svg}svg[1]/{http://www.w3.org/2000/svg}title[1]`. Prefix spelling therefore does not change semantic path identity, while a namespace change does. Unqualified SVG accepted by the visual engine uses ordinary `/svg[1]/title[1]` segments.

Facts align by `(kind, path, name)`. `kind` is `element_content` or `attribute`. A different `authored_value` creates a change; a fact present on only one side creates an insertion or deletion through a null `before` or `after`. Differences are sorted by that key and receive deterministic `source-audit:N` IDs. Every present fact carries a half-open UTF-16 `source_span` into its original side.

Captures do not overlap. Once an outermost descriptive element is selected, its exact inner source is one fact and nested descriptive markup or metadata attributes are not separately inventoried. This keeps one authored byte range from becoming several audit differences and preserves arbitrary metadata vocabularies without pretending to interpret them.

## Visual boundary

Before ordinary visual analysis, the engine replaces each captured descriptive element's inner content with the same number of UTF-16 spaces. The outer element, its attributes, namespace state, and sibling position remain present. As a result:

- foreign vocabulary, shapes, styles, resource-looking descendants, and invalid visual values inside descriptive content cannot fabricate visual subjects, coverage Diagnostics, or reference cycles;
- Source Spans outside the content remain unchanged;
- a supported CSS selector whose result depends on the outer element or a `data-*`/`aria-*` attribute can still produce its real visual paint or geometry consequence;
- the metadata value itself never becomes a visual Atomic Difference.

The last point is consequence-aware rather than a claim that every metadata-bearing node is inert. For example, changing `data-state="on"` to `off` is absent from the visual report when no supported selector consumes it, but a `[data-state='on'] { fill: red }` rule can make the resulting `paint.fill` change reportable. The optional source audit reports the attribute change in both cases.

Masking is not a resource-limit bypass. Whole-source input size, XML element, nesting, path-command, and reference-count limits still inspect the original source before semantic analysis. Metadata content can therefore make an input inadmissible by exceeding those fixed safety budgets even though it cannot create visual subjects, semantic resource edges, or visual-coverage Diagnostics.

## Status and JSON

`SourceAuditReport` has its own `audit_schema_version`, `analysis_status`, `differences`, and `diagnostics`. Schema `1.0` permits `complete` and `failed`. If either input is malformed, the audit is `failed`, has no partial difference inventory, and returns one `svg_parse_failed` Diagnostic per malformed side with `before` or `after` and an available parser span.

`SourceAuditReport::to_json_string` and `to_compact_json_string` serialize the same evidence. The independent [source-audit JSON Schema](../schema/svgdiff-source-audit.schema.json) and [canonical example](../schema/examples/nonvisual-source-audit.json) do not change Structured Report schema `5.0`. No source-audit field is ever injected into Structured Report JSON.

## Executable enforcement

- Visual exclusion, offset-preserving masking, CSS consequences, audit alignment, namespaces, Unicode spans, failures, and determinism: [`source_audit_wbtest.mbt`](../modules/svgdiff/engine/source_audit_wbtest.mbt)
- Root public API and serialization separation: [`svgdiff_test.mbt`](../svgdiff_test.mbt)
- JSON Schema positive and negative controls: [`validate.py`](../evaluation/source-audit/validate.py)
- Canonical visual equality report with changed metadata: [`nonvisual-metadata-equivalent.json`](../schema/examples/nonvisual-metadata-equivalent.json)
