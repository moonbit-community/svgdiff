# Renderer Decision and Evaluation Status

Status: current dependency decision

Last verified: 2026-07-16

This file records the current production decision and unresolved renderer blockers. Detailed experiment output is retained in [research](research/README.md), including the archived [Influence Provenance prototype verdict](research/influence-provenance-prototype.md).

Any dependency change must follow the synchronized [upgrade procedures](upgrade-procedures.md).

## Decision

Use pure-MoonBit community dependencies capability by capability behind the private engine seam. Do not replace a passing parser or scene layer merely because another renderer layer has a gap. Own a workspace module only when a reproducible required capability cannot be supplied by the dependency or a focused upstream extension.

Dependency-specific XML, scene, image, and raster types must not appear in the public `Milky2018/svgdiff` interface or Structured Report.

## Current stack

| Layer | Dependency | Status |
| --- | --- | --- |
| Authored XML and Source Spans | `Milky2018/xml@0.4.0` | Adopted in production. |
| SVG scene and canonical v1 raster | `mizchi/svg@0.2.1` | Adopted for the current narrow support slice. |
| Baseline image difference and region extraction | `mizchi/pixelmatch@0.6.1` | Adopted behind project-owned report types. |
| Embedded raster decoding | `Milky2018/svgdiff-raster-codec@0.1.1` with `mizchi/zlib@0.4.6` | Project-owned bounded PNG/baseline-JPEG resource decoder and color-metadata inspector; no profile conversion or final SVG compositing. |
| Higher-fidelity supersampled raster candidate | `mizchi/canvas@0.9.0` | Evaluated successfully for the sampling question, but not used by the production engine. |
| Structural XML alternative | `moonbit-community/XMLParser@0.2.5` | Rejected as the Source Semantics correctness boundary. |
| External reference renderer | `resvg` | Optional conformance oracle only; not a production dependency. |
| Browser rendering oracle | Chromium through pinned `@playwright/cli@0.1.17` | Implemented for offline deterministic fixture capture; not a production dependency. |

## Accepted evidence

The initial MoonBit spike established that `mizchi/svg` can parse inspectable scenes, preserve useful numeric geometry, render deterministic baseline images, and support initial Difference Region localization. It also demonstrated that the integer-oriented raster response cannot be the only magnitude oracle: equal-sized micro-movements on opposite sides of a quantization boundary can produce different pixel responses.

V1 therefore preserves exact computed parameter deltas separately from canonical rendered measurements. A zero pixel response never erases a supported computed difference.

The historical `mizchi/canvas` supersampling experiment produced monotonic and directionally symmetric premultiplied-RGBA responses within the declared RGBA8 rounding allowance. The current [alternate-scale QA baseline](../evaluation/alternate-scale/README.md) separately rerenders the pinned production renderer at scales 1, 2, 4, and 8 and makes its quantization and directional asymmetry reproducible. Both are renderer QA evidence only and do not enter Structured Report magnitude.

## Current adapters and guards

### Cascade, inheritance, and computed CSS values

The pinned `mizchi/svg@0.2.1` dependency applies conflicting presentation attributes and inline declarations in XML attribute order, does not honor inline importance, inherits only a subset of the admitted visual-property surface, does not resolve the admitted CSS-wide/custom-property, paint-rule, or complete CSS Color 3 slice, and does not establish isolated group-opacity, container-mask, filter-graph, or CSS blend execution. Production therefore uses `svgdiff/style-precedence-normalizer@3+ordinary-inheritance-normalizer@1+css-computed-value-normalizer@3+css-color3-opacity-normalizer@1+length-used-value-normalizer@1+stroke-used-geometry-normalizer@1+basic-shape-used-geometry-normalizer@1+isolated-group-compositor@1+static-mask-normalizer@1+static-mask-compositor@1+static-filter-graph-compositor@1+static-blend-compositor@1+mizchi/svg@0.2.1`: private renderer-input adapters materialize cascade winners, ordinary inheritance, CSS-wide defaulting, bounded custom-property substitution, `currentColor`, expanded paint order, winding rules, canonical deterministic sRGB channels, multiplied color/paint alpha, and admitted mask values before canonicalizing length, stroke, and basic-shape used values; product compositors then isolate admitted opacity and mask layers, execute admitted filter graphs, and apply browser-matched opaque blend/isolation semantics before source-over composition. The original source remains untouched for source-level evidence. Invalid or unsupported syntax remains unchanged and emits the corresponding limitation Diagnostic. Upstream PR [`mizchi/svg#4`](https://github.com/mizchi/svg/pull/4) remains useful but is no longer a product blocker.

The Chromium inherited-stylesheet, CSS-wide fill, custom-property/`currentColor`, HSL, color-alpha/paint-opacity, inherited paint-opacity, and clamped-opacity fixtures are byte-equivalent to their canonical companions. Raw `mizchi/svg` diverges on the first six authored forms; production proves deterministic computed equivalence through its private normalizers. Fractional alpha retains the independent one-level raster guard even after normalization, while HSL and clamped zero opacity are exact.

### Authored length used values

The shared length resolver keeps authored text and Source Spans separate from canonical local-user-unit values. Unitless and `px`, CSS absolute units, nearest-SVG-viewport percentages, and static `vw`/`vh`/`vmin`/`vmax` values are materialized only in the private renderer copy. Chromium canonical-pair fixtures prove equivalent absolute, percentage, viewport-relative, and nested-viewport inputs; the disposition validator independently requires complete CLI computed equivalence and zero changed pixels. Environment-dependent and arithmetic lengths are not rewritten.

### Basic-shape used geometry

The pinned renderer does not consistently apply omitted paired radii and SVG half-dimension clamping. Production therefore resolves the current unitless basic-shape slice before rendering and materializes canonical values only in the private renderer copy. Engine tests prove that implicit/clamped and explicit used radii render identically after this adapter. The raw renderer still differs from Chromium on circle, ellipse, and rounded-rectangle antialiasing and on filled polyline/polygon boundaries, so those inputs emit `renderer_curved_shape_raster_unproven` or `renderer_point_shape_raster_unproven` rather than receiving false complete Rendered Evidence.

### Supersampled canvas adoption

The evaluated `mizchi/canvas@0.9.0` path was blocked under the tested toolchain by a test-compatibility problem in transitive `mizchi/image@0.4.2`: an `assert_eq` requires `ColorType` to implement `Debug`. The experiment used a temporary dependency-cache patch only to isolate raster behavior. No cache modification is part of this repository, and production does not depend on the patched package. The focused fix remains open as [`mizchi/image-mbt#3`](https://github.com/mizchi/image-mbt/pull/3).

### Feature coverage

Paths, general affine transforms outside the admitted integer axis-transform slice, general CSS, gradient or pattern rasterization, embedded-image final compositing, filter primitives beyond direct static `feOffset`, general clip/mask content, continuous-alpha or effect-interacting blending, text layout, and external resources are not accepted as complete merely because a dependency exposes related types or rendering functions. Static linear/radial gradient, admitted static pattern, bounded PNG/JPEG resource semantics, local rectangular clip resolution/bounds, the bounded static alpha/luminance mask slice, the bounded static `feOffset` graph, and opaque binary-alpha blend/isolation semantics are project-owned; unavailable rendered layers remain guarded. Viewport mapping, rectangular clip rasterization, admitted mask transfer, filter execution, and blend execution are accepted only through their project-level semantic and conformance tests. Each remaining capability needs the same evidence before the v1 scope expands.

### Browser oracle

The [browser rendering oracle](../evaluation/browser-oracle/README.md) captures the complete-analysis corpus fixtures and focused conformance fixtures under Chromium, DPR `1`, explicit viewports, an offline context, and a transparent background. It records browser identity plus source and PNG hashes and validates reproducible RGB/RGBA output.

The independent [renderer conformance comparison](../evaluation/renderer-conformance/README.md) normalizes browser and raw `mizchi/svg@0.2.1` pixels to premultiplied RGBA8. Its 141-case dependency baseline records 67 exact cases and 74 divergences across geometry, paint, alpha, clipping, compositing, viewport mapping, stroke geometry, markers, authored units, cascade precedence, inheritance, computed CSS values, solid-color syntax, paint opacity, paint fallback selection, paint order, structural stacking, winding rules, gradients, patterns, embedded rasters, use instances, static filter offsets, and CSS blending/isolation. Six admitted mask fixtures cover alpha, luminance, object-bounding-box coordinates, host mode override, transforms, and isolated container application; five are raw exact and the container case differs by one premultiplied channel level. Four admitted filtered sources cover user-space offsets, object-bounding-box primitive units, named chains, and SourceAlpha; raw rendering diverges by 32 to 44 pixels, while all four unfiltered canonical companions are exact and production reports zero changed pixels against those companions. Eight admitted blend fixtures cover all formulas, ordinary-group backdrop exposure, explicit isolation, and transparent-backdrop invariance; two raw sources diverge while six paths are exact, and production reports zero changed pixels against both canonical companions. The four admitted rectangle clip fixtures are exact for leaf, container, object-bounding-box, and deterministic transformed cases; inherited polygon clip-rule fixtures remain guarded by `clip_path_content_unsupported`. The PNG and JPEG fixtures each change 144 browser pixels while the pinned renderer leaves them absent, establishing `renderer_embedded_raster_unavailable`. Both structural stacking orders are exact. Six use fixtures show exact repeated placement, host inheritance, symbol viewport mapping, and untransformed nesting; direct and nested transform-plus-translation cases retain `renderer_use_transform_raster_unproven`. Six focused gradient fixtures cover linear/radial geometry, both coordinate-unit modes, transforms, templates, and multi-stop opacity; all six diverge. Six focused pattern fixtures cover tile/content units, transforms, viewBox mapping, and templates; one is exact and five diverge. The missing-server fallback-color and no-fallback fixtures plus their canonical companions are all exact. Inherited fill-rule source and leaf forms are exact; inherited paint order becomes exact after expansion to the canonical leaf form, while active stroke rasterization remains guarded. Four unit-bearing, four cascade, one inherited-stylesheet, one CSS-wide, one custom-property/`currentColor`, and four color/opacity inputs have Chromium canonical companions. HSL receives an executable production-normalizer disposition; group opacity, mask composition, all four admitted filter paths, and both raw blend divergences receive executable product-compositor dispositions while the raw dependency divergences remain preserved; fractional color/paint-alpha pairs retain their renderer guard because even the canonical companion differs by one premultiplied RGBA8 level. Baseline observations, accepted dispositions, production guards, eight normalizer stages, and four project-owned compositors are bound by `svgdiff-renderer-conformance-profile/25`, independently from report schema `1.44` and the production renderer identity.

Every divergence now has an executable disposition. A browser-invisible `1.0` to `0.99999` position change becomes 16 full-channel changed pixels in the pinned renderer, so fractional geometry emits `renderer_fractional_geometry_unproven`. The six focused gradient fixtures change 87 to 196 pixels with maximum channel deltas from 105 to 255 (the multi-stop opacity case changes 144 pixels with maximum delta 237), so referenced gradients emit `renderer_gradient_raster_unproven`. Five pattern fixtures change 32 to 96 pixels with maximum channel deltas from 89 to 255, so referenced patterns emit `renderer_pattern_raster_unproven`; the exact user-space fixture does not justify the remaining modes. Leaf opacity `0.5` becomes alpha `127` instead of Chromium's `128`, so it emits `renderer_fractional_opacity_unproven`. Skew fixtures differ on 26 pixels, so general affine transforms outside the integer axis slice emit `renderer_transform_raster_unproven`. Curved shapes differ on 28 to 40 pixels and filled point shapes on 36 to 84, so their dedicated renderer guards limit those raster claims. Marker fixtures differ on 12 to 40 pixels and emit `renderer_marker_raster_unproven`. The raw mask-container fixture differs by one premultiplied channel level and is assigned to `static-mask-compositor`. The four raw filter sources diverge by 32 to 44 pixels and are assigned to `static-filter-graph-compositor`; their canonical companions and production equivalence checks prove the admitted paths. The raw blend grid differs on 240 pixels and the ordinary-group source differs on 32 pixels; both are assigned to `static-blend-compositor`, whose W3C formulas, explicit isolation, and product canonical comparisons prove the admitted paths. The raw group-opacity fixture differs on 164 pixels, while the product compositor's exact RGBA tests establish browser-consistent alpha 128, top-child overlap, nesting, backdrop source-over, transforms, sibling order, and symbol instances. Remaining guards limit only the evidence layers they name and retain numeric source/computed evidence plus the renderer observation where available.

Current reports project those encountered renderer-specific Diagnostics into `renderer_capability_gaps`. The structured records expose stable capability IDs and `guarded` or `unavailable` status without pretending to be a global renderer support inventory.

### Platform font observations

The accepted [platform-native font boundary](platform-native-font-modes.md) extends the same oracle separation to CoreText, DirectWrite, browser text, and comparable system stacks. They are permanently excluded from canonical Font Execution Profiles. A future exact-bundle capture may be a named-target external conformance observation; an ambient system-font capture is exploratory and unreproducible. Neither can enter Structured Report equality, magnitude, coverage, Impact, regions, or causality directly.

## Escalation rule

The detailed and quantitative admission policy is the [Renderer Upstream and Ownership Gate](renderer-ownership-gate.md). For each missing capability:

1. reproduce the gap with a project acceptance fixture;
2. determine the smallest failing layer;
3. prefer a released dependency update or focused upstream extension;
4. add a conservative Diagnostic while the gap remains;
5. create a workspace-owned module only if the required behavior cannot be maintained economically upstream.

One minimized dependency-owned failure is enough for a focused upstream patch. Ownership requires an active-milestone blocker, a named smallest layer, evidence that a released upstream solution is not viable, an explicit maintenance plan, and at least three independent cases satisfying the breadth or project-specific-control trigger. A global conformance percentage and pixel magnitude are not ownership criteria.

## Evidence trail

- [MoonBit SVG ecosystem survey](research/moonbit-svg-ecosystem.md)
- [SVG difference detection feasibility](research/detection-feasibility.md)
- [Milky XML 0.4.0 evaluation](research/milky-xml-evaluation.md)
- [XMLParser 0.2.5 evaluation](research/xmlparser-evaluation.md)
- [Historical Influence Provenance prototype verdict](research/influence-provenance-prototype.md)
- [Current v1 support contract](v1-scope.md)
- [Browser rendering oracle](../evaluation/browser-oracle/README.md)
- [Pinned renderer conformance baseline](../evaluation/renderer-conformance/README.md)
- [Alternate-scale renderer QA baseline](../evaluation/alternate-scale/README.md)
- [Dependency, security, and upstream status](dependency-security.md)
- [Platform-native font rendering boundary](platform-native-font-modes.md)
