# M3 Compact-Summary Traceability Gate

Status: accepted milestone evidence

Gate identity: `svgdiff-m3-summary-traceability-gate/1`

Last verified: 2026-07-17

This gate composes the existing compact JSON, Agent projection, Impact frontier, report-integrity, and derived Markdown contracts. It establishes the M3 claim that compact Agent-facing summaries retain lossless links to the complete evidence graph without creating a second source of truth.

## Exact claim

- Default and `--agent-json` outputs parse to the same complete Structured Report value.
- `svgdiff-agent-projection/2` reconstructs the exact canonical report and rejects incomplete, duplicated, reordered, miscounted, relabeled, unknown-version, and wrong-source-Schema streams.
- Every Impact frontier group carries the exact ordered union of Atomic Differences owned by its listed events.
- Existing typed report references keep regions, Cause Envelopes, Changed Facts, Subject Alignments, and Diagnostics transitively reachable from summary IDs.
- Markdown retains stable frontier, difference, alignment, fact, and Diagnostic IDs plus the report status and Impact limitations. It explicitly says that evidence may be omitted and canonical JSON remains authoritative.

“Lossless” therefore describes compact JSON value identity, projection reconstruction, and graph links. It does not claim that the optional Markdown text can reconstruct every coverage row, event, region, cause, source fact, or profile field by itself.

## Reproduce

```sh
sh scripts/test-m3-summary-traceability-gate.sh
```

The script validates `manifest.v1.json`, checks complete/partial/failed Markdown summaries, checks an empty-inventory projection, and runs the existing CLI, Agent projection, report-determinism/reference-closure, and Impact frontier suites. Negative controls remove required Markdown traceability, alter authority and status text, mutate compact JSON, corrupt projection structure and identities, break Impact semantic edges, and break typed report-reference or causal closure.

The accepted result is:

```text
M3 compact-summary traceability gate: passed
```

This gate changes no product format or policy. Structured Report Schema `3.0`, projection `svgdiff-agent-projection/2`, Impact policy `event_rendered_pareto/v1`, and the derived-only Markdown authority remain unchanged.
