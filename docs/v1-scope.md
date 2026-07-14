# Current V1 Support Contract

Status: implementation-aligned contract

Last verified: 2026-07-14

This document states what schema `1.4` can analyze today. It deliberately separates implemented support from accepted future design. If this file disagrees with an ADR or research note about current capability, this file wins; if it disagrees with the public types or JSON Schema about serialization, the code and Schema win.

The executable trace from each feature to its Diagnostic and tests lives in the [feature coverage matrix](feature-coverage.md).

## Correctness claim

V1 compares two well-formed deterministic static SVG source strings under one explicit common viewport and a pinned rendering profile. A `complete` report means every encountered visual semantic is covered by the implemented analyzer slice. It does not claim browser equivalence, cross-renderer equivalence, or equivalence under another viewport or environment.

When an input leaves the supported slice, the engine emits Diagnostics and changes `analysis_status` to `partial` or `failed`. Supported source-level differences may still be reported even when computed or rendered evidence is unavailable. Crossing a fixed [comparison resource limit](resource-limits.md), forming an accepted local-reference cycle, or exceeding the conservative transitive `<use>` bound is a failed admission result and never returns a truncated difference inventory.

## Implemented profile

| Condition | Current behavior |
| --- | --- |
| Viewport | One explicit width and height shared by both inputs. CLI default: `16 x 16`. |
| DPR | Fixed to `1.0`. |
| Color interpretation | sRGB for the supported color slice. |
| Raster arithmetic | Canonical numeric error uses linear-sRGB premultiplied RGBA; renderer-native RGBA8 RMSE is also retained. |
| Renderer identity | Pinned as `svgdiff/style-precedence-normalizer@1+mizchi/svg@0.2.1`. |
| Renderer conformance profile | Pinned independently as `svgdiff-renderer-conformance-profile/2`. |
| Background | Transparent canvas only; no perceptual background option. |
| Resources | No caller-supplied resource bundle and no implicit network fetching. |
| Reference admission | Accepted local fragment edges are checked for cycles and bounded transitive `<use>` expansion before renderer parsing. |
| Fonts | No deterministic font environment or font-dependent completeness claim. |

The root library seam canonicalizes DPR, color interpretation, raster representation, renderer identity, and renderer conformance profile. It currently uses only the caller-supplied viewport dimensions from `ComparisonProfile`.

## Implemented complete-analysis slice

The following capabilities can participate in a `complete` report when no unsupported semantics are encountered:

- strict XML well-formedness and namespace-aware authored Source Spans through `Milky2018/xml@0.4.0`;
- strict path-data parsing, absolute segment normalization, segment-level authored spans, geometry-aware one-to-one path alignment, and guarded exact segment-parameter and topology differences;
- formatting normalization for attribute order, quoting, tag closing, entity spelling, and supported inline declaration whitespace;
- supported presentation attributes and supported inline-style declarations, including complete supported presentation/inline overlaps normalized at the private renderer boundary;
- basic shape subjects: `rect`, `circle`, `ellipse`, `line`, `polyline`, and `polygon`;
- basic subject correspondence, insertion, deletion, split, and merge relationships for the supported shape inventory;
- supported geometry facts for those shapes, plus fill, stroke, stroke width, and opacity facts where implemented by the analyzer; canonical rendered completeness currently requires integer-valued geometry and leaf opacity `0` or `1`;
- ordinary inherited fill provenance in the validated inheritance slice;
- source, computed, and rendered distinction for equivalent paint spellings such as `red` and `#ff0000`;
- exact continuous parameter deltas independent of raster quantization;
- presence footprint, changed-pixel fraction, RGBA8 RMSE, and linear-premultiplied-RGBA RMSE where available;
- deterministic same-domain ordering under `v1_domain_lexicographic`;
- connected pixel-mask Difference Regions and conservative computed-bounds fallback regions;
- conservative Cause Envelopes with a sound-overapproximation guarantee for complete covered regions;
- self-contained HTML presentation generated from the report without recomputing comparison semantics.

## Partial and guarded slices

| Feature | Evidence retained | Why the result is partial |
| --- | --- | --- |
| Text content | Source-level `text.content` difference | Font loading, shaping, layout, and glyph raster evidence are deferred. |
| Group or root opacity | Supported source-level compositing difference | Isolated group compositing semantics are not fully modeled. |
| Fractional basic-shape geometry | Exact authored and computed numeric differences plus a pinned-renderer measurement | Chromium shows that the pinned renderer can quantize browser-invisible subpixel movement into full pixel changes; `renderer_fractional_geometry_unproven` limits Rendered Evidence. |
| Fractional leaf opacity | Authored/computed opacity and a numeric pinned-renderer measurement | The pinned renderer floors `0.5` to alpha `127` while Chromium uses `128`; `renderer_fractional_opacity_unproven` limits Rendered Evidence. |
| Referenced linear gradient | Narrow first-stop/single-rect source and computed analysis plus a pinned-renderer measurement | Browser interpolation differs from the pinned raster; `renderer_gradient_raster_unproven` limits Rendered Evidence even for the narrow slice, while other gradient semantics retain their broader guards. |
| Conflicting presentation attribute and inline style with incomplete or unsupported inline syntax | Independently supported Source Semantics | The private adapter cannot prove a safe renderer rewrite; `renderer_style_precedence_unresolved` blocks complete computed/rendered claims. |
| Stylesheets, selectors, or unsupported CSS syntax | Any independently supported source facts | The full cascade and selector model are not implemented. |
| Path geometry | Strict normalized segment inventory with authored Source Spans, geometry-aware one-to-one correspondence, exact normalized command/parameter/topology differences, continuous parameter deltas, and a bounded isolated alpha-boundary maximum-distance observation | Transforms, continuous-curve boundary distance, complete stroke and paint semantics, and accepted renderer conformance are not implemented; `unsupported_visual_subject` continues to limit computed/rendered claims. |
| Unsupported element, attribute, paint value, or resource use | Any independently supported evidence | Coverage is explicitly unproven for the affected layers. Deterministic [property tests](unsupported-input-properties.md) prevent unchanged unsupported inputs from becoming complete equality. |

These guards are part of v1 correctness. A guarded numeric renderer observation is not browser-conformant evidence, and absent rendered evidence is never interpreted as zero.

Current producers also project encountered renderer-specific Diagnostics into `renderer_capability_gaps`. The stable capability IDs distinguish CSS precedence, fractional geometry, fractional opacity, referenced-gradient rasterization, and group compositing. This encountered-only array does not list unrelated missing features and does not replace the coverage matrix.

## Unsupported or deferred

V1 does not completely analyze:

- scripts, event-driven state, or animation timelines;
- static `foreignObject` through an HTML/CSS layout engine;
- implicit network resources or caller-supplied resource bundles;
- complete path semantics, including transformed geometry, continuous-curve boundary distance, and browser-conformant stroke and paint evaluation;
- transforms and cumulative coordinate systems;
- `viewBox`, `preserveAspectRatio`, nested SVG viewports, or intrinsic viewport derivation;
- the general CSS cascade, selectors, custom properties, or `!important`;
- full gradients, radial gradients, patterns, markers, images, symbols, or `<use>` instances;
- clipping, masking, filters, blending, isolation, and complete group compositing;
- deterministic fonts, shaping, text layout, and glyph rasterization;
- perceptual backgrounds, FLIP, SSIM, learned perceptual metrics, and advanced color profiles;
- exact contribution weights, minimal root causes, or cross-subject event synthesis;
- browser-to-browser or renderer-to-renderer equality claims.

Pure nonvisual metadata such as accessibility descriptions and custom data attributes is outside visual Atomic Difference enumeration, although it remains present in the input source.

## Coverage behavior

For unsupported or unresolved content, the engine must:

1. emit a Diagnostic with a stable code;
2. identify the affected subject when known;
3. list the constrained evidence layers;
4. retain any independently supported source difference;
5. avoid a `complete` claim when the gap could affect the conclusion;
6. mark a Cause Envelope `not_established` when causal completeness cannot be guaranteed.

`complete`, `partial`, and `failed` describe analysis coverage. They do not classify whether the observed difference is visually important. Their exact guarantees and caller decision procedure are defined in the [Analysis Status Contract](analysis-status.md).

## Ownership boundaries

- `Milky2018/xml@0.4.0` owns XML well-formedness, namespaces, entities, and source locations.
- Private project code owns SVG-aware Source Semantics and mapping into report facts.
- `mizchi/svg@0.2.1` supplies the pinned scene and raster implementation behind the engine seam.
- The project owns comparison, coverage guards, alignment, magnitudes, regions, conservative Cause Envelopes, report serialization, and HTML projection.
- Dependency-specific types remain private.

Future expansion is tracked in the [post-v1 roadmap](../roadmap.md). Accepted but unimplemented directions remain discoverable through the [ADR index](adr/README.md) without being presented as current support.
