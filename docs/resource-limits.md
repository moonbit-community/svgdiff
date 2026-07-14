# Comparison Resource Limits

Status: current module `0.3.2` and schema `1.4` contract

Last verified: 2026-07-14

Every production comparison uses the same fixed safety budgets. The public API does not expose a configurable limits record: changing these defaults is a versioned behavior change that must be reviewed against the compatibility contract and adversarial corpus.

## Production budgets

| Dimension | Scope | Inclusive maximum | Counted quantity |
| --- | --- | ---: | --- |
| Input bytes | Each SVG independently | 8,388,608 | UTF-8 bytes, counted before XML parsing without allocating an encoded copy |
| Elements | Each SVG independently | 100,000 | Namespace-aware XML start and empty-element events |
| Path complexity | Each SVG independently | 1,000,000 | Non-separator Unicode scalar values in every `<path d>` attribute; XML whitespace and commas do not count |
| Nesting depth | Each SVG independently | 256 | Simultaneously open XML elements, including the root |
| References | Each SVG independently | 100,000 | Every `href` attribute plus every case-insensitive `url(` token in attribute values |
| Materialized reference graph edges | Each SVG independently | 1,000,000 | Reference-edge copies propagated across containing ID scopes; checked before appending the first excess edge |
| Expanded elements | Each SVG independently | 1,000,000 | Conservative transitive authored-element upper bound across all accepted local `<use>` edges |
| Raster dimensions | Comparison Profile | 8,192 per axis and 16,777,216 total pixels | Positive viewport width, height, and their product before any render |
| Difference Regions | Whole report | 65,536 | Connected pixel regions and event-attached computed or pixel regions |
| Report bytes | Each built-in JSON form | 33,554,432 | The larger UTF-8 size of indented and compact serialization |

Path-data units deliberately form a conservative lexical work budget, not a segment count or a geometry metric. Complete path parsing and segment-level evidence remain separate roadmap work. Reference counting bounds reference-bearing source size; the separate [local-reference safety contract](reference-safety.md) rejects cycles and bounds transitive `<use>` expansion.

## Failure semantics

The engine checks raster dimensions before rendering, input bytes before parsing, XML structure and local-reference expansion while consuming bounded event streams, regions while extracting and attaching them, and report bytes at the serialization boundary. The exact inclusive boundary is accepted; the first unit beyond it is rejected.

An exceeded ordinary budget, including the materialized reference-graph edge budget, returns a small schema-valid report with:

- `analysis_status = "failed"`;
- one or more `resource_limit_exceeded` Diagnostics;
- a stable dimension key in `Diagnostic.subject_id`, qualified with `.before` or `.after` for source-local limits;
- a source location for the first offending XML element or attribute when one exists;
- failed coverage rows under `resource.<dimension>`;
- empty alignment, fact, difference, and event inventories.

The empty inventories are not truncated evidence and cannot support an equality conclusion. A caller must surface the Diagnostics and stop semantic interpretation. If both inputs independently fail a source budget, the bounded failure report may identify both; scanning stops at the first structural overrun within each input.

Malformed XML remains `svg_parse_failed`, not a resource failure, unless an earlier resource boundary is crossed first. Invalid or excessive viewport dimensions use the same resource failure because the renderer is never invoked outside the accepted raster boundary.

## Boundary and non-goals

The region budget stops region extraction and event attachment at the first excess, so it bounds retained region work. The report-byte budget checks completed built-in serializations; it bounds emitted JSON but does not claim to cap the transient memory needed to construct that serialization. The CLI currently reads each selected file or stdin stream into a String before the engine counts it, so the input budget protects parsing and later stages rather than initial file-read allocation.

Cancellation, wall-clock budgets, streaming input admission, peak-memory accounting, and publicly configurable embedding policies remain explicit roadmap items. The generated HTML includes both bounded input sources in addition to report JSON and therefore has no separate report-byte identity.

## Executable evidence

[`resource_limits_wbtest.mbt`](../engine/resource_limits_wbtest.mbt) covers exact and one-past boundaries for every dimension, non-ASCII UTF-8 accounting, reference cycles, acyclic repeated-use expansion, source locations, non-truncation, and bounded failure reports. [`test-cli.sh`](../scripts/test-cli.sh) covers the public failed-report and exit-status behavior.
