# Pipeline Stage Performance Benchmarks

Status: active native release microbenchmark suite

Suite version: `svgdiff-stage-benchmark-suite/1`

Last verified: 2026-07-14

This suite measures six production pipeline stages independently: parse and admission, subject alignment, raster rendering, pixel-region extraction, Cause Envelope provenance, and Structured Report serialization. It is a performance diagnostic suite. The separate `scripts/run-agent-benchmark.sh` command evaluates report and text-only Agent correctness; its scores are not timing measurements.

Run the standard MoonBit benchmark table with:

```sh
moon bench --target native --release engine
```

Write the same summaries as a validated machine-readable artifact with:

```sh
sh scripts/run-stage-benchmarks.sh --output /tmp/svgdiff-stage-benchmarks.json
```

The output uses `svgdiff-stage-benchmark-results/1`, records microseconds, native/release identity, fixed workload metadata, and MoonBit summary statistics for every stage. Run `sh scripts/test-stage-benchmarks.sh` for the structural gate and missing, duplicate, nonpositive, and malformed-statistic negative controls.

## Fixed diagnostic workload

The current suite compares two `128 x 128` SVGs containing the same 64 ID-aligned rectangles on a spaced grid. Every rectangle changes from red to blue. The workload creates nontrivial alignment, 64 disconnected pixel regions, per-region provenance, and a report large enough to exercise both JSON serializers.

This one workload exists to prove that stage boundaries are measurable. It is not a representative size taxonomy and establishes no latency or memory budget. Small, medium, and large workloads belong to the next roadmap item.

## Stage boundaries

The authoritative machine-readable descriptions live in [`suite.v1.json`](suite.v1.json). Every prerequisite listed below is constructed before the timed closure.

| Stage ID | Timed production work | Excluded setup |
| --- | --- | --- |
| `parse_admission` | Fixed resource admission, analyzer preflight, and pinned SVG document parsing for both inputs | Source, profile, and limit construction |
| `alignment` | Subject matching from pre-extracted inventories | XML parsing and subject extraction |
| `rendering` | Two pinned-renderer image productions from parsed documents | SVG parsing |
| `region_extraction` | Connected pixel-difference region extraction | Parsing and rendering |
| `provenance` | Cause Envelope attachment to a completed report | Comparison, regions, and report assembly |
| `serialization` | Compact and indented Structured Report JSON serialization | Comparison and report assembly |

The measurements overlap by design. For example, `parse_admission` includes parsing needed by production admission, while alignment setup also parses subjects outside its timer. Likewise, the completed report used by provenance and serialization already passed through earlier stages. Do not add the six means or medians and label the result end-to-end latency.

## Interpretation boundary

Timing varies with CPU, operating system, load, compiler, and MoonBit toolchain. The validator requires finite, positive, internally consistent statistics but has no machine-specific pass/fail threshold. Performance and memory budgets require named representative workloads and an explicit baseline environment; they remain unchecked roadmap work.
