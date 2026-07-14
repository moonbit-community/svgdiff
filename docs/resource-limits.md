# Comparison Resource Limits

Status: current module `0.4.1` and schema `1.7` contract

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

Path-data units deliberately form a conservative lexical work budget, not a segment count or a geometry metric. Exact normalized segment comparison occurs only after this admission bound succeeds. Reference counting bounds reference-bearing source size; the separate [local-reference safety contract](reference-safety.md) rejects cycles and bounds transitive `<use>` expansion.

Guarded path boundary observations use a separate best-effort work budget:

| Dimension | Scope | Inclusive maximum |
| --- | --- | ---: |
| Aligned path comparisons | Whole report | 64 |
| Isolated raster pixels | Each before or after path image | 1,048,576 |
| Isolated raster work pixels | Whole report, counting both sides | 4,194,304 |

This budget controls only the optional isolated alpha-boundary maximum-distance observation. Exhaustion leaves `geometry_displacement_css_px` null for later path differences but does not truncate normalized path command, parameter, or topology differences. Both empty isolated boundaries produce measured zero; exactly one empty boundary makes the distance unavailable. Path coverage is already partial under `unsupported_visual_subject`, so exhausting this observation budget is not a failed comparison and does not create a resource-limit Diagnostic.

Normalized segment sequence alignment uses at most 65,536 dynamic-programming cells. Larger before/after segment products use deterministic positional alignment instead. That fallback still enumerates every compared, inserted, or deleted position and cannot turn a changed segment inventory into equality, but it may conservatively report more parameter or topology differences than an unbounded minimum-edit alignment would.

## Failure semantics

The engine checks raster dimensions before rendering, input bytes before parsing, XML structure and local-reference expansion while consuming bounded event streams, regions while extracting and attaching them, and report bytes at the serialization boundary. The exact inclusive boundary is accepted; the first unit beyond it is rejected.

An exceeded ordinary budget in the production table, including the materialized reference-graph edge budget, returns a small schema-valid report with:

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

The public [`compare_with_control`](library-api.md) operation adds cooperative cancellation and an elapsed-time budget around these fixed resource limits. Interruption returns no report and does not replace a resource-limit Diagnostic. It cannot preempt one synchronous dependency parse or render call, and the CLI does not expose it. Streaming input admission, peak-memory enforcement, hard preemptive deadlines, and configurable resource-limit policies remain future work. The generated HTML includes both bounded input sources in addition to report JSON and therefore has no separate report-byte identity.

## Executable evidence

[`resource_limits_wbtest.mbt`](../engine/resource_limits_wbtest.mbt) covers exact and one-past boundaries for every dimension, non-ASCII UTF-8 accounting, reference cycles, acyclic repeated-use expansion, source locations, non-truncation, and bounded failure reports. [`test-cli.sh`](../scripts/test-cli.sh) covers the public failed-report and exit-status behavior.
