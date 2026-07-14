# svgdiff for MoonBit

`Milky2018/svgdiff` compares two deterministic static SVG source strings and returns a typed Structured Report designed for programs and agents that need visual-semantic differences without inspecting pixels directly.

## Install

```sh
moon add Milky2018/svgdiff@0.3.3
```

The module currently supports the native backend only.

## Compare two SVG sources

```mbt check
///|
test "compare SVG source strings through the public package" {
  let before = "<svg width='16' height='16'><rect width='8' height='8' fill='red'/></svg>"
  let after = "<svg width='16' height='16'><rect width='8' height='8' fill='blue'/></svg>"
  let report = @svgdiff.compare(
    before,
    after,
    @svgdiff.ComparisonProfile::v1_default(),
  )
  assert_eq(report.schema_version, "1.4")
  assert_eq(report.analysis_status, "complete")
  assert_true(report.atomic_differences.length() > 0)
  assert_true(report.events.length() > 0)
}
```

Always inspect `analysis_status` and `diagnostics` before interpreting an empty difference list as equality. Unsupported SVG features reduce coverage or fail with explicit Diagnostics instead of being silently treated as visually equal.

## Public seam

The root package exposes:

- `compare` for unlimited comparison;
- `compare_with_control` for cooperative cancellation or elapsed-time budgets;
- `render_html_report` for a self-contained presentation of an existing report;
- typed report, difference, magnitude, region, provenance, coverage, and Diagnostic records;
- canonical formatted and compact JSON serialization through `StructuredReport` methods.

Module version `0.3.3` emits Structured Report Schema `1.4`. The current engine is intentionally limited to a documented deterministic static subset; paths, transforms, general CSS, filters, masks, fonts, images, scripting, animation, and `foreignObject` are not fully evaluated. Their presence must constrain report coverage rather than imply equality.

The module is licensed under Apache-2.0.
