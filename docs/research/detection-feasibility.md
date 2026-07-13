# SVG Difference Detection Feasibility

Status: research note

Evaluated against `resvg`/`usvg` 0.47.0 and their current official documentation and source. This note evaluates detection infrastructure, not the choice of scoring thresholds.

## Conclusion

The proposed multidimensional comparison is technically feasible for a deliberately bounded input class: static, resource-closed SVG rendered under a declared viewport, DPI, font set, and device scale. `usvg` provides a resolved scene representation suitable for computed-appearance and geometry analysis, while `resvg` provides deterministic full-tree and per-node rasterization suitable for final raster evidence and optional alternate-scale renderer QA.

One major capability is not available directly: neither the documented public API nor the renderer traversal exposes a per-pixel contributor/ID buffer. Correct contribution attribution through opacity, overlapping paint, filters, clips, masks, and blend modes requires renderer instrumentation. Rendering each node separately is useful evidence, but it is not equivalent to that node's contribution in the final composited image.

## Recommended initial scope

Accept static SVG with a closed resource set:

- no animation, scripting, events, or other dynamic behavior;
- external images and styles either disabled or content-addressed and captured in the Comparison Profile;
- exact fonts supplied by the Comparison Profile rather than discovered implicitly from the host;
- viewport, DPI, background, language, renderer version, and device scale recorded;
- unsupported or ignored features make analysis partial rather than equal.

This matches `resvg`'s stated static-SVG scope. Its official README explicitly excludes animation and other dynamic features, while `usvg` documents that unsupported SVG features are ignored and CSS support is minimal ([resvg README](https://github.com/linebender/resvg), [usvg crate documentation](https://docs.rs/usvg/0.47.0/usvg/)).

## Capability matrix

| Required capability | Direct capability | Derivable measurement | Requires instrumentation or wrapper | Known boundary |
|---|---|---|---|---|
| Parsed and resolved scene | `usvg::Tree` parses SVG into renderable `Group`, `Path`, `Image`, and `Text` nodes. Supported attributes, CSS, references, units, basic shapes, `use`, markers, and text are normalized or resolved. | Traverse the Rust tree to build Visual Entities and normalized computed properties. | A separate source model or parser-to-tree provenance layer is needed to retain original element/attribute locations after normalization. | Normalization intentionally converts, replaces, and removes source constructs; unsupported features are ignored. |
| Geometry and transforms | Every `usvg::Node` exposes absolute transform, object bounds, stroke bounds, absolute bounds, and layer bounds. Paths expose normalized absolute path segments, fill, stroke, and paint order. | Device-space displacement, boundary sampling, stroke-expanded geometry, bounding-box deltas, and geometric alignment features are computable. | Exact mapping from normalized paths back to authored primitives needs provenance instrumentation or the separate source model. | Geometry uses single-precision path types; extremely small source distinctions can collapse after normalization. |
| Final raster output | `resvg::render` renders a tree with a caller-provided root transform into a pixmap and documents the result as sRGB. `tiny-skia::Pixmap` stores 8-bit premultiplied RGBA pixels. | Changed-pixel area, alpha difference, premultiplied RGBA error, background-composited color error, SSIM/FLIP inputs, and difference regions can be computed from two outputs. | Higher-precision or direct linear-light output would require a different backend or renderer changes. | The public output is quantized RGBA8888; color conversion after rendering cannot recover precision already lost. |
| Isolated entity rendering | `resvg::render_node` renders any Rust `&usvg::Node`; the C API can render a node identified by a non-empty SVG `id`. | An isolated subtree raster and approximate footprint can be produced for highlighting and alignment evidence. | The C API does not expose general tree traversal, anonymous nodes, paths, styles, or text layout; a custom Rust adapter is required for complete entity analysis from MoonBit. | Isolated rendering omits the original backdrop and sibling compositing context, so it is not final contribution attribution. |
| Coverage | Alpha is directly available in the premultiplied output. `tiny-skia::Mask` can rasterize a path into an 8-bit antialiased mask. | Leaf fill/stroke coverage masks can be derived from normalized paths; output-alpha differences provide useful final visibility evidence. | A distinct coverage plane for the complete renderer, separated from paint opacity and masks, requires instrumentation. | Final alpha conflates geometric coverage, paint opacity, masks, filters, and compositing. It is not pure geometric coverage. |
| Filters, clips, masks, blending | `usvg::Group` exposes clip path, mask, filters, opacity, isolation, and blend mode. `usvg` states that all supported filters are resolved. `resvg` renders isolated groups, then applies filters, clip paths, masks, opacity, and blend mode. | Layer bounds and final raster effects are measurable without reimplementing SVG compositing. | Contributor propagation through these operations requires hooks around layer creation, filter application, mask/clip application, and final composition. | Effects can spread or combine influence across pixels and entities; a single categorical ID per pixel is insufficient in general. |
| Text and fonts | `usvg::Text` exposes resolved chunks, absolute bounds, positioned glyph layout, and a flattened group ready for rendering. `Options` accepts a font database; the parsed tree exposes the database actually used. | Text content/style comparisons, glyph-position deltas, outline geometry, bounds, and final raster differences are computable when fonts are fixed. | The C API exposes font loading and final rendering but not text layout; rich text evidence requires a Rust adapter. | Flattening is documented as best effort for some OpenType SVG/COLR glyph features. Missing or substituted fonts must make text conclusions partial or indeterminate. |
| Alternate-scale renderer QA | Both full-tree and node rendering accept a caller-supplied root transform and target pixmap. | Rerender the same resolved tree at diagnostic scales without reparsing, but keep those measurements outside the Structured Report. | None for ordinary diagnostic sampling. | Rerendering cannot recover a distinction already collapsed by `usvg`'s single-precision normalized representation. |
| Per-pixel entity contribution | No documented public `resvg` or `usvg` API returns a contributor map, ID buffer, draw callback, or contribution weights. | Per-node isolated rasters can suggest candidate affected regions. Expensive counterfactual whole-scene renders can measure causal effect only if a node can be reliably omitted. | Correct attribution requires an instrumented renderer/fork or a maintained patch that propagates report-local entity identities and contribution information through the render/composite pipeline. | Overlap, blending, group opacity, filters, and masks create many-to-one and neighborhood-dependent contributions; attribution is inherently richer than one ID per pixel. |
| Unsupported-feature diagnostics | The parser can emit warnings through logging, and the C API can initialize logging to stderr. | A wrapper can capture warnings and combine them with a source feature scan. | Structured diagnostics and coverage accounting require an adapter; stderr warnings are not a sufficient canonical report API. | Because unsupported features are ignored, absence of a raster difference is not evidence of equality unless feature coverage is known. |

## Evidence for the direct capabilities

`usvg` is explicitly designed as the preprocessing layer between XML and rendering. It documents resolution of supported inherited/default attributes, CSS application, conversion of basic shapes to absolute paths, resolution of `use` and references, unit conversion, text resolution, marker expansion, and filter support ([usvg crate documentation](https://docs.rs/usvg/0.47.0/usvg/)). The resulting tree exposes renderable nodes and reusable resources ([`usvg::Tree`](https://docs.rs/usvg/0.47.0/usvg/struct.Tree.html), [`usvg::Node`](https://docs.rs/usvg/0.47.0/usvg/enum.Node.html)).

Geometry access is already suitable for a comparison engine. Nodes expose absolute transforms and several bounding-box definitions, while paths expose normalized absolute segments and resolved painting properties ([`usvg::Node`](https://docs.rs/usvg/0.47.0/usvg/enum.Node.html), [`usvg::Path`](https://docs.rs/usvg/0.47.0/usvg/struct.Path.html), [`usvg::Group`](https://docs.rs/usvg/0.47.0/usvg/struct.Group.html)).

`resvg` has only two public rendering operations: render the complete tree or one node. Both accept a root transform and a destination pixmap, which directly enables controlled viewport placement and optional alternate-scale QA ([resvg crate API](https://docs.rs/resvg/0.47.0/resvg/), [`render`](https://docs.rs/resvg/0.47.0/resvg/fn.render.html), [`render_node`](https://docs.rs/resvg/0.47.0/resvg/fn.render_node.html)). The internal renderer source traverses nodes directly and applies group filters, clips, masks, opacity, and blend mode, but exposes no contributor callback or auxiliary buffer ([resvg renderer source](https://docs.rs/resvg/0.47.0/src/resvg/render.rs.html)).

Text is available at both semantic and outline levels. `usvg::Text` exposes text chunks, positioned layout, bounds, and a flattened renderable group, together with explicit limitations for certain SVG and COLR font glyphs ([`usvg::Text`](https://docs.rs/usvg/0.47.0/usvg/struct.Text.html), [`usvg::layout::PositionedGlyph`](https://docs.rs/usvg/0.47.0/usvg/layout/struct.PositionedGlyph.html)). Font selection is configurable and the final font database is retained on the tree ([`usvg::Options`](https://docs.rs/usvg/0.47.0/usvg/struct.Options.html)).

The C API is materially narrower than the Rust API. It exposes parsing, image and ID-addressed node bounds/transforms, whole-tree rendering, per-ID rendering, and font loading, but keeps the render tree opaque and exposes no node enumeration or computed paint/geometry details ([current `resvg.h`](https://github.com/linebender/resvg/blob/main/crates/c-api/resvg.h)).

## Attribution design consequence

The report should initially distinguish three levels of spatial evidence:

1. `semantic_region`: bounds and paths derived from aligned `usvg` entities;
2. `isolated_raster_region`: nontransparent pixels from `render_node`, explicitly labelled as isolated rather than final contribution;
3. `final_difference_region`: pixels that differ between complete before/after renders, initially attributed by overlap and alignment evidence with an explicit confidence value.

A later instrumented renderer can add `contribution_evidence`, but it should not block the first usable engine. Until then, the JSON must not claim that an isolated node raster proves which final pixels were caused by that node.

## MoonBit-native alternative discovered after the resvg survey

The original resvg-focused survey concluded that its opaque C API would require a small Rust analysis adapter. That conclusion applies only if resvg is selected as the production renderer; it is not a general project requirement.

Mooncakes currently provides `mizchi/svg@0.2.1`, a dependency-free MoonBit SVG parser, public scene graph, and CPU renderer, together with `mizchi/pixelmatch` and the pure-MoonBit `mizchi/canvas` rasterizer. The current recommendation is to validate this MoonBit-native stack first and retain resvg as a conformance oracle or fallback. See [`moonbit-svg-ecosystem.md`](moonbit-svg-ecosystem.md) for the package-level evidence and limitations.

## Feasibility judgment

- Computed scene extraction: feasible directly through the Rust `usvg` API.
- Geometry and bounds scoring: feasible directly or with ordinary derived calculations.
- Final raster scoring under the Comparison Profile is feasible directly through `resvg` and `tiny-skia`; alternate-scale rerendering remains an internal QA capability.
- Text comparison: feasible when exact fonts are supplied; otherwise conditional.
- Filters, masks, clips, and blend effects: feasible in final rendering; hard for attribution.
- Source-to-normalized provenance: requires a separate source model or parser instrumentation.
- Per-pixel contribution attribution: requires renderer instrumentation; no mature direct API was found.
- Pure MoonBit implementation: feasible enough for an immediate integration spike through `mizchi/svg`; conformance and subpixel fidelity remain unverified project risks.
- resvg through its existing C API: sufficient for raster-only comparison, insufficient for the full proposed scene and provenance model without a Rust adapter.
