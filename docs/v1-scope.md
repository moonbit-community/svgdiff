# Current V1 Support Contract

Status: implementation-aligned contract

Last verified: 2026-07-14

This document states what schema `1.0` can analyze today. It deliberately separates implemented support from accepted future design. If this file disagrees with an ADR or research note about current capability, this file wins; if it disagrees with the public types or JSON Schema about serialization, the code and Schema win.

The executable trace from each feature to its Diagnostic and tests lives in the [feature coverage matrix](feature-coverage.md).

## Correctness claim

V1 compares two well-formed deterministic static SVG source strings under one explicit common viewport and a pinned rendering profile. A `complete` report means every encountered visual semantic is covered by the implemented analyzer slice. It does not claim browser equivalence, cross-renderer equivalence, or equivalence under another viewport or environment.

When an input leaves the supported slice, the engine emits Diagnostics and changes `analysis_status` to `partial` or `failed`. Supported source-level differences may still be reported even when computed or rendered evidence is unavailable.

## Implemented profile

| Condition | Current behavior |
| --- | --- |
| Viewport | One explicit width and height shared by both inputs. CLI default: `16 x 16`. |
| DPR | Fixed to `1.0`. |
| Color interpretation | sRGB for the supported color slice. |
| Raster arithmetic | Canonical numeric error uses linear-sRGB premultiplied RGBA; renderer-native RGBA8 RMSE is also retained. |
| Renderer identity | Pinned as `mizchi/svg@0.2.1`. |
| Background | Transparent canvas only; no perceptual background option. |
| Resources | No caller-supplied resource bundle and no implicit network fetching. |
| Fonts | No deterministic font environment or font-dependent completeness claim. |

The root library seam canonicalizes DPR, color interpretation, raster representation, and renderer identity. It currently uses only the caller-supplied viewport dimensions from `ComparisonProfile`.

## Implemented complete-analysis slice

The following capabilities can participate in a `complete` report when no unsupported semantics are encountered:

- strict XML well-formedness and namespace-aware authored Source Spans through `Milky2018/xml@0.4.0`;
- formatting normalization for attribute order, quoting, tag closing, entity spelling, and supported inline declaration whitespace;
- supported presentation attributes and supported inline-style declarations, except conflicting presentation/inline declarations described below;
- basic shape subjects: `rect`, `circle`, `ellipse`, `line`, `polyline`, and `polygon`;
- basic subject correspondence, insertion, deletion, split, and merge relationships for the supported shape inventory;
- supported geometry facts for those shapes, plus fill, stroke, stroke width, and opacity facts where implemented by the analyzer;
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
| Referenced linear gradient | Narrow validated first-stop/single-rect cases may be analyzed | Other stops, attributes, references, and placements are diagnosed rather than generalized. |
| Conflicting presentation attribute and inline style | Normalized Source Semantics | The pinned renderer does not yet guarantee correct precedence independent of XML attribute order; `renderer_style_precedence_unresolved` blocks complete computed/rendered claims. |
| Stylesheets, selectors, or unsupported CSS syntax | Any independently supported source facts | The full cascade and selector model are not implemented. |
| Unsupported element, attribute, paint value, or resource use | Any independently supported evidence | Coverage is explicitly unproven for the affected layers. |

These guards are part of v1 correctness. They are not temporary permission to interpret absent rendered evidence as zero.

## Unsupported or deferred

V1 does not completely analyze:

- scripts, event-driven state, or animation timelines;
- static `foreignObject` through an HTML/CSS layout engine;
- implicit network resources or caller-supplied resource bundles;
- paths and general path comparison;
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

`complete`, `partial`, and `failed` describe analysis coverage. They do not classify whether the observed difference is visually important.

## Ownership boundaries

- `Milky2018/xml@0.4.0` owns XML well-formedness, namespaces, entities, and source locations.
- Private project code owns SVG-aware Source Semantics and mapping into report facts.
- `mizchi/svg@0.2.1` supplies the pinned scene and raster implementation behind the engine seam.
- The project owns comparison, coverage guards, alignment, magnitudes, regions, conservative Cause Envelopes, report serialization, and HTML projection.
- Dependency-specific types remain private.

Future expansion is tracked in the [post-v1 roadmap](../roadmap.md). Accepted but unimplemented directions remain discoverable through the [ADR index](adr/README.md) without being presented as current support.
