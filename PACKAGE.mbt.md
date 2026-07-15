# svgdiff for MoonBit

`Milky2018/svgdiff` compares two deterministic static SVG source strings and returns a typed Structured Report designed for programs and agents that need visual-semantic differences without inspecting pixels directly.

## Install

```sh
moon add Milky2018/svgdiff@0.4.11
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
  assert_eq(report.schema_version, "1.17")
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

Module version `0.4.11` emits Structured Report Schema `1.17`. The current engine resolves presentation, inline, and matched static stylesheet declarations through one cascade model, including duplicates, specificity, source order, and `!important`; applies ordinary inheritance and CSS-wide defaulting without losing declaration ownership; resolves bounded custom-property substitution and `currentColor` dependencies; canonicalizes deterministic CSS Color 3 solid colors; computes clamped paint opacity; resolves complete static same-document linear and radial gradients with recursive templates and every fill/stroke consumer; and preserves exact authored length facts while resolving admitted shape, stroke, viewport, and marker units. The static selector scope covers type, universal, ID, class, attribute presence/equality, compound, list, and four structural combinators. External or dynamic gradients, non-sRGB interpolation, system palette selection, wide-gamut profiles, group compositing, cascade layers, complete CSS tokenization, unsupported selector grammar, active-stroke and marker rasterization, filters, masks, fonts, images, scripting, animation, and `foreignObject` remain guarded rather than implying equality.

The module is licensed under Apache-2.0.
