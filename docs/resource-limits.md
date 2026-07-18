# Comparison Resource Limits

Status: current module `0.5.30` and schema `1.45` contract

Last verified: 2026-07-16

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
| Embedded data-URL bytes | Each `image` locator | 6,291,456 | ASCII data-URL source characters before payload decoding |
| Embedded raster bytes | Each admitted PNG or JPEG | 4,194,304 | Decoded resource-file bytes before image decoding |
| Embedded raster dimensions | Each admitted PNG or JPEG | 8,192 per axis | Validated intrinsic width and height before normalized RGBA8 allocation |
| Embedded raster pixels | Each image and cumulatively per SVG | 16,777,216 | Validated intrinsic width times height; cumulative total counts every admitted image occurrence |
| Resource bundle entries | Each before or after bundle | 1,024 | Ordered caller-supplied locator records validated before source analysis |
| Resource bundle entry bytes | Each supplied entry | 4,194,304 | Caller-supplied bytes before signature validation or image decoding |
| Resource bundle bytes | Each before or after bundle | 16,777,216 | Sum of every supplied entry, including entries not referenced by the SVG |
| PNG decompression output | Each admitted PNG | Exact validated scanline length | Filter bytes plus encoded scanline bytes derived from IHDR dimensions, bit depth, and color type |
| Raster dimensions | Comparison Profile | 8,192 per axis and 16,777,216 total pixels | Positive viewport width, height, and their product before any render |
| Difference Regions | Whole report | 65,536 | Connected pixel regions and event-attached computed or pixel regions |
| LDR-FLIP map pixels | Whole report | 1,048,576 | Serialized event-map samples across every computed FLIP event |
| LDR-FLIP filter samples | Whole report | 268,435,456 | Spatial and feature kernel-sample visits over event context images |
| Report bytes | Each canonical JSON form | 33,554,432 | The larger UTF-8 size of indented and compact serialization |

The admitted filter executor additionally caps each graph at 256 direct primitives and aggregate primitive-surface work at 16,777,216 viewport pixels per source. Crossing either bound produces partial `filter_graph_budget_exceeded` evidence rather than executing an unbounded graph; exact filter source facts remain present. This is a feature-admission guard, not a failed whole-comparison resource report.

Opaque unsupported filter primitives add no second retained subtree string during semantic extraction: the internal record keeps only bounded input offsets, position, type, and subject identity. Exact subtree text is sliced when a Diagnostic or changed report fact requires it, then remains subject to the ordinary 8 MiB per-input and 32 MiB serialized-report limits. Malformed XML cannot yield a completed subtree record and follows the existing `svg_parse_failed` path.

The admitted blend compositor additionally caps each source at 64 active blend or isolation surfaces and 67,108,864 aggregate viewport-surface pixels. The exact inclusive boundary is accepted. Crossing either bound produces partial `blend_surface_budget_exceeded` evidence while retaining exact declarations, resolved keywords, stacking order, and conservative affected subjects; it does not emit a truncated render or a failed whole-comparison resource report.

Optional LDR-FLIP uses aggregate output and convolution-work budgets. Before computing an event map, the engine reserves its complete serialized response area and its spatial-plus-feature filter work over the required context image. If either reservation would exceed the remaining report budget, that event emits `not_computed/perceptual_map_budget_exceeded`. Raw Rendered Evidence, DeltaEOK, Difference Regions, equality, Diagnostics, Cause Envelopes, coverage, and ordering remain unchanged; this condition is not a failed whole-comparison resource report.

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

The engine checks raster dimensions before rendering, input bytes before parsing, XML structure and local-reference expansion while consuming bounded event streams, embedded data-URL and decoded-file bytes before image decoding, intrinsic dimensions and pixels before normalized RGBA8 allocation, cumulative image pixels while scanning each source, PNG decompression against its exact validated scanline length, regions while extracting and attaching them, and report bytes at the serialization boundary. The exact inclusive boundary is accepted; the first unit beyond it is rejected.

An exceeded ordinary budget in the production table, including the materialized reference-graph edge budget, returns a small schema-valid report with:

- `analysis_status = "failed"`;
- one or more `resource_limit_exceeded` Diagnostics;
- a stable dimension key in `Diagnostic.subject_id`, qualified with `.before` or `.after` for source-local limits;
- a source location for the first offending XML element or attribute when one exists;
- failed coverage rows under `resource.<dimension>`;
- empty alignment, fact, difference, and event inventories.

The empty inventories are not truncated evidence and cannot support an equality conclusion. A caller must surface the Diagnostics and stop semantic interpretation. If both inputs independently fail a source budget, the bounded failure report may identify both; scanning stops at the first structural overrun within each input.

Malformed XML remains `svg_parse_failed`, not a resource failure, unless an earlier resource boundary is crossed first. Invalid image syntax, MIME/signature mismatch, or decoder failure remains partial `embedded_raster_data_invalid`; those conditions are not relabeled as resource exhaustion. Invalid or excessive viewport dimensions use the same resource failure because the renderer is never invoked outside the accepted raster boundary.

## Boundary and non-goals

The region budget stops region extraction and event attachment at the first excess, so it bounds retained region work. The report-byte budget checks completed canonical serializations; it bounds default and `--agent-json` output but does not claim to cap the transient memory needed to construct that serialization. The lossless Agent projection is derived only from an already bounded report. Its total JSONL may add one small envelope per bounded array item and is not a third 32 MiB report-byte measurement; each individual record contains at most one canonical item plus fixed metadata. The CLI currently reads each selected file or stdin stream into a String before the engine counts it, so the input budget protects parsing and later stages rather than initial file-read allocation.

The public [`compare_with_control`](library-api.md) operation adds cooperative cancellation and a deterministic engine-checkpoint budget around these fixed resource limits. Interruption returns no report and does not replace a resource-limit Diagnostic. It cannot preempt one synchronous dependency parse or render call, and neither executable entry exposes it. Streaming input admission, peak-memory enforcement, hard preemptive deadlines, and configurable resource-limit policies remain future work. The generated HTML includes both bounded input sources in addition to report JSON and therefore has no separate report-byte identity.

No current limit authorizes persistent cache storage or lookup because the product has no persistent cache. A future exact-result cache must independently cap key manifests, entry bytes, total storage, parsing, lookup, atomic publication, and eviction work. It must still include the comparison's effective deterministic limits in the key and validate a cached report against the active report-byte limit; an oversized, corrupt, or unknown entry is a miss, not a truncated report.

These budgets do not authorize or bound script execution because the canonical engine never executes scripts. A future external [Script Observation](script-execution-boundary.md) must run outside the comparison process and independently cap instructions or fuel, memory, stack, tasks, microtasks, timers, DOM growth and mutations, logs, output, wall time, and process descendants. A wall-clock timeout alone is a safety kill, not a deterministic execution result.

No current budget authorizes interaction-state resolution or browser action replay. A future [Interaction State Profile](interaction-state-profiles.md) must separately cap devices, target locators, cross-side mappings, hit-test candidates, state fixed-point iterations, derived matches, and manifest bytes. An external action observation must additionally cap action ticks, dispatched work, transcript and postcondition records, capture output, time, memory, and process descendants; an exhausted or cycling state is unavailable, not an arbitrary chosen match set.

No current budget authorizes animation schedule resolution or frame capture. A future [Animation Timeline Profile](animation-timeline-model.md) must cap schedule nodes and edges, rational size, event occurrences, repeat expansion, style-change transactions, mapped effects, checkpoints, interval partitions, evaluator work, renderer work, and output. External observations additionally cap tasks, microtasks, timers, frame callbacks, mutations, transcript bytes, memory, wall time, and descendants; a wall-time kill or exhausted temporal budget is unavailable evidence, not a selected final frame.

No current budget authorizes `foreignObject` host-language processing. A future [Foreign Object Layout Profile](foreign-object-layout-boundary.md) must separately cap foreign tree depth and nodes, attributes and text, style sheets, selectors and declarations, generated boxes and fragments, lines and glyphs, resources and decoded surfaces, layout passes, cross-boundary effects, recursion, output, and evaluator work. External observations additionally require hard process time, memory, filesystem, network, credential, and descendant isolation; exhausted layout is unavailable, not empty content.

No current budget authorizes generalized resource snapshots, URL resolution, recursive external closure, or prefetch. A future [Resource Snapshot Bundle](general-resource-snapshot-bundles.md) must cap manifest and member bytes, URLs, logical requests, response headers, redirects, representation bytes, roots, edges, nesting, decoded text, parsed nodes, decompression, surfaces, total work, digests, and output. A separate prefetcher additionally caps DNS/connect/read time, private-network decisions, concurrency, transfer bytes, content decoding, processes, memory, logs, and atomic output; exhaustion produces a typed snapshot or acquisition failure, never truncated complete content.

## Executable evidence

[`resource_limits_wbtest.mbt`](../engine/resource_limits_wbtest.mbt) covers exact and one-past boundaries for the general dimensions, non-ASCII UTF-8 accounting, reference cycles, acyclic repeated-use expansion, source locations, non-truncation, and bounded failure reports. [`perceptual_flip_wbtest.mbt`](../engine/perceptual_flip_wbtest.mbt) covers event-local FLIP budget exhaustion and independence from other evidence. [`embedded_image_diff_wbtest.mbt`](../engine/embedded_image_diff_wbtest.mbt) covers exact data-URL, decoded-byte, dimension, per-image, cumulative-pixel, and PNG decompression boundaries. [`resource_bundle_wbtest.mbt`](../engine/resource_bundle_wbtest.mbt) covers bundle entry-count, per-entry-byte, cumulative-byte, configuration, and decoder boundaries. [`test-cli.sh`](../scripts/test-cli.sh) covers the public failed-report, explicit resource-file, and exit-status behavior. [`test-agent-projection.sh`](../scripts/test-agent-projection.sh) proves exact reconstruction and smaller maximum record context for complete, partial, failed, empty-inventory, and FLIP reports.
