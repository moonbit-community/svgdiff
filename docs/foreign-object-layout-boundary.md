# Static foreignObject Layout Boundary

Status: accepted future profile boundary; no foreign-content layout is implemented

Future profile identity: `svgdiff-foreign-object-layout-profile/1`

Initial closed slice identity: `svgdiff-foreign-object-xhtml-rect-slice/1`

Future observation identity: `svgdiff-foreign-object-observation/1`

Last verified: 2026-07-17

General canonical support for static SVG `foreignObject` requires a deterministic engine for each admitted foreign host language. For XHTML, that means HTML element semantics, a UA stylesheet, CSS cascade and computed values, box and line layout, fonts and shaping, replaced resources, painting, and SVG-boundary compositing. The engine may be a smaller project-owned evaluator for a closed subset and may be isolated behind a workspace module or process; it need not be a complete embedded browser. An outer `foreignObject` rectangle, XML subtree comparison, or browser screenshot is not a substitute.

The current deterministic static Comparison Profile remains unchanged. Every `foreignObject` is guarded as an unsupported visual subject, including empty or identical input, so its uncomputed contents cannot produce false complete equality.

The governing decision is [ADR 0105](adr/0105-require-a-deterministic-host-language-engine-for-foreign-content.md). Primary evidence is in the [research note](research/foreign-object-layout-boundary.md), and the boundary is machine-checkable under [`evaluation/foreign-content-decision`](../evaluation/foreign-content-decision/).

## Why static content still needs an engine

`foreignObject` delegates descendant semantics to another XML namespace or host language. SVG supplies the outer geometry and integration point; it does not define how an XHTML `div`, inline text, margin, line break, flex container, image, control, or generated box is styled and laid out. “No script” removes one dynamic axis but does not remove CSS layout, font selection, bidi and line breaking, resources, UA defaults, overflow, or painting.

The current input seam parses standalone SVG as XML. Namespace-expanded names come from that XML parse; it does not run the HTML tokenizer or HTML tree builder. XHTML descendants must therefore carry the correct namespace under the accepted XML profile. If a later observation loads SVG through an HTML parser, its MIME type, embedding context, integration-point parsing, resulting namespace tree, and serialized DOM are a different target identity.

Unknown foreign namespaces are not assumed to be XHTML and are not treated as transparent or empty. Each admitted namespace requires a versioned handler with its own semantics and evidence contract.

## Required profile identity

A future `svgdiff-foreign-object-layout-profile/1` must close and hash all of these groups:

1. **Source and tree construction**: input MIME/processing mode, XML and namespace rules, accepted host-language namespace, element/attribute grammar, DOM/tree model, whitespace and character handling, and exact source/resource hashes.
2. **Host-language semantics**: accepted XHTML element subset, default roles and generated boxes, UA stylesheet, presentational hints, form/control exclusion or policy, and evaluator/spec/build identity.
3. **CSS semantics**: origins, cascade, inheritance, selectors, values and units, custom properties, display and box generation, formatting contexts, containing blocks, fragmentation, writing mode, bidi, line breaking, overflow, stacking, painting, and a closed accepted property/module set.
4. **SVG integration**: `x`, `y`, `width`, `height`, coordinate mapping, clipping and overflow, transforms, opacity, masks, clips, filters, blend/isolation, hit testing, stacking with SVG siblings, viewport, DPR, and cross-boundary inheritance rules.
5. **Text**: exact Font Bundle and Font Execution Profile, family matching and fallback, Unicode data, language, locale, shaping, bidi, line breaking, hyphenation, glyph metrics, rasterization, and missing-glyph behavior.
6. **Resources**: exact caller-supplied inputs or an accepted [Resource Snapshot Bundle](general-resource-snapshot-bundles.md), base URL, URL resolution, MIME and decoder rules, intrinsic sizes, replaced-element sizing, CSS images and fonts, recursion, readiness, and no-implicit-I/O policy.
7. **Processing axes**: scripts, events, interaction, animation timeline, forms, editable/selection state, media queries and preferences, locale, timezone, device/platform widgets, accessibility-only state, and explicit disabled or referenced profile values.
8. **Color and output**: color profile, canvas/background, compositing and raster identity, renderer/conformance identity, pixel normalization, and output evidence format.
9. **Safety and compatibility**: grammar and work limits, process isolation where applicable, normalized manifest hash, version compatibility, unsupported and failure policy, and complete evaluator/dependency build identities.

Declaring the same viewport and font bytes does not close the rest of this identity. A browser name alone is not a host-language profile.

## Evidence layers

Foreign content must preserve these as separate evidence rather than flattening them into a screenshot:

- namespace-qualified authored markup, attributes, text, style declarations, and Source Spans;
- selected declarations, inherited and computed values, generated boxes, and resource dependencies;
- box fragments, line boxes, glyph runs, replaced-content geometry, clipping, scroll/overflow state, stacking, and cross-boundary mappings;
- isolated foreign surface pixels and final SVG compositing evidence;
- alignment between foreign elements, boxes, text runs, resources, and affected SVG subjects;
- Atomic Differences, magnitudes, Difference Regions, and conservative Cause Envelopes only where their owning semantic and renderer layers are complete; and
- Diagnostics and per-layer coverage wherever any preceding result is unavailable.

Equal final pixels do not erase a reportable supported markup or computed-layout difference. A changed foreign subtree cannot receive causal completeness from its outer rectangle alone, because style, font, resource, layout, and overlapping SVG participants may all contribute.

## General support and bounded subsets

“General static XHTML” means all valid static XHTML/CSS behavior allowed by the claimed profile. It requires a correspondingly complete deterministic host-language engine and conformance corpus. Svgdiff will not claim general support from a browser wrapper, a DOM library, a CSS parser, or a box renderer that omits layout families.

A bounded canonical subset is viable when it has a closed namespace, element, attribute, CSS, layout, font, resource, paint, and SVG-integration grammar. The evaluator may be much smaller than a browser, but it is still a layout engine for that subset. Unsupported descendants, selectors, values, formatting contexts, fonts, resources, pseudo-elements, controls, or boundary effects must retain exact source evidence and make affected computed/rendered claims partial.

The accepted first implementation candidate is `svgdiff-foreign-object-xhtml-rect-slice/1`: XML-parsed SVG; explicit XHTML-namespace nested `div` elements; empty or XML-whitespace character data; element-attached `style` only; explicitly positioned finite non-negative CSS-pixel rectangles; reviewed `box-sizing`, solid sRGB backgrounds and borders, fixed clipping, and source-over alpha; and only independently admitted outer SVG geometry and composition. It excludes HTML repair, text, ordinary flow, auto or percentage sizing, intrinsic layout, stylesheets and selectors, variables, generated content, replaced resources, scrolling UI, transforms, effects, forms, script, interaction, and animation. Every excluded construct keeps the affected evidence partial.

This rectangular tracer tests namespace, boundary integration, layout provenance, and causal plumbing without waiting for fonts. It is not general HTML/CSS support. A text-bearing prose slice must wait for exact font matching, shaping, bidi, whitespace, line breaking, baselines, glyph layout, paint, and rasterization. Neither slice is implemented by this decision.

Dependency choice follows the existing renderer ownership gate: prove the feature with acceptance cases, locate the smallest failing layer, prefer a maintained deterministic dependency, and own only the smallest project-specific seam when released dependencies cannot satisfy it. No HTML/CSS engine dependency or workspace module is selected by this decision.

## Static processing boundary

Canonical foreign-content support remains secure-static:

- scripts and event-handler execution are permanently excluded;
- interaction state and animation are absent unless separately accepted profiles are referenced;
- network, filesystem, system fonts, ambient style sheets, plugins, media devices, storage, history, permissions, locale defaults, and platform UI are unavailable;
- form controls, editable content, selection, media playback, canvas, plugins, custom elements, shadow DOM, and implementation-native widgets are unsupported until separately profiled; and
- caller-supplied resources are admitted only by exact bytes under their owning bounded decoders and readiness rules.

CSS that is syntactically static can still reference ambient state or unsupported resources. Such input remains partial; “static” is not an instruction to guess defaults.

## Outcomes and observations

Canonical resolution retains distinct outcomes including:

- `resolved`;
- `invalid_profile`;
- `foreign_markup_invalid`;
- `foreign_namespace_unsupported`;
- `host_language_feature_unsupported`;
- `css_feature_unsupported`;
- `layout_unavailable`;
- `font_unavailable`;
- `resource_unavailable`;
- `svg_integration_unsupported`;
- `platform_widget_unsupported`;
- `privacy_sensitive_state_unsupported`;
- `dynamic_state_unsupported`;
- `layout_limit_exceeded`;
- `evaluator_conformance_divergent`;
- `renderer_conformance_unavailable`; and
- `insufficient_evidence`.

Missing, malformed, unsupported, unavailable, ambiguous, or limit-exceeded input is never an empty box, transparent pixels, numeric zero, or equality.

A future `svgdiff-foreign-object-observation/1` may capture one exact browser or layout target. It records source parsing mode and resulting namespace tree, target/build/OS, UA styles, viewport/DPR, fonts, resources, color, script/state/timeline policy, requested and achieved readiness, layout fragment and computed-style evidence where available, pixels, transcript, limits, repeats, and divergence. `ambient_unreproducible`, `replay_diverged`, `failed`, and `unavailable` remain distinct.

Even a byte-repeatable browser observation cannot fabricate canonical Source Semantics, Computed Appearance, Visual Events, Impact, Difference Regions, Cause Envelopes, or complete coverage. Cross-target observations use the accepted multi-renderer experiment model and never vote one layout into truth.

## Agent interpretation

A text-only Agent must distinguish the SVG outer rectangle, foreign source tree, host-language handler, computed style, layout fragments, text/resource evidence, isolated foreign surface, final compositing, and coverage. It must name the exact profile or target when describing a foreign-content result.

The Agent must not describe matching outer geometry as matching content, an empty renderer result as an empty `foreignObject`, unknown namespaces as XHTML, matching browser pixels as semantic equality, or a missing font/resource as no visual change.

## Implementation gate

Implementation may begin only when a concrete Agent task requires it and the project has:

- selected a closed first host-language slice and versioned every profile identity group above;
- implemented or selected a deterministic layout seam with exact source/build/dependency and conformance identity;
- completed the applicable font, resource, color, cascade, selector, layout, paint, clipping, compositing, and renderer prerequisites;
- exact positive, equivalent, malformed, namespace, unsupported, missing-resource/font, overflow, transform, opacity/effect, stacking, limit, and hostile-input cases;
- negative controls proving no system font, implicit I/O, script, event, animation, interaction, locale, platform widget, or ambient UA state enters execution;
- hard structural, style, selector, layout-fragment, line/glyph, resource, surface, recursion, time, memory, report, and process limits;
- conservative alignment and provenance sufficient for the claimed Agent differences, locations, and possible causes; and
- deterministic and cross-target conformance plus text-only Agent evaluation for the admitted subset.

Until then, run:

```sh
sh scripts/test-foreign-content-decision.sh
```
