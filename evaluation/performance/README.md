# Performance Benchmarks and Budgets

Status: active native release stage and end-to-end suites

Suite versions: `svgdiff-stage-benchmark-suite/1` and `svgdiff-performance-budgets/1`

Last verified: 2026-07-14

The stage suite measures six production pipeline stages independently: parse and admission, subject alignment, raster rendering, pixel-region extraction, Cause Envelope provenance, and Structured Report serialization. It is a performance diagnostic suite. The end-to-end suite separately enforces wall-time and peak-resident-memory budgets on representative small, medium, and large native release CLI comparisons. The `scripts/run-agent-benchmark.sh` command evaluates report and text-only Agent correctness; its scores are not timing measurements.

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

The stage suite compares two `128 x 128` SVGs containing the same 64 ID-aligned rectangles on a spaced grid. Every rectangle changes from red to blue. The workload creates nontrivial alignment, 64 disconnected pixel regions, per-region provenance, and a report large enough to exercise both JSON serializers.

This one workload exists to prove that stage boundaries are measurable. It is not the representative size taxonomy and establishes no latency or memory budget.

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

`region_extraction` measures connected-component extraction once. It does not include the later per-event region attachment and local rendered-magnitude calculation in `finish_report`; use end-to-end scaling to detect regressions in that report-assembly work.

## Representative end-to-end budgets

Run the budget gate with:

```sh
sh scripts/run-performance-budgets.sh --output /tmp/svgdiff-performance-budgets.json
```

The versioned [`budgets.v1.json`](budgets.v1.json) manifest generates deterministic pairs containing supported, ID-aligned rectangles whose fill changes from red to blue. Generation happens before measurement. Every sample launches the production native release CLI with compact Agent JSON in a fresh child of a fresh Python probe, requires `analysis_status: complete`, and verifies the exact expected Atomic Difference count.

| Size | Subjects | Viewport | Median wall-time ceiling | Peak RSS ceiling |
| --- | ---: | ---: | ---: | ---: |
| Small | 8 | `32 x 16` | 500 ms | 64 MiB |
| Medium | 64 | `128 x 128` | 2,000 ms | 128 MiB |
| Large | 256 | `256 x 256` | 10,000 ms | 256 MiB |

Each workload runs three isolated samples. The gate uses median wall time to reduce isolated scheduling noise and the maximum observed peak RSS to retain the strongest memory observation. Wall time includes CLI startup, input reads, comparison, compact JSON serialization, and captured stdout. It excludes workload generation and harness setup. Peak RSS comes from `getrusage(RUSAGE_CHILDREN).ru_maxrss` and is normalized from bytes on macOS or KiB on Linux to MiB. The harness therefore supports macOS and Linux; it does not claim portable RSS semantics on other operating systems.

Run `sh scripts/test-performance-budgets.sh` for the positive gate plus synthetic independent time-failure, memory-failure, and malformed-sample controls. The JSON artifact records raw samples, aggregation, each metric decision, operating system, architecture, Python version, and product version.

These values are deliberately generous portability and regression ceilings for the named workloads. They are not optimization targets, latency guarantees for arbitrary SVG, hard per-request enforcement, or evidence that hostile inputs are safe. Change a ceiling only with a recorded workload or environment reason and reviewed measurement evidence.

## Measured optimization record

ISS-083 identified per-event local rendered-magnitude calculation as the scaling hot path for the grid workloads. Each event commonly owns one pixel region, but the earlier implementation scanned the complete viewport once per event. The optimized path scans only that region's rectangular bounds when exactly one region is attached. It retains the full-image union scan for zero or multiple regions and retains the same changed-pixel test and error formulas in all cases.

The following native release results were collected on 2026-07-14 on the same Darwin arm64 host and toolchain. Both the committed `b83dd7a` baseline and optimized tree ran the budget harness three times, with three isolated samples per workload per run. Each table value is the mean of the three run medians.

| Workload | Baseline | Optimized | Change |
| --- | ---: | ---: | ---: |
| Small | 6.259 ms | 6.245 ms | within noise |
| Medium | 35.261 ms | 27.722 ms | 21.4% lower |
| Large | 276.076 ms | 148.545 ms | 46.2% lower |

The optimization does not change a budget, matching policy, report order, or metric definition. The single-region ring regression keeps an equal pixel inside the rectangular bounds to prove the restricted scan still excludes unchanged pixels; the deterministic report and canonical example gates protect serialized output.

## Interpretation boundaries

Timing varies with CPU, operating system, load, compiler, and MoonBit toolchain. Stage results require finite, positive, internally consistent statistics but intentionally have no machine-specific pass/fail threshold. Their measurements overlap and must not be added. End-to-end results have explicit ceilings for named workloads and record the executing environment so regressions can be interpreted without mistaking them for universal product guarantees. Agent-quality scores remain a third independent evaluation axis.
