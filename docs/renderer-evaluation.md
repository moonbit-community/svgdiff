# Renderer Evaluation

Status: accepted strategy; initial candidate spike complete

## Decision strategy

Use a pure-MoonBit community renderer when it satisfies the core comparison contract or can be extended upstream at reasonable cost. Create a project-owned renderer only after a reproducible acceptance case demonstrates that the dependency cannot satisfy a required capability.

Adoption is capability-specific. A rasterization failure does not discard a parser or public scene graph that passed its own contract. Any project-owned workspace module is limited to the smallest layer whose required behavior cannot be obtained or extended upstream.

The renderer remains behind an internal seam. The external comparison interface and Structured Report schema do not expose dependency-specific types.

## Initial candidate stack

- `mizchi/svg@0.2.1`: SVG parsing, public scene graph, and CPU rendering;
- `mizchi/pixelmatch@0.6.1`: baseline pixel Difference Regions and shift analysis;
- `mizchi/canvas@0.9.0`: candidate higher-fidelity raster backend when supersampling or text/path rendering requires it;
- `Milky2018/xml@0.4.0`: adopted Source Semantics parsing and authored-provenance foundation;
- `moonbit-community/XMLParser@0.2.5`: evaluated structural DOM candidate; partially usable for trusted input but not accepted as the sole Source Semantics correctness boundary.

## Acceptance cases

The initial `mizchi/svg` spike must establish, with concrete artifacts rather than interface inspection alone:

1. existing SVG markup can be parsed into inspectable scene nodes;
2. the same scene renders deterministically at declared dimensions;
3. position, geometry, paint, transform, presence, and group changes produce measurable Difference Regions;
4. raw numeric distinctions remain available in the scene even when target pixels are equal;
5. conservative regions can be related to changed nodes without omitting injected causes;
6. filters, masks, clips, blending, text, nested SVG, CSS, references, and unsupported features have explicit coverage outcomes;
7. alternate-scale rerendering can be used internally for renderer QA without entering the canonical comparison model;
8. the supported targets required by the product remain buildable;
9. dependency warnings, failures, and conformance gaps can be converted into Structured Report Diagnostics;
10. required provenance hooks can be implemented upstream, wrapped conservatively, or maintained without copying the entire renderer into the core module.

## Initial spike results

The executable spike in `prototype/influence_provenance` uses the published `mizchi/svg@0.2.1` and `mizchi/pixelmatch@0.6.1` packages rather than a mock adapter.

| Experiment case | Result | Consequence |
|---|---|---|
| Parse two SVG documents and find `rect#box` | PASS | Public scene types are sufficient for initial Computed Appearance extraction. |
| Recover authored `x` values | PASS: `2.0 -> 3.0` | Raw numeric geometry remains available independently of pixels. |
| Render changed position and paint | PASS: 72 differing pixels | The stack can produce deterministic baseline Rendered Evidence. |
| Extract Difference Regions | PASS: one content region at `(2, 2, 9, 8)` | Baseline spatial localization is available. |
| Relate the region to before/after bounds | PASS | The conservative envelope contains both injected facts, `box.x` and `box.fill`. |
| Normalize equivalent paint syntax | PASS at rendered layer: `red -> #ff0000` produces zero differing pixels | Source representation and rendered equivalence can be kept separate. |
| Resolve a tiny negative geometry delta | 16 differing pixels for `1.0 -> 0.99999` | Integer rasterization can amplify a tiny parameter change at a quantization boundary. |
| Resolve a tiny positive geometry delta | 0 differing pixels for `1.0 -> 1.00001` | The same-magnitude parameter change can disappear at the selected raster scale. |

The asymmetric tiny-delta result disqualifies the current rasterizer as the sole Difference Magnitude oracle. It remains useful for parsing, scene inspection, baseline rendered localization, and early end-to-end development. Continuous parameter and device-space geometry measurements remain authoritative for geometric magnitude, while a higher-fidelity or supersampled renderer must be evaluated for Rendered Evidence.

The initial spike does not yet settle filters, masks, clips, blending, text, nested SVG, CSS, references, or provenance hooks. Those cases remain open and must constrain Analysis Coverage.

## XMLParser 0.2.5 source-layer evaluation

The [`XMLParser 0.2.5 evaluation`](research/xmlparser-evaluation.md) passed authored color spelling, SVG hierarchy, namespace-qualified attribute, single-quote, and entity-reference cases. It failed required well-formedness checks by accepting trailing input through `xml_from_string`, mismatched root tags, and duplicate attributes. Its public DOM also lacks element and attribute source spans, while the context-returning convenience API advertised in the README is not exported in 0.2.5.

The project will not depend on this library. The accepted replacement is `Milky2018/xml@0.4.0`.

## Milky XML 0.4.0 source-layer evaluation

The [`Milky XML 0.4.0 evaluation`](research/milky-xml-evaluation.md) passed strict document parsing, namespace-qualified elements, authored value recovery, explicit element boundaries, non-BMP offsets, contextual parse-error spans, bounded entity expansion, and disabled implicit external entity resolution. The project adopts the dependency and removes its custom XML parser module. Private Source Semantics helpers retain responsibility for selecting SVG visual declarations and mapping the dependency's events and spans into report evidence.

## Supersampled canvas spike

A second executable experiment evaluated `mizchi/canvas@0.9.0` with its 4x4 antialiasing path. The experiment mapped a parameter delta of `0.00001` into controlled device-space displacements around the same vertical edge and compared positive and negative movement using exact changed-pixel counts plus absolute premultiplied-RGBA error.

| Device-space delta | Negative response | Positive response | Symmetry result |
|---:|---:|---:|---|
| `0.00001` | 0 pixels, error 0 | 0 pixels, error 0 | Exact |
| `0.01` | 4 pixels, error 32 | 4 pixels, error 32 | Exact |
| `0.125` | 4 pixels, error 256 | 4 pixels, error 256 | Exact |
| `0.25` | 4 pixels, error 512 | 4 pixels, error 512 | Exact |
| `0.5` | 4 pixels, error 1024 | 4 pixels, error 1016 | Within one RGBA8 rounding step per affected premultiplied color and alpha channel |

This is a sufficient first result for the sampling strategy: the rendered response is monotonic and directionally symmetric within declared quantization error. A zero response at the original scale remains a valid Render Observation rather than evidence that the geometric difference does not exist; Computed Appearance still reports the exact `0.00001` parameter delta.

This scale experiment is renderer QA only. Its alternate-scale values do not enter Difference Magnitude, the canonical Structured Report, or visual-impact ordering.

The experiment also caught an invalid metric: comparing straight-alpha bytes directly made added and removed translucent red edges look highly asymmetric because RGB values remain non-zero at zero or low alpha. All project color and raster error metrics must therefore operate on linear premultiplied RGBA, as already required by the Difference Magnitude design.

The published dependency is not yet directly adoptable under the current toolchain. Its transitive `mizchi/image@0.4.2` source contains an inline `assert_eq` for `ColorType`, but that enum does not derive `Debug`, causing dependency compilation to fail. A one-line temporary cache patch was used only to separate this build-compatibility defect from raster behavior and was then removed. This is a focused upstream-fix candidate, not evidence that SVG Diff needs to own a rasterizer.

## Outcomes

### Adopt the dependency

Use the published module directly for the capabilities that pass. Do not infer that passing parser and baseline localization experiments makes its raster output an authoritative continuous magnitude measure.

### Extend upstream

Prefer a focused upstream hook or public helper when the renderer is correct but lacks introspection, conservative bounds, or provenance callbacks.

The current first upstream candidate is the `mizchi/image` `ColorType` test-compatibility fix required to build `mizchi/canvas` with the active MoonBit toolchain.

### Own a workspace module

If required correctness cannot be achieved through the dependency or a focused upstream change, create a separate MoonBit module for rendering and manage it through the repository workspace. The module owns SVG parsing/resolution/rasterization concerns; SVG Diff consumes only its stable observation and diagnostic interface.

Do not create this module before a failing acceptance case identifies the exact capability it must own.

## Role of resvg

resvg remains an optional external oracle for differential and conformance fixtures. It is not part of the production architecture unless later evidence overturns the MoonBit-native decision.
