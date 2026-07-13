# Prototype Verdict

Status: toy walkthrough and first real MoonBit integration spike complete

## Question

Does conservative tile-level Influence Provenance preserve every injected actual cause while allowing safe pruning and whole-Delta fallback?

## Automated walkthrough

The six-tile toy renderer derives output values, Difference Regions, and Influence Provenance through paint, blur, and composite operations.

| Scenario | Result | Observation |
|---|---|---|
| Direct paint | PASS | The paint cause is retained and unrelated metadata is pruned. |
| Before/after movement | PASS | Unioning both renderings retains the cause for vacated and occupied tiles. |
| Filter expansion | PASS | The filter cause is retained together with one accepted false positive. |
| Compositing dependencies | PASS | Foreground and backdrop causes are retained together with one conservative blend candidate. |
| Unknown-operation fallback | PASS | Widening to all Changed Facts preserves completeness. |
| Unsupported operation | NOT CLAIMED | The injected cause is missing, but incomplete coverage prevents a false completeness claim. |

The prototype validates the data model, conservative transfer discipline, before/after union, and fallback behavior.

## Real MoonBit integration spike

Scenario 7 uses the published `mizchi/svg@0.2.1` parser, public scene graph, and renderer together with `mizchi/pixelmatch@0.6.1`.

| Experiment case | Observation |
|---|---|
| Parse and find `rect#box` | PASS |
| Recover geometry | `x=2.0 -> x=3.0` |
| Rendered difference | 72 pixels in one content region at `(2, 2, 9, 8)` |
| Conservative Cause Envelope | `[box.x, box.fill]`; no injected cause missing |
| Equivalent paint syntax | `red -> #ff0000` produces zero rendered difference pixels |
| Tiny negative geometry delta | `1.0 -> 0.99999` produces 16 difference pixels |
| Tiny positive geometry delta | `1.0 -> 1.00001` produces zero difference pixels |

This validates the real parser-to-scene-to-render-to-region plumbing and a minimal conservative region-to-fact mapping. It also falsifies the stronger hypothesis that this integer-oriented rasterizer can be the sole magnitude oracle: equal-size positive and negative micro-deltas behave asymmetrically at the integer boundary.

The prototype still does not validate real filter effect bounds, masks, clipping, blending, text, nested SVG, CSS, external references, complete provenance hooks, memory cost, or performance. The next renderer experiment should evaluate a supersampled `mizchi/canvas` path or a focused upstream raster hook before a project-owned workspace module is created.

## Supersampled canvas experiment

The follow-up experiment rendered the same edge under positive and negative `0.00001` parameter changes mapped to increasing device scales. The correct premultiplied-RGBA comparison produced:

| Device delta | Negative error | Positive error |
|---:|---:|---:|
| `0.00001` | 0 | 0 |
| `0.01` | 32 | 32 |
| `0.125` | 256 | 256 |
| `0.25` | 512 | 512 |
| `0.5` | 1024 | 1016 |

All non-zero cases affected four pixels. The final difference is exactly the declared maximum rounding allowance of one RGBA8 step per affected premultiplied color and alpha channel. This accepts `mizchi/canvas` provisionally as a higher-fidelity observation backend.

The alternate-scale values in this experiment are renderer QA data only. The canonical report retains the exact Computed Appearance delta and the Render Observation under its declared Comparison Profile, not a scale curve.

The experiment required a temporary one-line `Debug` derive in downloaded `mizchi/image@0.4.2` because the published dependency does not compile under the active toolchain. That cache modification is not part of the project. A focused upstream compatibility fix is preferred over a workspace-owned raster module at this point.

## User verdict

To be filled before the prototype is deleted or its validated logic is absorbed into the production design.
