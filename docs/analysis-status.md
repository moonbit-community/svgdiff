# Analysis Status Contract

Status: current schema `5.0` caller contract

Last verified: 2026-08-18

`analysis_status` summarizes the engine's internal per-feature, per-evidence-layer coverage under the recorded comparison inputs. Successful coverage rows are not serialized; actual gaps appear in `limitations`. The status does not describe how many differences exist or how visually important a difference is.

The status belongs to one Structured Report and one exact renderer/profile execution. A future [multi-renderer experiment matrix](multi-renderer-profiles.md) may associate several reports or external observations, but it cannot upgrade a cell's `partial` or `failed` status, turn missing cells into agreement, or extend one cell's equality/completeness claim to another target or profile.

The canonical profile never executes SVG scripts. Encountering script-capable content therefore prevents complete dynamic-state equality even when the two script sources are identical or a separate browser capture happens to match. A future [Script Observation](script-execution-boundary.md) cannot upgrade the report's status or turn disabled execution into measured zero.

The current profile also declares no interaction state. Unsupported pseudo-class selectors keep the affected report partial; they are not treated as false. A future [Interaction State Profile](interaction-state-profiles.md) would establish completeness only for one resolved checkpoint, while a failed, unstable, or target-local browser replay cannot upgrade status or establish checkpoint equality.

The current profile also disables animation rather than sampling it at zero. A future [Animation Timeline Profile](animation-timeline-model.md) would scope completeness to one exact resolved checkpoint or independently proven interval; matching finite samples or an external browser replay cannot upgrade current status or establish temporal equality.

The current profile has no `foreignObject` host-language layout engine. Even empty or identical foreign content keeps the affected report partial; outer geometry or matching browser pixels cannot upgrade status. A future [Foreign Object Layout Profile](foreign-object-layout-boundary.md) would establish completeness only for its exact namespace, markup, style, layout, font, resource, paint, and SVG-integration subset.

The current profile resolves only admitted data URLs and exact opaque PNG/JPEG bundle keys. An external URL remains partial even when a network target currently exists or before/after locators match. A future [Resource Snapshot Bundle](general-resource-snapshot-bundles.md) could close one exact side-qualified request graph, but a missing snapshot, acquisition transcript, or matching URL cannot upgrade current status.

## Status summary

| Status | Comparison result available | Complete equality conclusion allowed | CLI exit status |
| --- | --- | --- | ---: |
| `complete` | Yes | Yes, but only when the report contains no Atomic Differences and only within the recorded profile and support contract | `0` |
| `partial` | Yes, with constrained claims | No | `0` |
| `failed` | No usable semantic comparison | No | `1` |

Invalid CLI arguments and file I/O failures are not analysis results and exit with status `2` without producing a valid Structured Report. The stable process-level mapping is defined in the [CLI Exit-Code Contract](cli-exit-codes.md).

Likewise, the embedding-only [`compare_with_control`](library-api.md) and `compare_with_control_and_resources` operations raise the `Cancelled` or `CheckpointBudgetExceeded` case of `ComparisonInterrupted` and return no report. Interruption is request control flow, not `analysis_status = "failed"`, because no complete evidence inventory was established. The ordinary comparison and CLI status table are unchanged.

## `complete`

A `complete` report guarantees all of the following:

1. Both inputs were parsed successfully.
2. Every encountered visual semantic falls within the current [complete-eligible feature coverage](feature-coverage.md), or is nonvisual metadata outside visual difference enumeration.
3. Every changed supported authored fact discovered by the accepted analyzers is represented by an item in `difference_groups` and is not silently discarded because its computed or rendered effect is zero.
4. Every resulting Atomic Difference preserves its available source, computed, and rendered evidence according to the feature analyzer.
5. No known unsupported feature, unresolved environment input, or failed measurement could invalidate the report's conclusions under the recorded profile.
6. Every Difference Region's Cause Envelope is a `sound_overapproximation`: it may contain false-positive candidates but must contain every actual changed cause within the supported coverage boundary.

A complete report with no Atomic Differences supports this statement:

> No visual-semantic difference was found within schema `5.0`'s implemented support contract under the recorded comparison inputs.

It does not support any of these stronger statements:

- the source files are byte-for-byte or XML-identical;
- the SVGs are equivalent under another viewport, DPR, renderer, font environment, resource snapshot, background, browser, future interaction state, animation checkpoint, temporal interval, or foreign-content profile;
- the SVGs would remain equivalent after the support contract expands;
- nonvisual metadata is identical.

Whether a report was fully recomputed or returned by a future validated exact-result cache cannot strengthen this claim. Cache provenance is operational metadata outside Structured Report semantics, and no cache hit may promote `partial` or `failed` evidence to `complete`. The current product performs full comparisons and has no persistent cache; see the [cache investigation](incremental-cache-investigation.md).

The independent `SourceAuditReport.analysis_status` is not this field and does not compose into Structured Report coverage. A malformed source audit can fail independently; a complete visual report can coexist with nonvisual source-audit differences.

A complete report may contain Atomic Differences with zero rendered magnitude. `complete` means the analysis claim is covered, not that every semantic difference changes a pixel.

## `partial`

A `partial` report guarantees all of the following:

1. Both inputs were parsed sufficiently to return a Structured Report.
2. Independently supported evidence is retained, including source-level differences that can be established before the unsupported layer.
3. Every known coverage gap is represented by one or more `limitations` entries with affected evidence layers.
4. Computed relations blocked by a coverage gap use `indeterminate` rather than being coerced to `equivalent` or `different`.
5. Unavailable measurements remain absent or `not_computed`; they are not serialized as measured zero. A numeric pinned-renderer observation may remain present when only renderer conformance is limited, but the relevant coverage cell and Diagnostic prevent treating it as browser-conformant evidence.
6. Cause Envelopes whose completeness cannot be proven use `not_established` and retain the relevant limitation IDs.

A partial report does not permit an equality conclusion, even when:

- every `difference_groups[].items` array is empty;
- all available raster metrics are zero;
- the two renderer outputs happen to match;
- the unsupported construct appears unchanged in the two source files.

Consumers may use the supported differences, magnitudes, regions, and candidates that are present, but must qualify any summary with the limitations that constrain it. The CLI returns status `0` because partial analysis is a successfully produced result, not a process failure.

If the required Visual Object Graph cannot be assembled after the primitive
comparison succeeds, `visual_scene_analysis_unavailable` limits Source
Semantics and Computed Appearance, `scene.summary.status` remains
`not_computed`, and the report is partial. An empty scene in that state is not
evidence that the documents contain no visual objects or coherent changes.

An unsupported direct filter primitive demonstrates this rule: schema `5.0` emits a source-only Atomic Difference and limitation links, while leaving its effective relation indeterminate, magnitude absent, rendered outcome unavailable, regions empty, and causal completeness unestablished. The retained change prevents source loss; it does not make the report complete or prove that the edit changes pixels.

## `failed`

A `failed` report means the engine could not establish a usable semantic comparison. Malformed XML produces `svg_parse_failed` with the parser's source-role-qualified UTF-16 span. Invalid caller resource-bundle configuration produces `resource_bundle_invalid` before SVG comparison, including when the invalid entry is unused. Crossing a fixed [comparison resource limit](resource-limits.md) produces `resource_limit_exceeded`; its subject identifies the dimension, and source-local structural limits retain the first offending span. A cyclic or explosively expanding accepted local-reference graph instead produces `reference_cycle_detected` or `reference_expansion_limit_exceeded` with the establishing reference spans; cycle safety covers unused accepted definitions. The complete missing, invalid, cyclic, and unused decision matrix is the [Resource Outcome Policy](resource-outcome-policy.md).

The report still has the schema's required top-level fields so callers can parse it uniformly, but its difference arrays must not be interpreted as evidence of equality or absence. Callers should surface the Diagnostics and stop semantic interpretation. The CLI returns status `1`.

## Status composition

Status follows the strongest encountered failure condition:

```text
failed > partial > complete
```

- A parse failure or resource-limit rejection makes the comparison `failed`.
- Otherwise, any `limited` coverage cell makes the comparison `partial` and references one or more Diagnostics.
- Only a matrix with no `limited` or `failed` cell may summarize to `complete`.

Before the summary is accepted, the engine enforces the [Coverage Proof Obligations](coverage-proof-obligations.md). An analyzer with missing feature rows or inconsistent Diagnostic references is downgraded through `coverage_proof_incomplete` rather than trusted.

The [terminal evidence-or-Diagnostic coverage gate](../evaluation/terminal-coverage-gate/README.md) validates this production status composition together with admitted, guarded, unsupported, failed-admission, hostile, and advanced-profile boundaries. It closes the terminal claim only for the declared profile: no test count, raw pixel agreement, empty difference inventory, or future identity format can widen `complete` beyond this contract.

The number or magnitude of Atomic Differences never changes this ordering. A large fully analyzed change can be `complete`; an apparently identical document pair containing one unsupported element is `partial`.

## Caller decision procedure

1. Verify `schema_version` before interpreting fields.
2. Read `analysis_status` before inspecting difference counts or magnitudes.
3. Read `limitations`; an empty list means no encountered limitation, not global SVG support.
4. If `failed`, report limitations and stop.
5. If `partial`, retain supported findings but state the limitation and do not claim equality.
6. If `complete`, interpret every `difference_groups[].items[]` entry; claim profile-scoped equality only when all groups are empty.
7. Use comparable measurements for prioritization, never `analysis_status` or cross-domain values with unlike units.

## Executable enforcement

- Complete, partial, and failed report cases: [`structured_report_test.mbt`](../modules/svgdiff/engine/structured_report_test.mbt)
- Unsupported-feature equality guards: [`generic_shape_diff_test.mbt`](../modules/svgdiff/engine/generic_shape_diff_test.mbt)
- Partial Cause Envelope downgrade: [`cause_envelope_test.mbt`](../modules/svgdiff/engine/cause_envelope_test.mbt)
- CLI exit behavior: [`modules/svgdiff/cmd/svgdiff/main.mbt`](../modules/svgdiff/cmd/svgdiff/main.mbt) and [`scripts/test-cli.sh`](../scripts/test-cli.sh)
- Feature-level traceability: [`feature-coverage.md`](feature-coverage.md)
