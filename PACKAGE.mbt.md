# svgdiff for MoonBit

`Milky2018/svgdiff` compares two deterministic static SVG source strings and returns a typed Structured Report designed for programs and agents that need visual-semantic differences without inspecting pixels directly.

## Install

```sh
moon add Milky2018/svgdiff@0.4.2
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
  assert_eq(report.schema_version, "1.8")
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

Module version `0.4.2` emits Structured Report Schema `1.8`. The current engine is intentionally limited to a documented deterministic static subset. Basic shapes resolve canonical unitless used geometry while retaining authored facts; paths have guarded exact segment differences; SVG transform lists and root or nested viewport mappings have exact source and cumulative affine evidence plus typed translation, rotation, signed-scale, skew, or singular residual effects. Stroke outlines, markers, non-unitless shape geometry, rounded-rectangle and polygon browser-conformant rasterization, general affine or non-integer viewport rasterization, resource transforms, precise transform-aware localization, physical viewport units, general CSS, filters, masks, fonts, images, scripting, animation, and `foreignObject` remain guarded rather than implying equality.

The module is licensed under Apache-2.0.
