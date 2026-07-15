# Analysis Status Contract

Status: current schema `1.22` caller contract

Last verified: 2026-07-14

`analysis_status` summarizes the report's per-feature, per-evidence-layer `coverage_matrix` under the recorded Comparison Profile. It does not describe whether the SVGs are equal, how many differences exist, or how visually important a difference is.

## Status summary

| Status | Comparison result available | Complete equality conclusion allowed | CLI exit status |
| --- | --- | --- | ---: |
| `complete` | Yes | Yes, but only when the report contains no Atomic Differences and only within the recorded profile and support contract | `0` |
| `partial` | Yes, with constrained claims | No | `0` |
| `failed` | No usable semantic comparison | No | `1` |

Invalid CLI arguments and file I/O failures are not analysis results and exit with status `2` without producing a valid Structured Report. The stable process-level mapping is defined in the [CLI Exit-Code Contract](cli-exit-codes.md).

Likewise, the embedding-only [`compare_with_control`](library-api.md) operation raises the `Cancelled` or `TimeBudgetExceeded` case of `ComparisonInterrupted` and returns no report. Interruption is request control flow, not `analysis_status = "failed"`, because no complete evidence inventory was established. The ordinary comparison and CLI status table are unchanged.

## `complete`

A `complete` report guarantees all of the following:

1. Both inputs were parsed successfully.
2. Every encountered visual semantic falls within the current [complete-eligible feature coverage](feature-coverage.md), or is nonvisual metadata outside visual difference enumeration.
3. Every changed supported authored fact discovered by the accepted analyzers is represented in `changed_facts` and is not silently discarded because its computed or rendered effect is zero.
4. Every resulting Atomic Difference preserves its available source, computed, and rendered evidence according to the feature analyzer.
5. No known unsupported feature, unresolved environment input, or failed measurement could invalidate the report's conclusions under the recorded profile.
6. Every Difference Region's Cause Envelope is a `sound_overapproximation`: it may contain false-positive candidates but must contain every actual changed cause within the supported coverage boundary.

A complete report with no Atomic Differences supports this statement:

> No visual-semantic difference was found within schema `1.22`'s implemented support contract under the recorded Comparison Profile.

It does not support any of these stronger statements:

- the source files are byte-for-byte or XML-identical;
- the SVGs are equivalent under another viewport, DPR, renderer, font environment, resource environment, background, browser, or future interaction state;
- the SVGs would remain equivalent after the support contract expands;
- nonvisual metadata is identical.

A complete report may contain Atomic Differences with zero rendered magnitude. `complete` means the analysis claim is covered, not that every semantic difference changes a pixel.

## `partial`

A `partial` report guarantees all of the following:

1. Both inputs were parsed sufficiently to return a Structured Report.
2. Independently supported evidence is retained, including source-level differences that can be established before the unsupported layer.
3. Every known coverage gap is represented by one or more Diagnostics with affected evidence layers.
4. Computed relations blocked by a coverage gap use `indeterminate` rather than being coerced to `equivalent` or `different`.
5. Unavailable measurements remain absent or `not_computed`; they are not serialized as measured zero. A numeric pinned-renderer observation may remain present when only renderer conformance is limited, but the relevant coverage cell and Diagnostic prevent treating it as browser-conformant evidence.
6. Cause Envelopes whose completeness cannot be proven use `not_established` and retain the relevant Diagnostic IDs.

A partial report does not permit an equality conclusion, even when:

- `atomic_differences` is empty;
- all available raster metrics are zero;
- the two renderer outputs happen to match;
- the unsupported construct appears unchanged in the two source files.

Consumers may use the supported differences, magnitudes, regions, and candidates that are present, but must qualify any summary with the Diagnostics that constrain it. The CLI returns status `0` because partial analysis is a successfully produced result, not a process failure.

## `failed`

A `failed` report means the engine could not establish a usable semantic comparison. Malformed XML produces `svg_parse_failed` with the parser's source-role-qualified UTF-16 span. Crossing a fixed [comparison resource limit](resource-limits.md) produces `resource_limit_exceeded`; its subject identifies the dimension, and source-local structural limits retain the first offending span. A cyclic or explosively expanding accepted local-reference graph instead produces `reference_cycle_detected` or `reference_expansion_limit_exceeded` with the establishing reference spans.

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

The number or magnitude of Atomic Differences never changes this ordering. A large fully analyzed change can be `complete`; an apparently identical document pair containing one unsupported element is `partial`.

## Caller decision procedure

1. Verify `schema_version` before interpreting fields.
2. Verify `profile.renderer_conformance_profile_id` before treating rendered evidence as a known conformance claim; older schema `1.0` reports may omit it and require an explicit legacy policy.
3. Read `analysis_status` before inspecting difference counts or magnitudes.
4. Read `renderer_capability_gaps` as an encountered-only projection of renderer Diagnostics; do not treat an empty array as global support.
5. If `failed`, report Diagnostics and stop.
6. If `partial`, retain supported findings but state the coverage limitation and do not claim equality.
7. If `complete`, interpret all Atomic Differences; claim profile-scoped equality only when the list is empty.
8. Use magnitude and Domain Ordering for prioritization, never `analysis_status`.

## Executable enforcement

- Complete, partial, and failed report cases: [`structured_report_test.mbt`](../engine/structured_report_test.mbt)
- Unsupported-feature equality guards: [`generic_shape_diff_test.mbt`](../engine/generic_shape_diff_test.mbt)
- Partial Cause Envelope downgrade: [`cause_envelope_test.mbt`](../engine/cause_envelope_test.mbt)
- CLI exit behavior: [`cmd/svgdiff/main.mbt`](../cmd/svgdiff/main.mbt) and [`scripts/test-cli.sh`](../scripts/test-cli.sh)
- Feature-level traceability: [`feature-coverage.md`](feature-coverage.md)
