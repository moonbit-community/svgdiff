# Concise Agent JSON

Status: current schema `1.46` serialization contract

Last verified: 2026-07-22

`svgdiff before.svg after.svg` emits an indented Structured Report. Adding
`--agent-json` removes formatting whitespace but produces the same JSON value.

The formal report has seven top-level fields:

- `schema_version` and `analysis_status` establish the contract and whether an
  equality conclusion is allowed;
- `comparison` records only caller-relevant comparison inputs such as the
  viewport and requested perceptual conditions;
- `canvas` records whole-canvas measurements once;
- `difference_groups` contains every Atomic Difference, grouped by visual
  domain and kept in the engine's domain-specific magnitude order;
- `events` links differences to rendered outcomes, localization, and possible
  causes;
- `limitations` contains only actual conditions that constrain a conclusion.

The serializer deliberately excludes successful coverage rows, renderer
adapter chains, alignment candidates and scores, Changed Fact tables, Source
Resolution tables, source spans, evidence-layer bookkeeping, ordering-policy
vectors, Impact frontier witnesses, duplicate pixel/CSS rectangles, RGBA8
duplicates, FLIP pixel maps, unrequested metric statuses, and null placeholders.
These are engine implementation state, not product-report content.

## Missing, zero, and limited values

A computed numeric zero is serialized as `0`. A metric that is not applicable
or was not requested is omitted. If the current comparison ought to provide an
answer but cannot, the affected difference or region links to one or more
entries in `limitations`; a noncomputed event outcome also includes a short
reason code. Consumers must never substitute an omitted value with zero.

## Differences and events

Each difference retains its stable ID, affected subject and role, semantic
`kind`, exact authored before/after values, effective relation, available
numeric magnitudes, and limitation links. Thus `red` to `#ff0000` remains an
authored difference with `effective.relation = "equivalent"` and explicit
zero raster measurements.

Each event lists its Atomic Difference IDs. A region contains one CSS-space
bounding box, its observed or conservative kind, and a possible-cause envelope.
When `possible_causes.guarantee` is `sound_overapproximation`, the candidate
Atomic Difference IDs may include false positives but contain every actual
changed cause within complete analysis coverage. `not_established` makes no
such claim.

## Independent measurements

Changed fraction, linear-premultiplied-RGBA RMSE, optional perceptual response,
geometric displacement, coverage, and other domain magnitudes are distinct
measurements. The JSON neither serializes a universal impact score nor exposes
the engine's internal Pareto bookkeeping. Consumers may sort within a common
domain but must not compare unlike units or invent calibrated severity.

The JSON Schema is [`svgdiff-report.schema.json`](../schema/svgdiff-report.schema.json).
Default and `--agent-json` documents both validate against it and differ only in
whitespace.
