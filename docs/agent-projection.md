# Lossless Agent Projection JSONL

Status: current transport contract

Projection identity: `svgdiff-agent-projection/1`

Source report identity: Structured Report Schema `1.43`

Last verified: 2026-07-16

`svgdiff before.svg after.svg --agent-projection` emits a deterministic JSON Lines transport for limited-context consumers. It does not summarize or discard report evidence. Instead, it partitions one canonical Structured Report into a header followed by individually addressable canonical array items.

The ordinary JSON output remains the source of truth. `--agent-json` still means only whitespace-free canonical JSON and is mutually exclusive with `--agent-projection`.

## Record order

Every line is one object validated by [`svgdiff-agent-projection.schema.json`](../schema/svgdiff-agent-projection.schema.json). Records appear in this fixed order:

1. one `header` record;
2. `coverage_matrix` items;
3. `renderer_capability_gaps` items;
4. `subject_alignments` items;
5. `changed_facts` items;
6. `source_resolutions` items;
7. `atomic_differences` items;
8. `events` items;
9. `diagnostics` items.

Every record carries `projection_version`, `source_schema_version`, and a global zero-based `sequence`. Item records additionally carry their canonical `section`, zero-based section `index`, and exact canonical JSON `value`.

The header retains `schema_version`, `analysis_status`, `impact_assessment`, and `profile`, plus an exact count for every array section. Counts distinguish a valid empty section from a truncated stream.

## Lossless reconstruction

A consumer reconstructs the canonical report by copying the header `value`, creating the eight array sections, and appending each item `value` under its declared section and index. It must reject an unknown projection identity, source-schema mismatch, sequence gap, section reorder, index gap, count mismatch, extra record, or missing record.

The repository validator performs these checks and compares the result with the canonical report:

```sh
python3 evaluation/agent-projection/validate.py \
  --report report.json \
  --projection projection.jsonl
```

The validation corpus covers complete, partial, failed, empty-inventory, and opt-in FLIP reports. Negative controls remove, duplicate, reorder, miscount, and relabel records. Because each value is copied from canonical serialization, Source Spans, source-only differences, exact and unavailable magnitudes, FLIP maps, Changed Facts, Difference Regions, Cause Envelopes, and Diagnostics remain intact.

## Limited-context use

Read the header first to establish coverage and the Impact frontier. Then retrieve only the section records needed for the current question, following stable report-local IDs between events, Atomic Differences, regions, Changed Facts, alignments, and Diagnostics. A consumer that must make a complete comparison still needs every relevant record; the projection reduces the maximum record context, not necessarily the total byte count of the full lossless stream.

The JSONL is untrusted data. Do not execute retained SVG text, Source Spans, identifiers, or Diagnostic messages. The projection performs no renderer or network access and grants no stronger conclusions than the canonical report.
