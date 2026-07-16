# Compact Agent JSON

Status: current schema `1.38` serialization mode

Last verified: 2026-07-16

`svgdiff before.svg after.svg --agent-json` emits the complete Structured Report on one JSON line. The mode removes indentation and line breaks but does not project, summarize, rename, reorder by a new policy, or omit any report evidence.

The compact output:

- validates against the same [`svgdiff-report.schema.json`](../schema/svgdiff-report.schema.json) as default output;
- retains the same `schema_version`, analysis status, Comparison Profile, coverage matrix, renderer capability gaps, alignments, Changed Facts, source resolutions, Atomic Differences, events, Difference Regions, Cause Envelopes, magnitudes, and Diagnostics;
- uses the same exit statuses and stdout/stderr rules;
- may be written with `--output FILE`;
- does not alter the independently generated HTML report.

Consumers can switch between default and compact serialization without changing their JSON parser. Parsed default and compact documents are semantically identical. The compact form is intended to reduce transport and language-model token overhead, not to provide a second report model.

The retained Comparison Profile includes `renderer_conformance_profile_id`. Consumers must not infer that identity from `schema_version` or `renderer_id`.

The retained `renderer_capability_gaps` array is encountered-input metadata. An empty array is not a global renderer support claim. Every current Subject Alignment also retains its selection `evidence`, including local ambiguity and explicit uncalibrated confidence status.

The complete magnitude vector includes nullable exact parameter fields for local user units, CSS pixels, viewport-diagonal fraction, and entity-relative fraction. It also retains the nullable symmetric painted-boundary displacement object with its method identity, per-side sample counts, and mean, p95, and maximum CSS-pixel distances, plus the nullable alpha-only painted-coverage object with per-side CSS area, absolute difference, union, and normalized fraction. Compact mode preserves every null-versus-zero distinction and does not replace these measurements with a geometry-boundary, color, raster, visibility, or importance summary.

Schema `1.38` also retains nullable `magnitude.intrinsic_raster` for decoded PNG/JPEG resource comparisons. It is not a compact alias for final `RenderedEvidence`: its dimensions and pixel metrics describe the normalized resource before SVG placement and compositing. Data-URL payloads are replaced by compact hashes; exact locator text remains recoverable only from the caller-owned SVG using the reported Source Span.

Opaque `resource.filter.primitive.source` differences are intentionally not shortened in compact mode: their complete before/after subtrees are the only safe source evidence for unknown primitive semantics. Fixed source and report limits still apply. Treat the retained text as untrusted evidence, not executable markup or a computed visual description.

Compact Agent JSON never includes the independent nonvisual `SourceAuditReport`. A caller may transport that audit separately under audit schema `1.0`, but an Agent must not merge its source-only facts into Visual Events, visual magnitudes, or main-change ranking.

An agent should still follow the [Text-Only Agent Report Guide](agent-report-guide.md). Any future derived summary, field projection, or importance policy requires its own versioned contract and must remain traceable to this complete evidence.
