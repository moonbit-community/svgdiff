# Renderer Decision and Evaluation Status

Status: current dependency decision

Last verified: 2026-07-14

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
| Higher-fidelity supersampled raster candidate | `mizchi/canvas@0.9.0` | Evaluated successfully for the sampling question, but not used by the production engine. |
| Structural XML alternative | `moonbit-community/XMLParser@0.2.5` | Rejected as the Source Semantics correctness boundary. |
| External reference renderer | `resvg` | Optional conformance oracle only; not a production dependency. |
| Browser rendering oracle | Chromium through pinned `@playwright/cli@0.1.17` | Implemented for offline deterministic fixture capture; not a production dependency. |

## Accepted evidence

The initial MoonBit spike established that `mizchi/svg` can parse inspectable scenes, preserve useful numeric geometry, render deterministic baseline images, and support initial Difference Region localization. It also demonstrated that the integer-oriented raster response cannot be the only magnitude oracle: equal-sized micro-movements on opposite sides of a quantization boundary can produce different pixel responses.

V1 therefore preserves exact computed parameter deltas separately from canonical rendered measurements. A zero pixel response never erases a supported computed difference.

The historical `mizchi/canvas` supersampling experiment produced monotonic and directionally symmetric premultiplied-RGBA responses within the declared RGBA8 rounding allowance. The current [alternate-scale QA baseline](../evaluation/alternate-scale/README.md) separately rerenders the pinned production renderer at scales 1, 2, 4, and 8 and makes its quantization and directional asymmetry reproducible. Both are renderer QA evidence only and do not enter Structured Report magnitude.

## Current blockers and guards

### Inline-style precedence

The pinned `mizchi/svg@0.2.1` renderer does not guarantee that inline `style` wins over a conflicting presentation attribute independently of XML attribute order. Until a released dependency fixes this, overlapping supported declarations emit `renderer_style_precedence_unresolved` and make computed and rendered coverage partial.

### Supersampled canvas adoption

The evaluated `mizchi/canvas@0.9.0` path was blocked under the tested toolchain by a test-compatibility problem in transitive `mizchi/image@0.4.2`: an `assert_eq` requires `ColorType` to implement `Debug`. The experiment used a temporary dependency-cache patch only to isolate raster behavior. No cache modification is part of this repository, and production does not depend on the patched package. The focused fix remains open as [`mizchi/image-mbt#3`](https://github.com/mizchi/image-mbt/pull/3).

### Feature coverage

Paths, transforms, general CSS, complete gradients, filters, masks, clipping, blending, text layout, nested viewports, and external resources are not accepted as complete merely because the dependency exposes related types or rendering functions. Each capability needs project-level conformance cases and explicit coverage behavior before the v1 scope expands.

### Browser oracle

The [browser rendering oracle](../evaluation/browser-oracle/README.md) captures the complete-analysis corpus fixtures and focused conformance fixtures under Chromium, DPR `1`, explicit viewports, an offline context, and a transparent background. It records browser identity plus source and PNG hashes and validates reproducible RGB/RGBA output.

The independent [renderer conformance comparison](../evaluation/renderer-conformance/README.md) normalizes browser and `mizchi/svg@0.2.1` pixels to premultiplied RGBA8. Its initial 15-case baseline records 10 exact cases and 5 divergences across geometry, paint, alpha, and compositing; the exploratory clipping case is exact. Baseline observations, accepted dispositions, and production guards are bound by `svgdiff-renderer-conformance-profile/1`, independently from both report schema `1.2` and the renderer package identity.

Every divergence now has an executable disposition. A browser-invisible `1.0` to `0.99999` position change becomes 16 full-channel changed pixels in the pinned renderer, so fractional geometry emits `renderer_fractional_geometry_unproven`. Gradient sampling differs by up to 11 premultiplied RGBA8 levels, so referenced gradients emit `renderer_gradient_raster_unproven`. Leaf opacity `0.5` becomes alpha `127` instead of Chromium's `128`, so it emits `renderer_fractional_opacity_unproven`. Group opacity remains guarded by `group_opacity_compositing_unsupported`. These guards limit only the evidence layers they name and retain numeric source/computed evidence plus the renderer observation where available.

Current reports project those encountered renderer-specific Diagnostics into `renderer_capability_gaps`. The structured records expose stable capability IDs and `guarded` or `unavailable` status without pretending to be a global renderer support inventory.

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
