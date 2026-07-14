# Renderer Decision and Evaluation Status

Status: current dependency decision

Last verified: 2026-07-14

This file records the current production decision and unresolved renderer blockers. Detailed experiment output is retained in [research](research/README.md) and the archived [influence-provenance prototype](../prototype/influence_provenance/README.md).

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

## Accepted evidence

The initial MoonBit spike established that `mizchi/svg` can parse inspectable scenes, preserve useful numeric geometry, render deterministic baseline images, and support initial Difference Region localization. It also demonstrated that the integer-oriented raster response cannot be the only magnitude oracle: equal-sized micro-movements on opposite sides of a quantization boundary can produce different pixel responses.

V1 therefore preserves exact computed parameter deltas separately from canonical rendered measurements. A zero pixel response never erases a supported computed difference.

The `mizchi/canvas` supersampling experiment produced monotonic and directionally symmetric premultiplied-RGBA responses within the declared RGBA8 rounding allowance. Those alternate-scale measurements are renderer QA evidence only and do not enter Structured Report magnitude.

## Current blockers and guards

### Inline-style precedence

The pinned `mizchi/svg@0.2.1` renderer does not guarantee that inline `style` wins over a conflicting presentation attribute independently of XML attribute order. Until a released dependency fixes this, overlapping supported declarations emit `renderer_style_precedence_unresolved` and make computed and rendered coverage partial.

### Supersampled canvas adoption

The evaluated `mizchi/canvas@0.9.0` path was blocked under the tested toolchain by a test-compatibility problem in transitive `mizchi/image@0.4.2`: an `assert_eq` requires `ColorType` to implement `Debug`. The experiment used a temporary dependency-cache patch only to isolate raster behavior. No cache modification is part of this repository, and production does not depend on the patched package.

### Feature coverage

Paths, transforms, general CSS, complete gradients, filters, masks, clipping, blending, text layout, nested viewports, and external resources are not accepted as complete merely because the dependency exposes related types or rendering functions. Each capability needs project-level conformance cases and explicit coverage behavior before the v1 scope expands.

## Escalation rule

For each missing capability:

1. reproduce the gap with a project acceptance fixture;
2. determine the smallest failing layer;
3. prefer a released dependency update or focused upstream extension;
4. add a conservative Diagnostic while the gap remains;
5. create a workspace-owned module only if the required behavior cannot be maintained economically upstream.

## Evidence trail

- [MoonBit SVG ecosystem survey](research/moonbit-svg-ecosystem.md)
- [SVG difference detection feasibility](research/detection-feasibility.md)
- [Milky XML 0.4.0 evaluation](research/milky-xml-evaluation.md)
- [XMLParser 0.2.5 evaluation](research/xmlparser-evaluation.md)
- [Historical influence-provenance prototype](../prototype/influence_provenance/README.md)
- [Current v1 support contract](v1-scope.md)
