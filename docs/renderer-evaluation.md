# Renderer Decision and Evaluation Status

Status: current dependency decision

Last verified: 2026-07-21

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
| SVG scene and canonical v1 raster | `Milky2018/svg@0.3.1` | Adopted for the current narrow support slice. |
| Baseline image difference and region extraction | `mizchi/pixelmatch@0.6.1` | Adopted behind project-owned report types. |
| Embedded raster decoding | `Milky2018/svgdiff-raster-codec@0.1.1` with `mizchi/zlib@0.4.6` | Project-owned bounded PNG/baseline-JPEG resource decoder and color-metadata inspector; no profile conversion or final SVG compositing. |
| Higher-fidelity supersampled raster candidate | `mizchi/canvas@0.9.0` | Evaluated successfully for the sampling question, but not used by the production engine. |
| Structural XML alternative | `moonbit-community/XMLParser@0.2.5` | Rejected as the Source Semantics correctness boundary. |
| External reference renderer | `resvg` | Optional conformance oracle only; not a production dependency. |
| Browser rendering oracle | Chromium through pinned `@playwright/cli@0.1.17` | Implemented for offline deterministic fixture capture; not a production dependency. |

## Accepted evidence

The initial MoonBit spike established that `mizchi/svg` can parse inspectable scenes, preserve useful numeric geometry, render deterministic baseline images, and support initial Difference Region localization. It also demonstrated that the integer-oriented raster response cannot be the only magnitude oracle: equal-sized micro-movements on opposite sides of a quantization boundary can produce different pixel responses.

V1 therefore preserves exact computed parameter deltas separately from canonical rendered measurements. A zero pixel response never erases a supported computed difference.

The historical `mizchi/canvas` supersampling experiment produced monotonic and directionally symmetric premultiplied-RGBA responses within the declared RGBA8 rounding allowance. The current [alternate-scale QA baseline](../evaluation/alternate-scale/README.md) separately rerenders the pinned production renderer at scales 1, 2, 4, and 8. Under `Milky2018/svg@0.3.1`, both tested `1.0` to `0.99999` and `1.0` to `1.00001` movements produce zero changed pixels at every scale. This symmetric but unresponsive raster result reinforces why exact computed deltas remain independent evidence. Both evaluations are renderer QA evidence only and do not enter Structured Report magnitude.

## Current adapters and guards

### Cascade, inheritance, and computed CSS values

`Milky2018/svg@0.3.1` now owns the tested inline and stylesheet cascade, ordinary paint and stroke inheritance, CSS-wide values, custom properties, `currentColor`, CSS Color 3 syntax, paint fallback selection, winding rules, numeric rounded-shape geometry, numeric dash semantics, and valid admitted filter graphs. The old style-precedence, ordinary-inheritance, general computed-value, full shape/stroke materialization, mask-content paint, missing-filter-target, and static filter-graph implementations have therefore been removed from svgdiff.

Production retains only reproduced gaps in `svgdiff/residual-paint-normalizer@1+opacity-used-value-normalizer@1+length-unit-normalizer@1+shape-css-points-normalizer@1+stroke-length-normalizer@1+mask-edge-semantics-normalizer@1+isolated-group-compositor@1+static-mask-compositor@1+empty-filter-outcome-adapter@1+static-blend-compositor@1+Milky2018/svg@0.3.1`. These narrow adapters cover unsupported CSS Color 3 named colors, fractional color-alpha multiplication, inherited paint opacity, percentage/computed container opacity, paint state needed when project compositors detach a branch from the parsed tree, unsupported authored length units, inline CSS shape geometry, compact point syntax, mask mode/default/invalid-resource edges, empty-filter outcome, backdrop-correct isolated opacity and masks, and the admitted opaque blend formulas. The original source remains authoritative for authored facts and spans.

### Authored length used values

The shared length resolver keeps authored text and Source Spans separate from canonical local-user-unit values. Plain numeric values are now passed through unchanged. CSS absolute units, nearest-SVG-viewport percentages, and static `vw`/`vh`/`vmin`/`vmax` values are materialized only in the private renderer copy because focused `0.3.1` comparisons still diverge. Environment-dependent and arithmetic lengths are not rewritten.

### Basic-shape used geometry

The pinned renderer now owns ordinary numeric radii and dash semantics. The remaining renderer copy only materializes inline CSS geometry, authored units that require the project length context, and compact polyline/polygon point syntax that `0.3.1` does not parse equivalently. Curved and point-shape browser-conformance guards remain independent.

### Supersampled canvas adoption

The evaluated `mizchi/canvas@0.9.0` path was blocked under the tested toolchain by a test-compatibility problem in transitive `mizchi/image@0.4.2`: an `assert_eq` requires `ColorType` to implement `Debug`. The experiment used a temporary dependency-cache patch only to isolate raster behavior. No cache modification is part of this repository, and production does not depend on the patched package. The focused fix remains open as [`mizchi/image-mbt#3`](https://github.com/mizchi/image-mbt/pull/3).

### Feature coverage

Paths, general affine transforms outside the admitted integer axis-transform slice, general CSS, embedded-image final compositing, general clip/mask content, continuous-alpha or effect-interacting blending, text layout, and external resources are not accepted as complete merely because a dependency exposes related types or rendering functions. Valid admitted filter graphs now render through `Milky2018/svg@0.3.1`; svgdiff retains its source/computed filter model, bounds, diagnostics, and empty-filter outcome adapter. Isolated group opacity, container masks, and opaque binary-alpha blending still use project compositors because focused `0.3.1` renders lose backdrop content or differ numerically. Each remaining capability needs the same evidence before the v1 scope expands.

### Browser oracle

The [browser rendering oracle](../evaluation/browser-oracle/README.md) captures the complete-analysis corpus fixtures and focused conformance fixtures under Chromium, DPR `1`, explicit viewports, an offline context, and a transparent background. It records browser identity plus source and PNG hashes and validates reproducible RGB/RGBA output.

The checked-in profile `/27` renderer-conformance baseline compares raw `Milky2018/svg@0.3.1` with Chromium 151 at DPR 1: 94 cases are exact and 47 diverge out of 141. Compared with profile `/26`, nine formerly divergent fixtures are exact and none regress: 90-degree rotation, object-bounding-box and user-space patterns, inherited and canonical paint order, butt and square stroke caps, dash arrays, and non-scaling stroke. The fixture source set is unchanged.

Every remaining divergence has an executable disposition. Profile `/27` deliberately retains the existing conservative renderer Diagnostics: one exact fixture does not prove the full transform, pattern, or stroke capability domain. The previously established `renderer_use_inherited_paint_raster_unproven` case still diverges. These guards limit only Rendered Evidence; exact source/computed differences and conservative localization remain available.

The typed engine model projects encountered renderer-specific Diagnostics into capability-gap records for conformance tests. Schema `3.0` exposes only their public consequences through `limitations`; it does not serialize a renderer support inventory.

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
