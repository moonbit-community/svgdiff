# svgdiff

`svgdiff` compares two static SVGs by visual semantics. It reports what changed,
how large the rendered change is, where it occurred, and which authored facts
may have caused it. The JSON report is designed for programs and text-only
agents; the HTML report provides the same result for people.

Try it online at <https://milky2018.github.io/svgdiff/>.

## CLI

Run the WASIp1 command directly from Mooncakes:

```sh
moon runwasm Milky2018/svgdiff/cmd/svgdiff@0.10.0 before.svg after.svg
```

Run the repository version:

```sh
moon runwasm modules/svgdiff/cmd/svgdiff testdata/before.svg testdata/after.svg
```

Write compact JSON and a self-contained HTML report:

```sh
moon runwasm modules/svgdiff/cmd/svgdiff before.svg after.svg \
  --agent-json \
  --output report.json \
  --html report.html
```

The same command package supports native and WASIp1 targets. Use `-` for at
most one input to read it from stdin. Run with `--help` for viewport, resource,
perceptual, and computation-budget options.

Exit status is `0` when a complete or partial report was produced, `1` when
analysis failed or its computation budget was exhausted, and `2` for invalid
arguments or file I/O errors.

## Library

```sh
moon add Milky2018/svgdiff@0.10.0
```

```mbt check
///|
test "compare SVG source strings" {
  let before = "<svg width='16' height='16'><rect width='8' height='8' fill='red'/></svg>"
  let after = "<svg width='16' height='16'><rect width='8' height='8' fill='blue'/></svg>"
  let report = @svgdiff.compare(
    before,
    after,
    @svgdiff.ComparisonProfile::v1_default(),
  )
  assert_eq(report.schema_version, "5.0")
  assert_eq(report.analysis_status, "complete")
  assert_true(report.atomic_differences.length() > 0)
}
```

Read `analysis_status` and `limitations` before interpreting an empty difference
set as equality. Magnitudes remain multidimensional: changed pixels, linear RGBA
RMSE, geometry, coverage, color, and optional FLIP evidence are not collapsed
into one invented severity score.

The serialized contract is [schema 5.0](schema/svgdiff-report.schema.json).

## Repository

The workspace contains two independently published modules:

- `modules/svgdiff`: comparison engine, CLI, browser ABI, JSON, and HTML.
- `modules/raster_codec`: PNG/JPEG decoding used by explicit image resources.

The static site lives in `web`. Product behavior is tested beside the MoonBit
code; the repository intentionally has no separate evaluation framework.

```sh
moon info
moon fmt
moon check --target all --warn-list +73
moon test --target all
sh scripts/test-cli.sh
sh scripts/test-wasm.sh
sh scripts/build-pages.sh
```

Licensed under Apache-2.0.
