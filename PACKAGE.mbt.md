# svgdiff for MoonBit

`Milky2018/svgdiff` compares two deterministic static SVG source strings and returns a typed Structured Report designed for programs and agents that need visual-semantic differences without inspecting pixels directly.

## Install

```sh
moon add Milky2018/svgdiff@0.5.3
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
  assert_eq(report.schema_version, "1.23")
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

Module version `0.5.3` emits Structured Report Schema `1.23`. The current engine resolves presentation, inline, and matched static stylesheet declarations through one cascade model, including duplicates, specificity, source order, and `!important`; applies ordinary inheritance and CSS-wide defaulting without losing declaration ownership; resolves bounded custom-property substitution and `currentColor` dependencies; canonicalizes deterministic CSS Color 3 solid colors; computes clamped paint opacity; selects valid same-document paint servers or their deterministic SVG 2 fallbacks; compares inherited `paint-order`, `fill-rule`, and `clip-rule` by their active visual context; resolves complete static same-document linear and radial gradients plus patterns over the admitted basic-shape child slice with recursive templates and every fill/stroke consumer; preserves exact authored length facts while resolving admitted shape, stroke, viewport, and marker units; separates authored definitions from deterministic same-document use-instance placements; links admitted ancestry, instance-resolution, and stacking changes to their computed or rendered consequences; builds one private typed dependency graph across every admitted or guarded resource family; and decodes bounded 8-bit non-interlaced PNG and single-scan baseline JPEG data URLs into intrinsic RGBA8 resource evidence with compact hashes, numeric pixel magnitudes, placement facts, and conservative bounds. The static selector scope covers type, universal, ID, class, attribute presence/equality, compound, list, and four structural combinators. External or context paint, dynamic paint servers, unsupported pattern child SVG, complete clip-path evaluation, non-sRGB interpolation, system palette selection, wide-gamut profiles, group compositing, cascade layers, complete CSS tokenization, unsupported selector grammar, active-stroke, marker, gradient, pattern, unsupported raster variants, and embedded-image final rasterization, filters, masks, fonts, external image loading, nested SVG images, scripting, animation, and `foreignObject` remain guarded rather than implying equality.

The module is licensed under Apache-2.0.
