# Concise Agent JSON

Status: current schema `4.0` serialization contract

Last verified: 2026-08-18

`svgdiff before.svg after.svg` emits an indented Structured Report. Adding
`--agent-json` removes formatting whitespace but produces the same JSON value.

The formal report has eight top-level fields:

- `schema_version` and `analysis_status` establish the contract and whether an
  equality conclusion is allowed;
- `comparison` records only caller-relevant comparison inputs such as the
  viewport and requested perceptual conditions;
- `canvas` records whole-canvas measurements once;
- `scene` records aligned Visual Objects and relations, six orthogonal scene
  conclusions, and coherent scene-level change events;
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

## Scene, differences, and events

Read `scene` before the primitive evidence inventory. Its `summary` keeps
content, object-set, relation-graph, layout, style, and representation
conclusions independent. An object alignment may be one-to-one, set-to-set, or
explicitly unmatched; unresolved many-to-many correspondence is retained as
abstention rather than forced into an arbitrary pairing or mislabeled as
presence change. Object-owned rendered subjects cannot pair across accepted
object correspondences. Scene events expose `object`, `systemic`, or
`comparison` scope and reference compact evidence domains plus representative
primitive IDs instead of repeating the whole underlying inventory.

`scene.evidence_coverage` is the losslessness check for this compression.
`classified_difference_count + residual_difference_count` equals
`effective_difference_count`, where effective means every non-`equivalent`
relation, including `indeterminate`. `residual_domains` reports compact counts
for effective Atomic Differences that did not support an emitted scene pattern;
their full records remain in `difference_groups` and their owning primitive
Events remain in `events`.

Each difference retains its stable ID, affected subject and role, semantic
`kind`, exact local authored before/after values, effective relation, available
direct numeric magnitudes, and limitation links. A path-command or
path-parameter difference therefore carries only its corresponding authored
segment rather than repeating the complete `d` attribute.

Each event lists its Atomic Difference IDs. A region contains one CSS-space
bounding box, its observed or conservative kind, and a possible-cause envelope.
The event outcome owns its final raster response exactly once. When all
available child observations agree, `outcome.isolated_subject` also owns the
shared painted-boundary and alpha-coverage comparison exactly once; those
subject-level observations are not repeated on every child difference and must
not be interpreted as each child's independent contribution. Thus `red` to
`#ff0000` remains an authored difference with
`effective.relation = "equivalent"`, while its owning event carries the
explicit measured-zero raster outcome.

All current Event regions are `conservative`. An admitted isolated rendering
may tighten the candidate or prove it empty, while other Events use a
bounds-filtered final-canvas mask or computed bounds. Several Events may
legitimately share a region, and its outcome is a bounded response rather than
an exact contribution. `observed` is reserved for future scene-level
contribution evidence.
`possible_causes.scope = "event_region"` carries explicit
`candidate_difference_ids`. `scope = "comparison"` means every Atomic
Difference in the report remains a candidate and deliberately omits the
redundant ID array. A comparison-scoped envelope whose Diagnostic IDs equal
the complete top-level `limitations` inventory also omits that redundant ID
array; its `coverage` and `guarantee` require consumers to inspect the canonical
top-level inventory. A smaller event-local Diagnostic subset remains explicit
as `limitation_ids`. When `possible_causes.guarantee` is
`sound_overapproximation`, the represented candidates may include false
positives but contain every actual changed cause within complete analysis
coverage. `not_established` makes no such claim.

## Independent measurements

Changed fraction, linear-premultiplied-RGBA RMSE, optional perceptual response,
geometric displacement, coverage, and other domain magnitudes are distinct
measurements. Atomic `magnitude` contains only evidence direct to that
difference. Event `outcome` contains the shared rendered response and optional
shared isolated-subject observations. The JSON neither serializes a universal
impact score nor exposes the engine's internal Pareto bookkeeping. Consumers
may sort within a common domain but must not compare unlike units or invent
calibrated severity.

The JSON Schema is [`svgdiff-report.schema.json`](../schema/svgdiff-report.schema.json).
Default and `--agent-json` documents both validate against it and differ only in
whitespace.
