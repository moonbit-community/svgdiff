# Renderer Decision and Evaluation Status

Status: current dependency decision

Last verified: 2026-07-20

This file records the current production decision and unresolved renderer blockers. Detailed experiment output is retained in [research](research/README.md), including the archived [Influence Provenance prototype verdict](research/influence-provenance-prototype.md).

Any dependency change must follow the synchronized [upgrade procedures](upgrade-procedures.md).

## Decision

Use pure-MoonBit community dependencies capability by capability behind the private engine seam. Do not replace a passing parser or scene layer merely because another renderer layer has a gap. Own a workspace module only when a reproducible required capability cannot be supplied by the dependency or a focused upstream extension.

Dependency-specific XML, scene, image, and raster types must not appear in the public `Milky2018/svgdiff` interface or Structured Report.

No renderer or browser dependency may execute SVG script as part of canonical comparison. The accepted [script execution boundary](script-execution-boundary.md) keeps future script-enabled captures external and separately identified; sandboxing alone is not renderer conformance or deterministic execution evidence.

## Current stack

| Layer | Dependency | Status |
| --- | --- | --- |
| Authored XML and Source Spans | `Milky2018/xml@0.4.0` | Adopted in production. |
| SVG scene and canonical v1 raster | `Milky2018/svg@0.3.0` | Adopted for the current narrow support slice. |
| Baseline image difference and region extraction | `mizchi/pixelmatch@0.6.1` | Adopted behind project-owned report types. |
| Embedded raster decoding | `Milky2018/svgdiff-raster-codec@0.1.1` with `mizchi/zlib@0.4.6` | Project-owned bounded PNG/baseline-JPEG resource decoder and color-metadata inspector; no profile conversion or final SVG compositing. |
| Higher-fidelity supersampled raster candidate | `mizchi/canvas@0.9.0` | Evaluated successfully for the sampling question, but not used by the production engine. |
| Structural XML alternative | `moonbit-community/XMLParser@0.2.5` | Rejected as the Source Semantics correctness boundary. |
| External reference renderer | `resvg` | Optional conformance oracle only; not a production dependency. |
| Browser rendering oracle | Chromium through pinned `@playwright/cli@0.1.17` | Implemented for offline deterministic fixture capture; not a production dependency. |

## Accepted evidence

The initial MoonBit spike established that `mizchi/svg` can parse inspectable scenes, preserve useful numeric geometry, render deterministic baseline images, and support initial Difference Region localization. It also demonstrated that the integer-oriented raster response cannot be the only magnitude oracle: equal-sized micro-movements on opposite sides of a quantization boundary can produce different pixel responses.

V1 therefore preserves exact computed parameter deltas separately from canonical rendered measurements. A zero pixel response never erases a supported computed difference.

The historical `mizchi/canvas` supersampling experiment produced monotonic and directionally symmetric premultiplied-RGBA responses within the declared RGBA8 rounding allowance. The current [alternate-scale QA baseline](../evaluation/alternate-scale/README.md) separately rerenders the pinned production renderer at scales 1, 2, 4, and 8. Under `Milky2018/svg@0.3.0`, both tested `1.0` to `0.99999` and `1.0` to `1.00001` movements produce zero changed pixels at every scale. This symmetric but unresponsive raster result reinforces why exact computed deltas remain independent evidence. Both evaluations are renderer QA evidence only and do not enter Structured Report magnitude.

## Current adapters and guards

### Cascade, inheritance, and computed CSS values

The pinned `Milky2018/svg@0.3.0` dependency substantially improves the tested style-precedence, inheritance, computed-color, alpha, group-opacity, mask, filter-offset, use-transform, and pattern-template cases relative to `mizchi/svg@0.2.1`. It still does not establish the complete admitted CSS, geometry, paint, resource, or compositing surface. Production therefore retains `svgdiff/style-precedence-normalizer@3+ordinary-inheritance-normalizer@1+css-computed-value-normalizer@3+css-color3-opacity-normalizer@1+length-used-value-normalizer@1+stroke-used-geometry-normalizer@1+basic-shape-used-geometry-normalizer@1+isolated-group-compositor@1+static-mask-normalizer@1+static-mask-compositor@1+static-filter-graph-compositor@1+static-blend-compositor@1+Milky2018/svg@0.3.0`: private renderer-input adapters materialize supported computed values and used geometry, while product compositors own the admitted isolated opacity, mask, filter, and blend slices. The original source remains untouched for source-level evidence. Invalid or unsupported syntax remains unchanged and emits the corresponding limitation Diagnostic.

The Chromium inherited-stylesheet, CSS-wide fill, custom-property/`currentColor`, HSL, color-alpha/paint-opacity, inherited paint-opacity, and clamped-opacity fixtures are byte-equivalent to their canonical companions. `Milky2018/svg@0.3.0` is exact on the first four authored forms, HSL, and clamped zero opacity. The two fractional color/paint-alpha cases still retain their independent one-level raster guard.

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

The independent [renderer conformance comparison](../evaluation/renderer-conformance/README.md) normalizes browser and raw `Milky2018/svg@0.3.0` pixels to premultiplied RGBA8. Its 141-case dependency baseline records 85 exact cases and 56 divergences: 18 more exact cases than the same Chromium corpus under `mizchi/svg@0.2.1`. Newly exact coverage includes the two subtle-geometry directions, leaf and group alpha, the tested cascade and computed-color forms, pattern-template inheritance, transformed use placement, admitted masks, all four filter-offset sources, and the tested isolation path. Gradients, most patterns, embedded PNG/JPEG composition, fractional alpha, polygon clip rules, curved/point/stroke/marker rasterization, skew, and authored-unit handling still diverge. The package exposes a host image resolver, but svgdiff has not yet connected its bounded resource bundle to that API, so final PNG/JPEG compositing remains unavailable.

Every divergence has an executable disposition. Four cases that were exact under `0.2.1` differ under `0.3.0`: a 90-degree rotation (6 pixels), a user-space pattern (12 pixels), canonical inherited paint order with active stroke (10 pixels), and a `use` instance inheriting `currentColor` through its referenced group (32 pixels). The pattern and stroke cases were already guarded. Profile `/26` narrows the transform-complete slice to non-axis-swapping integer transforms and adds `renderer_use_inherited_paint_raster_unproven` for the referenced-`currentColor` case. These guards limit only Rendered Evidence; exact source/computed differences and conservative localization remain available.

Current reports project those encountered renderer-specific Diagnostics into `renderer_capability_gaps`. The structured records expose stable capability IDs and `guarded` or `unavailable` status without pretending to be a global renderer support inventory.

The [M2 renderer and coverage gate](../evaluation/m2-renderer-coverage-gate/README.md) makes the complete safety chain explicit: reproducible observations, one disposition per divergence, encountered capability projection, centralized coverage proof, status composition, and unsupported-input false-equality properties. It does not promote this renderer to browser-equivalence authority.

### Platform font observations

The accepted [platform-native font boundary](platform-native-font-modes.md) extends the same oracle separation to CoreText, DirectWrite, browser text, and comparable system stacks. They are permanently excluded from canonical Font Execution Profiles. A future exact-bundle capture may be a named-target external conformance observation; an ambient system-font capture is exploratory and unreproducible. Neither can enter Structured Report equality, magnitude, coverage, Impact, regions, or causality directly.

### Color observations

The accepted [color-management profile boundary](color-management-profiles.md) applies the same separation to browser, OS, display-profile, and physical HDR/SDR output. Future canonical color execution must use a closed mathematical reference profile; host or display pixels remain independently identified `svgdiff-color-observation/1` evidence and cannot directly establish canonical equality, magnitude, completeness, or Impact.

### Future multi-renderer experiments

The accepted [multi-renderer boundary](multi-renderer-profiles.md) supports both same-target profile sensitivity and same-profile renderer conformance, but only as separate typed edges over independently identified cells. A target-plus-profile diagonal remains confounded, cross-environment browser output is a target observation rather than pure engine conformance, and no majority can replace the canonical report or a reviewed divergence disposition.

### Future foreign-content layout

The accepted [foreign-content boundary](foreign-object-layout-boundary.md) does not treat the pinned SVG renderer or Chromium oracle as a hidden HTML/CSS layout engine. General canonical XHTML requires a separately profiled deterministic host-language engine. The initial rectangular XHTML slice remains unimplemented and must prove its box and paint records plus outer SVG integration before any renderer disposition can expand coverage; browser output remains conformance or target-local observation evidence.

### Future generalized resource snapshots

The accepted [Resource Snapshot boundary](general-resource-snapshot-bundles.md) supplies closed external response inputs but cannot make an unsupported CSS, font, nested-SVG, image-compositing, or host-language path renderer-conformant. Each family still needs its own semantic and disposition evidence. The initial URL-resolved PNG/JPEG tracer reuses current intrinsic decoding only and does not expand final image compositing.

### Composed M5 authority boundary

The [M5 explicit non-goal coverage gate](../evaluation/m5-nongoal-coverage-gate/README.md) validates these renderer-adjacent decisions together with fonts, scripts, interaction, animation, and color. The [M5 adopted-profile environment gate](../evaluation/m5-adopted-profile-gate/README.md) independently proves that the current advanced adopted set is empty and requires implementation, concrete profile, and pinned environment manifests to agree before that set can grow. Passing either gate does not adopt a backend or profile. A browser, platform stack, physical display, or alternate renderer remains a separately identified observation; neither exact pixels nor a majority of observations can override one canonical report's renderer identity, coverage matrix, or Diagnostics.

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
- [Color-management profile boundary](color-management-profiles.md)
- [Multi-renderer and browser profile boundary](multi-renderer-profiles.md)
