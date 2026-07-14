# MoonBit SVG Ecosystem Survey

Status: research note

Registry snapshot: 2026-07-10

Last evidence refresh: 2026-07-13

Historical ecosystem evidence only. See [`../renderer-evaluation.md`](../renderer-evaluation.md) for the current production decision.

## Conclusion

A Rust renderer adapter is not a prerequisite for SVG Diff. Mooncakes currently provides a pure-MoonBit SVG parser, public scene graph, and CPU renderer in `mizchi/svg@0.2.1`, plus complementary raster and image-difference packages. The initial feasibility spike should therefore be MoonBit-native; resvg remains useful as an external conformance oracle or fallback only if measured gaps cannot be closed economically.

## Primary candidate: `mizchi/svg@0.2.1`

The package describes itself as a standalone SVG scene graph and renderer, has no module dependencies, and exposes:

- `parse_svg` and `parse_svg_document` for existing SVG markup;
- public `SVGNode`, `SVGDocument`, `Scene`, `Shape`, `Transform`, `BoundingBox`, `Paint`, filter, mask, clipping, gradient, pattern, marker, and image types;
- rendering from a document, scene, node, or SVG string into an in-memory `Image`;
- a public `PixelSetter` callback abstraction used by raster primitives;
- shapes, paths, affine transforms, gradients, filters, masks, clipping, blend modes, text, images, and hit testing.

Official source: [mizchi/svg](https://github.com/mizchi/svg). Mooncakes release inspected: `0.2.1`.

The package's 256 tests pass under the current toolchain on `wasm`, `wasm-gc`, `js`, and `native`:

```text
moon -C .repos/mizchi/svg/0.2.1 test --target all
Total tests: 256, passed: 256, failed: 0. [wasm]
Total tests: 256, passed: 256, failed: 0. [wasm-gc]
Total tests: 256, passed: 256, failed: 0. [js]
Total tests: 256, passed: 256, failed: 0. [native]
```

The run emits current-toolchain warnings for ambiguous empty-map literals but no failures.

## Suitability for SVG Diff

| Required capability | Current fit | Needed work |
|---|---|---|
| Parse existing SVG | Direct | Preserve authored values and source locations in a separate Source Semantics model or parser extension |
| Traverse scene structure | Direct through public concrete types | Assign report-local identities and extract normalized comparison features |
| Render final pixels | Direct | Define and reproduce the Comparison Profile |
| Inspect geometry and styles | Largely direct from public nodes and shapes | Expose or reimplement node-level computed bounds where current helpers are private |
| Generate Difference Regions | Directly composable | Convert rendered `Image` values into the project's continuous Difference Field |
| Influence Provenance | Feasible in MoonBit | Add Changed Fact tokens to scene resolution and conservative region propagation; current renderer has no provenance hooks |
| Exact Contribution Index | Not provided | Still deferred; would require deeper compositing instrumentation |
| Source fidelity | Incomplete for the project goal | The normalized scene graph cannot replace a raw XML/source-provenance model |

The renderer's internal `render_node` function is private, so an external dependency alone cannot inject node identities at every operation. Practical options are an upstream provenance hook, a maintained MoonBit fork, or a parallel conservative influence analysis over the public scene graph. None requires Rust.

## Known maturity limits

The package is substantial but not yet a browser-conformance replacement. Its own plan records open work around nested SVG sizing, CSS `<style>` handling in some marker cases, non-scaling stroke, gradient context behavior, external references, and broader text layout. Its WPT effort reports 83 enabled cases at the inspected release. These gaps must affect Analysis Coverage and should be tested against the SVG Diff corpus before expanding the v1 correctness claim.

The built-in rasterizer uses integer-oriented scanline and Bresenham-style primitives and produces 8-bit RGBA images. It is suitable for the first integration spike, but subpixel fidelity and antialiasing require explicit evaluation rather than assumption.

The first project integration spike confirmed this limitation. For an otherwise identical rectangle, `x=1.0` versus `x=0.99999` produced 16 differing pixels, while `x=1.0` versus `x=1.00001` produced zero. This discontinuity is consistent with integer quantization at a raster boundary. It does not invalidate the parser or scene graph, but it prevents this raster result from serving as the only geometry-magnitude channel.

## Complementary Mooncakes packages

### `mizchi/pixelmatch@0.6.1`

Provides MoonBit/WASM pixel comparison, antialias detection, diff images, region extraction, shift detection, and compact AI-oriented reports. Its YIQ/threshold model is useful as a baseline and region extractor, not a replacement for the project's continuous geometry, color, and FLIP measurements.

Official source: [mizchi/pixelmatch](https://github.com/mizchi/pixelmatch).

### `mizchi/canvas@0.9.0`

Provides a pure-MoonBit headless canvas renderer with paths, transforms, source-over blending, text through font outlines, images, PNG output, and optional 4x4 supersampling antialiasing. It targets JS, native, and wasm-gc and may become a higher-fidelity raster backend for `mizchi/svg` if the initial SVG renderer's sampling is insufficient.

The project spike found symmetric, monotonic premultiplied-RGBA responses for controlled positive and negative edge movement from `0.01` to `0.5` device pixels, within RGBA8 rounding. The renderer therefore remains a viable sampling backend. Direct adoption is temporarily blocked by a current-toolchain compilation error in transitive `mizchi/image@0.4.2`: an inline `assert_eq` requires `ColorType` to derive `Debug`. The algorithm was evaluated using a temporary one-line cache patch that is not part of the project.

Official source: [mizchi/canvas-mbt](https://github.com/mizchi/canvas-mbt).

### `Milky2018/xml@0.4.0`

Provides a document-buffered MoonBit XML pull reader with strict well-formedness, namespace-aware events, bounded entity expansion, disabled implicit external entity resolution, and authored Source Spans for events and attributes. It is the adopted foundation for the raw Source Semantics and provenance layer that the normalized SVG scene graph cannot preserve by itself.

Official source: [moonbit-community/xml-mbt](https://github.com/moonbit-community/xml-mbt).

## Revised recommendation

Validate this MoonBit-native stack first:

```text
Source Semantics       Milky2018/xml plus private SVG-aware adaptation
Computed Appearance   mizchi/svg scene graph
Render Observation    mizchi/svg Image, with mizchi/canvas evaluated for sampling
Difference Regions    project metrics plus optional mizchi/pixelmatch baseline
Influence Provenance  project extension in MoonBit
```

Use resvg only as a reference renderer in differential/conformance tests unless the MoonBit packages fail a measured v1 requirement. A production Rust seam should not be introduced speculatively.
