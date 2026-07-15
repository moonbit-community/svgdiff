# Current V1 Support Contract

Status: implementation-aligned contract

Last verified: 2026-07-15

This document states what schema `1.17` can analyze today. It deliberately separates implemented support from accepted future design. If this file disagrees with an ADR or research note about current capability, this file wins; if it disagrees with the public types or JSON Schema about serialization, the code and Schema win.

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
| Renderer identity | Pinned as `svgdiff/style-precedence-normalizer@3+ordinary-inheritance-normalizer@1+css-computed-value-normalizer@1+css-color3-opacity-normalizer@1+length-used-value-normalizer@1+stroke-used-geometry-normalizer@1+basic-shape-used-geometry-normalizer@1+mizchi/svg@0.2.1`. |
| Renderer conformance profile | Pinned independently as `svgdiff-renderer-conformance-profile/14`. |
| Background | Transparent canvas only; no perceptual background option. |
| Resources | No caller-supplied resource bundle and no implicit network fetching. |
| Reference admission | Accepted local fragment edges are checked for cycles and bounded transitive `<use>` expansion before renderer parsing. |
| Fonts | No deterministic font environment or font-dependent completeness claim. |

The root library seam canonicalizes DPR, color interpretation, raster representation, renderer identity, and renderer conformance profile. It currently uses only the caller-supplied viewport dimensions from `ComparisonProfile`.

## Implemented complete-analysis slice

The following capabilities can participate in a `complete` report when no unsupported semantics are encountered:

- strict XML well-formedness and namespace-aware authored Source Spans through `Milky2018/xml@0.4.0`;
- strict path-data parsing, absolute segment normalization, segment-level authored spans, geometry-aware one-to-one path alignment, and guarded exact segment-parameter and topology differences;
- strict SVG transform-list parsing for `matrix`, `translate`, `scale`, `rotate`, `skewX`, and `skewY`; source-located authored facts; cumulative affine matrices through entities, groups, resource containers, and nested `svg` ancestry; and canonical typed translation, rotation, signed-scale, skew, or singular residual effects;
- root `viewBox` mapping into the explicit Comparison Viewport and nested `svg` viewport mapping from unitless, CSS absolute-unit, percentage, or `vw`/`vh`/`vmin`/`vmax` `x`, `y`, `width`, and `height`, including all `preserveAspectRatio` alignments, `none`, `meet`, and `slice`; source-located `document.viewport` facts remain distinct from leaf cumulative matrices and typed effects;
- formatting normalization for attribute order, quoting, tag closing, entity spelling, and supported inline declaration whitespace;
- supported presentation attributes, inline-style declaration lists, and matched static stylesheet rules, including selector specificity, source order, duplicate properties, `!important`, and private renderer normalization of the selected winners;
- basic shape subjects with canonical used geometry from unitless, CSS absolute-unit, SVG percentage, and admitted viewport-relative lengths: `rect`, `circle`, `ellipse`, `line`, `polyline`, and `polygon`, including omitted defaults, rectangle `auto` dimensions, zero-size numeric geometry, rectangle and ellipse radius propagation, rectangle radius clamping, number-only point-list normalization, line no-interior semantics, and polyline/polygon fill closure semantics;
- basic subject correspondence, insertion, deletion, split, and merge relationships for the supported shape inventory;
- supported geometry facts for those shapes, plus fill, stroke paint, canonical length-aware stroke width, dash arrays and dash offsets, caps, joins, miter limits, `vector-effect`, and opacity facts where implemented by the analyzer; active stroke rasterization remains separately guarded;
- local `marker`, `marker-start`, `marker-mid`, and `marker-end` attachment facts plus canonical length-aware marker viewport/reference properties, SVG path vertex roles, automatic orientation, instance transforms, and conservative clipped viewport envelopes; marker child paint and rasterization remain separately guarded;
- ordinary inheritance for supported `fill`, `stroke`, stroke-width/cap/join/miter/dash properties, and marker longhands across admitted `svg`/`g` ancestry, including nearest-owner or initial-value resolution, owner-level Changed Facts, leaf consequences, computed relations, and renderer-input materialization;
- `inherit`, `initial`, `unset`, and author-origin `revert` for every supported inherited and non-inherited property; deterministic black initial `color`; `currentColor` for supported paint consumers; and case-sensitive inherited custom properties with bounded nested `var()` references and fallbacks, invalid-at-computed-value behavior, dependency-aware Changed Facts, and private renderer materialization;
- strict deterministic sRGB solid colors across CSS Color 3 hexadecimal, RGB(A), HSL(A), extended named colors, `transparent`, and admitted alpha-hex syntax; canonical computed channels remain separate from exact authored spelling and Source Span;
- number-or-percentage `opacity`, inherited `fill-opacity` and `stroke-opacity`, and non-inherited `stop-opacity`, with `[0,1]` clamping, continuous numeric deltas, and effective leaf or stop alpha multiplication;
- static same-document linear and radial gradients, including recursive `href` and `xlink:href` template inheritance, all child stops, clamped monotonic offsets, sRGB stop colors and opacity, `gradientUnits`, `spreadMethod`, `gradientTransform`, default and explicit geometry, object-bounding-box and user-space consumer coordinates, degenerate paint modes, exact resource-component differences, and fill/stroke fan-out to every consumer;
- source, computed, and rendered distinction for equivalent paint spellings such as `red`, `#ff0000`, `rgb(255,0,0)`, and `hsl(0,100%,50%)`;
- exact continuous parameter deltas independent of raster quantization;
- presence footprint, changed-pixel fraction, RGBA8 RMSE, and linear-premultiplied-RGBA RMSE where available;
- deterministic same-domain ordering under `v2_domain_lexicographic`;
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
| Environment-dependent system colors | Exact authored value and Source Span | No pinned system palette exists; `system_color_environment_unsupported` prevents environment-dependent equality. |
| Wide-gamut or out-of-profile color functions | Exact authored value and Source Span | Profile conversion is deferred; `color_profile_unsupported` prevents clipping or substitution into sRGB. |
| Malformed solid color or opacity syntax | Exact authored value and Source Span | `solid_color_syntax_unsupported` or `opacity_syntax_unsupported` prevents invalid values from silently becoming black, transparent, or another numeric value. |
| Referenced linear or radial gradient rasterization | Complete static source/computed resource semantics, every fill/stroke consumer outcome, conservative localization, and a pinned-renderer measurement | All six focused browser fixtures diverge from the pinned raster; `renderer_gradient_raster_unproven` limits only Rendered Evidence. |
| Invalid or unresolved gradient semantics | Exact authored declarations, Source Spans, and every independently resolved resource or consumer fact | Dedicated Diagnostics distinguish external/invalid references, cycles, dynamic content, malformed offsets/lengths/units/spread/transforms, missing object bounds, and non-sRGB interpolation instead of treating all paint servers as one gap. |
| Conflicting presentation attribute and inline style with incomplete or unsupported inline syntax | Independently supported Source Semantics | The private adapter cannot prove a safe renderer rewrite; `renderer_style_precedence_unresolved` blocks complete computed/rendered claims. |
| Selector or stylesheet syntax outside the admitted static grammar | Any independently parsed selector, declaration, authored value, and Source Span evidence | `css_cascade_unsupported` prevents unsupported applicability from being approximated as matching or not matching. |
| Cascade layers or `revert-layer` | Independently supported authored declarations and Source Spans | `css_revert_layer_unsupported` prevents author-only `revert` semantics from being misapplied across unmodeled layers. |
| Variable syntax outside the admitted balanced component-text subset | Independently supported declarations, dependencies, and Source Spans | `css_variable_syntax_unsupported` prevents excluded strings, escapes, comments, malformed `var()`, or invalid custom-property names from being approximated. |
| Excessive custom-property expansion | Independently supported declarations, dependencies, and Source Spans | `css_variable_expansion_limit` bounds recursion and output size rather than returning a truncated computed value. |
| Path geometry | Strict normalized segment inventory with authored Source Spans, geometry-aware one-to-one correspondence, exact normalized command/parameter/topology differences, continuous parameter deltas, and a bounded isolated alpha-boundary maximum-distance observation | Transformed-path boundary measurement, continuous-curve boundary distance, complete stroke and paint semantics, and accepted path renderer conformance are not implemented; `unsupported_visual_subject` continues to limit computed/rendered claims. |
| General affine transform rasterization | Exact authored transform-list and cumulative-matrix differences plus a pinned-renderer measurement | Only integer axis-aligned matrices, translations, scales, and quadrant rotations have accepted browser fixtures; `renderer_transform_raster_unproven` limits other affine Rendered Evidence. |
| Non-integer viewport mapping | Exact viewport declarations, resolved cumulative matrices, typed transform effects, and a pinned-renderer measurement | Root and nested `none`, meet, slice, and integer-axis mappings have exact browser fixtures; `renderer_viewport_raster_unproven` limits other viewport Rendered Evidence. |
| Invalid, non-positive, or unsupported-unit viewport declaration | Exact authored declaration and Source Span when available | `viewport_semantics_unsupported` prevents a complete coordinate mapping. |
| Invalid or unsupported basic-shape geometry | Authored facts, exact Source Spans, and any independently resolved geometry | `basic_shape_geometry_unsupported` prevents source, computed, and rendered completeness; valid zero-size geometry is not an error. |
| Curved basic-shape rasterization | Canonical circle/ellipse/rounded-rectangle geometry, computed relations, bounds, and a pinned-renderer measurement | Chromium differs from the pinned renderer on boundary antialiasing; `renderer_curved_shape_raster_unproven` limits Rendered Evidence. |
| Filled point-shape rasterization | Canonical polyline/polygon point sequence, closure semantics, computed relations, bounds, and a pinned-renderer measurement | Chromium differs from the pinned renderer on filled boundaries; `renderer_point_shape_raster_unproven` limits Rendered Evidence. |
| Active stroke outline rasterization | Canonical stroke used geometry, computed relations, conservative bounds, and a pinned-renderer measurement | Chromium differs from the pinned renderer for admitted caps and outlines; `renderer_stroke_outline_raster_unproven` limits Rendered Evidence. |
| Active stroke joins and dashes | Canonical joins, miter limits, dash patterns, offsets, computed relations, and conservative bounds | Chromium differs from the pinned renderer; `renderer_stroke_join_raster_unproven` and `renderer_stroke_dash_raster_unproven` limit Rendered Evidence. |
| Transformed `non-scaling-stroke` rasterization | Distinct host-space used-width semantics and conservative bounds | Chromium differs from the pinned renderer; `renderer_non_scaling_stroke_unproven` limits Rendered Evidence. |
| Marker placement and viewport semantics | Authored attachment/resource facts, local-reference resolution, SVG start/mid/end vertices, automatic orientation, unit and viewBox transforms, typed resource differences, and conservative clipped instance envelopes | Marker child paint/cascade and context paint are not interpreted; `marker_content_semantics_unsupported` limits Computed Appearance and Rendered Evidence. |
| Invalid or unsupported marker semantics | Exact authored declaration and Source Span where available | `marker_semantics_unsupported` or `marker_resource_semantics_unsupported` prevents false equality for missing, wrong-kind, external, malformed, unsupported-unit, visible-overflow, or otherwise unresolved marker input. |
| Marker rasterization | Independently modeled placement and conservative marker regions | All six Chromium fixtures diverge from the pinned renderer, including percentage lengths and zero-size behavior; `renderer_marker_raster_unproven` limits Rendered Evidence. |
| Malformed transform syntax | The exact authored declaration and source span | `transform_syntax_unsupported` prevents source, computed, and rendered completeness. |
| `patternTransform` | Authored transform-list and resource-local matrix differences | Pattern units, inheritance, references, and paint behavior remain unresolved under `resource_transform_semantics_unsupported`; `gradientTransform` is fully interpreted in the static gradient slice. |
| Unsupported element, attribute, paint value, or resource use | Any independently supported evidence | Coverage is explicitly unproven for the affected layers. Deterministic [property tests](unsupported-input-properties.md) prevent unchanged unsupported inputs from becoming complete equality. |

These guards are part of v1 correctness. A guarded numeric renderer observation is not browser-conformant evidence, and absent rendered evidence is never interpreted as zero.

Current producers also project encountered renderer-specific Diagnostics into `renderer_capability_gaps`. The stable capability IDs distinguish CSS precedence, fractional geometry, fractional opacity, curved-shape, filled point-shape, stroke outline, stroke join, stroke dash, non-scaling-stroke, marker, general affine, viewport, referenced-gradient rasterization, and group compositing. This encountered-only array does not list unrelated missing features and does not replace the coverage matrix.

## Unsupported or deferred

V1 does not completely analyze:

- scripts, event-driven state, or animation timelines;
- static `foreignObject` through an HTML/CSS layout engine;
- implicit network resources or caller-supplied resource bundles;
- complete path semantics, including transformed geometry, continuous-curve boundary distance, and browser-conformant stroke and paint evaluation;
- precise transform-aware bounds and localization beyond the conservative whole-scene outcome regions;
- automatic Comparison Viewport derivation, CSS sizing/cascade for SVG viewport properties, font/environment-relative lengths, arithmetic length functions, or dynamic viewport variants; object-bounding-box coordinates are implemented only for static gradient consumers;
- CSS-layout-dependent basic-shape or stroke lengths, exact continuous transformed stroke outlines, `pathLength` calibration, or precise transform-aware shape localization;
- selector escapes, namespaces, pseudo-classes/elements, functional selectors, comments, at-rules, non-author cascade origins, layers, scoping, registered custom properties, animation taint, complete CSS tokenization, system palette selection, or custom-property syntax outside the admitted balanced subset;
- external or animated gradients, non-sRGB gradient interpolation, patterns, marker child paint/cascade, `context-fill`/`context-stroke`, external marker references, unsupported relative marker lengths, visible marker overflow, images, symbols, or `<use>` instances;
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
