# svgdiff for MoonBit

`Milky2018/svgdiff` compares two deterministic static SVG source strings and returns a typed Structured Report designed for programs and agents that need visual-semantic differences without inspecting pixels directly.

## Install

```sh
moon add Milky2018/svgdiff@0.7.0
```

The library supports wasm, wasm-gc, JavaScript, and native. Executable I/O is
kept in the native-only `cmd/svgdiff` CLI; browser hosts can build the separate
wasm-only `cmd/svgdiff_wasm` in-memory JSON entry.

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
  assert_eq(report.schema_version, "2.0")
  assert_eq(report.analysis_status, "complete")
  assert_true(report.atomic_differences.length() > 0)
  assert_true(report.events.length() > 0)
  assert_eq(report.impact_assessment.policy_id, "event_rendered_pareto/v1")
  assert_eq(
    report.impact_assessment.candidate_event_count,
    report.events.length(),
  )
}
```

The concise JSON does not serialize `impact_assessment`; changed-area and linear-RGBA measurements remain independent and are not a severity ranking.

Always inspect `analysis_status` and `diagnostics` before interpreting an empty difference list as equality. Unsupported SVG features reduce coverage or fail with explicit Diagnostics instead of being silently treated as visually equal.

## Public seam

The root package exposes:

- `compare` for unlimited comparison;
- `compare_with_resources` for separate exact-match before/after PNG/JPEG bundles;
- `compare_with_control` for cooperative cancellation or deterministic checkpoint budgets;
- `compare_with_control_and_resources` for explicit bundles plus cooperative controls;
- `audit_nonvisual_metadata` for an independent source-only audit of descriptive content and accessibility/custom-data attributes;
- `render_html_report` for a self-contained evidence inspector over an existing report, including exact Impact frontier groups, all Atomic Differences, non-null magnitudes, events, regions, conservative possible causes, Diagnostics, and sandboxed source previews;
- `render_markdown_summary` for a derived non-authoritative orientation over an existing report;
- `PerceptualBackground::parse_srgb`, `FlipViewingConditions::from_pixels_per_degree`, and `FlipErrorThreshold::from_value` for optional explicit perceptual inputs that leave current transparent-canvas evidence unchanged;
- typed report, difference, magnitude, region, provenance, coverage, Diagnostic, and source-audit records;
- canonical formatted and compact JSON serialization plus lossless Agent projection JSONL through `StructuredReport` methods, with independent source-audit JSON methods.

Module version `0.7.0` supports wasm, wasm-gc, JavaScript, and native library targets, replaces elapsed-time interruption with a deterministic checkpoint budget, and emits concise Structured Report Schema `2.0` and propagates private influence tokens through supported group surfaces, clip, mask, and filter consumers, blend/isolation backdrop prefixes, and stacking-region participants. Complete operation events union their direct conservative fan-out with before/after entity identities and every event sharing the exact Difference Region, so overlapping backdrop causes remain present while disjoint later subjects no longer force comparison-wide candidates. Partial, unsupported, and empty-candidate paths keep their wider fallbacks. It also builds a private subject-influence token index from every Changed Fact's conservative rendered-subject fan-out, retaining direct event tokens and every geometry, paint, resource, transform, viewport, use-instance, or structural token that may reach the event's before/after entity identities. It also localizes transform events through cumulative before/after conservative painted bounds and retains resolved same-document filter regions as conservative bounds for unsupported SVG shadow and other opaque primitive changes without claiming computed pixels or causal completeness. It keeps precise embedded raster color-profile and HDR coverage Diagnostics, deterministic derived Markdown summaries, and the complete interactive HTML evidence inspector. It records an optional explicit normalized opaque sRGB8 Perceptual Background plus optional bounded FLIP pixels-per-degree Viewing Conditions, and exposes event-local changed-pixel mean DeltaEOK and opt-in event-local LDR-FLIP maps after exact shared linear-sRGB background compositing without changing transparent-canvas raw evidence. The current engine resolves presentation, inline, and matched static stylesheet declarations through one cascade model, including duplicates, specificity, source order, and `!important`; applies ordinary inheritance and CSS-wide defaulting without losing declaration ownership; resolves bounded custom-property substitution and `currentColor` dependencies; canonicalizes deterministic CSS Color 3 solid colors; computes clamped paint opacity; isolates static `svg`/`g`/`symbol`/`use` opacity on completed transparent layers; resolves one local static non-rounded rectangle clip with deterministic units, transforms, host application, consumer fan-out, and conservative effect bounds; resolves one local static alpha or sRGB-luminance mask with host mode, resource units, region defaults, deterministic transparent-black outcomes, isolated container application, continuous magnitudes, and per-side effect bounds; evaluates one local graph of direct static `feOffset` primitives on an explicit-ID untransformed basic-shape leaf with filter/primitive units, normative regions, SourceGraphic/SourceAlpha and named inputs, separate clipped RGBA intermediates, continuous magnitudes, fan-out, and conservative bounds; preserves every unsupported direct filter primitive as one position-aligned source-only subtree difference with exact span, affected consumers, and resolved filter-region localization; implements all sixteen CSS blend keywords and `isolation:auto|isolate` for opaque integer rectangles with categorical differences, nearest-boundary backdrop prefixes, browser-matched formulas, and operation-participant causal candidates; selects valid same-document paint servers or their deterministic SVG 2 fallbacks; compares inherited `paint-order`, `fill-rule`, and `clip-rule` by their active visual context; resolves complete static same-document linear and radial gradients plus patterns over the admitted basic-shape child slice with recursive templates and every fill/stroke consumer; preserves exact authored length facts while resolving admitted shape, stroke, viewport, and marker units; exposes exact local, CSS-pixel, viewport-relative, and entity-relative scalar parameter scales independently from outcome evidence; retains cached symmetric painted-boundary displacement distributions and alpha-only coverage differences from one bounded isolated render pair for admitted two-sided entity changes; separates authored definitions from deterministic same-document use-instance placements; aligns rendered entities independently from source-structural entities and Visual Resources, gives intrinsic image content a resource alignment apart from placement, and attaches every resource Atomic Difference to its resource-role alignment; links admitted ancestry, instance-resolution, stacking, clipping, blending, and source-over changes to their computed or rendered consequences; builds one private typed dependency graph across every admitted or guarded resource family; and decodes bounded 8-bit non-interlaced PNG and single-scan baseline JPEG data URLs or exact-match caller bundles into intrinsic RGBA8 resource evidence with compact hashes, numeric pixel magnitudes, placement facts, and conservative bounds. The static selector scope covers type, universal, ID, class, attribute presence/equality, compound, list, and four structural combinators. External or context paint, dynamic paint servers, unsupported pattern child SVG, curved or multi-child clips, clip references on use instances, non-sRGB interpolation, system palette selection, wide-gamut conversion, cascade layers, complete CSS tokenization, unsupported selector grammar, active-stroke, marker, gradient, pattern, unsupported raster variants, embedded-image final rasterization, visual execution of filter primitives beyond the admitted `feOffset` graph, CSS filter functions, general mask content, CSS image or multi-layer masks, continuous-alpha/antialiased/container/effect-interacting blend paths, font-dependent text semantics, unbundled image loading, nested SVG images, scripting, animation, and `foreignObject` remain guarded rather than implying equality.

Computed LDR-FLIP evidence includes separate unquantized whole-canvas mean, selected-event mean, response p95, and response maximum statistics. An optional invariant-checked FLIP error threshold additionally produces strict-above pixel count and whole-canvas fraction; it is reporting input rather than a visibility or severity boundary.

The module is licensed under Apache-2.0.
