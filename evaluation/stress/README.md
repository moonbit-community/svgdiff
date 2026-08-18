# Stress Cases

These fixtures exercise valid comparisons that are intentionally too expensive
or too large for the routine evaluation corpus. They are manual diagnostic
inputs, not CI gates or normative output snapshots.

## Banking domain cross-generator rewrite

[`cases/banking-domain-cross-generator`](cases/banking-domain-cross-generator)
contains two renderings of the same banking class diagram produced with very
different SVG structures. It is representative of a generator migration: the
visual subject matter remains recognizable while element types, grouping,
coordinates, styling, text layout, and document metadata all change.

Use this case to inspect:

- subject alignment across unrelated SVG trees;
- high-cardinality Atomic Difference and Visual Event reports;
- Cause Envelope and Diagnostic deduplication;
- report-size and memory-limit behavior; and
- report-inspector usability with hundreds of differences.

Run a deliberately coarse diagnostic comparison with:

```sh
moon run --target native modules/svgdiff/cmd/svgdiff -- \
  evaluation/stress/cases/banking-domain-cross-generator/before.svg \
  evaluation/stress/cases/banking-domain-cross-generator/after.svg \
  --width 16 --height 16 \
  --agent-json \
  --output /tmp/svgdiff-banking.json \
  --html /tmp/svgdiff-banking.html
```

The small observation viewport limits raster work but does not reduce source
semantic analysis. Do not add this case to a routine suite without defining
explicit time, memory, report-size, and interaction acceptance criteria.

### Diagnostic baseline

The 2026-08-18 native diagnostic run produced 891 Atomic Differences, 216
Visual Events, and 506 top-level Diagnostics. The `16 x 16` compact report was
692 KB; the `256 x 256` compact report was 1.09 MB with 1,801 Regions. These
figures are observations, not compatibility assertions.

The case originally exposed two scaling defects. Comparison-wide Cause
Envelopes repeated all 506 Diagnostic IDs for every Region, making the coarse
report 6.06 MB and causing the `256 x 256` report to exceed 32 MiB. The HTML
inspector also eagerly created all Event, Atomic Difference, evidence, and
Diagnostic nodes, while overlapping impact-map buttons intercepted each
other. The current implementation keeps the canonical Diagnostic inventory at
the report root, renders 24 Event summaries per outcome group, creates Event
details and Diagnostics on first disclosure, and clusters nearby impact points
into one button that cycles through every represented Event.
