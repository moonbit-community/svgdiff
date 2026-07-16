# svgdiff for MoonBit

`Milky2018/svgdiff` compares two deterministic static SVG source strings and returns a typed Structured Report designed for programs and agents that need visual-semantic differences without inspecting pixels directly.

## Install

```sh
moon add Milky2018/svgdiff@0.5.16
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
  assert_eq(report.schema_version, "1.36")
  assert_eq(report.analysis_status, "complete")
  assert_true(report.atomic_differences.length() > 0)
  assert_true(report.events.length() > 0)
}
```

Always inspect `analysis_status` and `diagnostics` before interpreting an empty difference list as equality. Unsupported SVG features reduce coverage or fail with explicit Diagnostics instead of being silently treated as visually equal.

## Public seam

The root package exposes:

- `compare` for unlimited comparison;
- `compare_with_resources` for separate exact-match before/after PNG/JPEG bundles;
- `compare_with_control` for cooperative cancellation or elapsed-time budgets;
- `compare_with_control_and_resources` for explicit bundles plus cooperative controls;
- `audit_nonvisual_metadata` for an independent source-only audit of descriptive content and accessibility/custom-data attributes;
- `render_html_report` for a self-contained presentation of an existing report;
- typed report, difference, magnitude, region, provenance, coverage, Diagnostic, and source-audit records;
- canonical formatted and compact JSON serialization through `StructuredReport` and `SourceAuditReport` methods.

Module version `0.5.16` emits Structured Report Schema `1.36`. The current engine resolves presentation, inline, and matched static stylesheet declarations through one cascade model, including duplicates, specificity, source order, and `!important`; applies ordinary inheritance and CSS-wide defaulting without losing declaration ownership; resolves bounded custom-property substitution and `currentColor` dependencies; canonicalizes deterministic CSS Color 3 solid colors; computes clamped paint opacity; isolates static `svg`/`g`/`symbol`/`use` opacity on completed transparent layers; resolves one local static non-rounded rectangle clip with deterministic units, transforms, host application, consumer fan-out, and conservative effect bounds; resolves one local static alpha or sRGB-luminance mask with host mode, resource units, region defaults, deterministic transparent-black outcomes, isolated container application, continuous magnitudes, and per-side effect bounds; evaluates one local graph of direct static `feOffset` primitives on an explicit-ID untransformed basic-shape leaf with filter/primitive units, normative regions, SourceGraphic/SourceAlpha and named inputs, separate clipped RGBA intermediates, continuous magnitudes, fan-out, and conservative bounds; preserves every unsupported direct filter primitive as one position-aligned source-only subtree difference with exact span and affected consumers; implements all sixteen CSS blend keywords and `isolation:auto|isolate` for opaque integer rectangles with categorical differences, nearest-boundary backdrop prefixes, browser-matched formulas, and comparison-wide causal candidates; selects valid same-document paint servers or their deterministic SVG 2 fallbacks; compares inherited `paint-order`, `fill-rule`, and `clip-rule` by their active visual context; resolves complete static same-document linear and radial gradients plus patterns over the admitted basic-shape child slice with recursive templates and every fill/stroke consumer; preserves exact authored length facts while resolving admitted shape, stroke, viewport, and marker units; exposes exact local, CSS-pixel, viewport-relative, and entity-relative scalar parameter scales independently from outcome evidence; separates authored definitions from deterministic same-document use-instance placements; aligns rendered entities independently from source-structural entities and Visual Resources, gives intrinsic image content a resource alignment apart from placement, and attaches every resource Atomic Difference to its resource-role alignment; links admitted ancestry, instance-resolution, stacking, clipping, blending, and source-over changes to their computed or rendered consequences; builds one private typed dependency graph across every admitted or guarded resource family; and decodes bounded 8-bit non-interlaced PNG and single-scan baseline JPEG data URLs or exact-match caller bundles into intrinsic RGBA8 resource evidence with compact hashes, numeric pixel magnitudes, placement facts, and conservative bounds. The static selector scope covers type, universal, ID, class, attribute presence/equality, compound, list, and four structural combinators. External or context paint, dynamic paint servers, unsupported pattern child SVG, curved or multi-child clips, clip references on use instances, non-sRGB interpolation, system palette selection, wide-gamut profiles, cascade layers, complete CSS tokenization, unsupported selector grammar, active-stroke, marker, gradient, pattern, unsupported raster variants, embedded-image final rasterization, visual execution of filter primitives beyond the admitted `feOffset` graph, CSS filter functions, general mask content, CSS image or multi-layer masks, continuous-alpha/antialiased/container/effect-interacting blend paths, font-dependent text semantics, unbundled image loading, nested SVG images, scripting, animation, and `foreignObject` remain guarded rather than implying equality.

The module is licensed under Apache-2.0.
