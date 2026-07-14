# Influence Provenance Prototype Verdict

Status: archived research evidence; validated conclusions are implemented in `engine`

Evidence period: 2026-07-10 to 2026-07-13

Archived: 2026-07-14

This note preserves the results of the removed `prototype/influence_provenance` package. It does not define the current report schema, support boundary, or renderer decision. The current causal-completeness contract is [`influence-provenance.md`](../influence-provenance.md).

## Question

Does conservative tile-level Influence Provenance preserve every injected actual cause while allowing safe pruning and whole-Delta fallback?

## Automated walkthrough

The prototype used a deterministic six-tile toy renderer to derive output values, Difference Regions, and Influence Provenance through paint, blur, and composite operations.

| Scenario | Result | Observation |
| --- | --- | --- |
| Direct paint | PASS | The paint cause is retained and unrelated metadata is pruned. |
| Before/after movement | PASS | Unioning both renderings retains the cause for vacated and occupied tiles. |
| Filter expansion | PASS | The filter cause is retained together with one accepted false positive. |
| Compositing dependencies | PASS | Foreground and backdrop causes are retained together with one conservative blend candidate. |
| Unknown-operation fallback | PASS | Widening to all Changed Facts preserves completeness. |
| Unsupported operation | NOT CLAIMED | The injected cause is missing, but incomplete coverage prevents a false completeness claim. |

The experiment validated the data model, conservative transfer discipline, before/after union, fallback behavior, and the rule that incomplete coverage must revoke a completeness claim. The production regression cases now live in `engine/cause_envelope_test.mbt`; the toy implementation was removed after those guarantees were absorbed.

## Real MoonBit integration spike

The integration scenario used the published `mizchi/svg@0.2.1` parser and renderer with `mizchi/pixelmatch@0.6.1`.

| Experiment case | Observation |
| --- | --- |
| Parse and find `rect#box` | PASS |
| Recover geometry | `x=2.0 -> x=3.0` |
| Rendered difference | 72 pixels in one content region at `(2, 2, 9, 8)` |
| Conservative Cause Envelope | `[box.x, box.fill]`; no injected cause missing |
| Equivalent paint syntax | `red -> #ff0000` produces zero rendered difference pixels |
| Tiny negative geometry delta | `1.0 -> 0.99999` produces 16 difference pixels |
| Tiny positive geometry delta | `1.0 -> 1.00001` produces zero difference pixels |

This validated early parser-to-scene-to-render-to-region plumbing and a minimal conservative region-to-fact mapping. It also falsified the stronger hypothesis that an integer-oriented rasterizer can be the sole magnitude oracle: equal-size positive and negative micro-deltas behaved asymmetrically at the integer boundary.

The scenario did not validate real filter effect bounds, masks, clipping, blending, text, nested SVG, CSS, external references, complete provenance hooks, memory cost, or performance.

## Supersampled canvas experiment

A follow-up experiment rendered the same edge under positive and negative `0.00001` parameter changes mapped to increasing device scales. Premultiplied-RGBA comparison produced:

| Device delta | Negative error | Positive error |
| ---: | ---: | ---: |
| `0.00001` | 0 | 0 |
| `0.01` | 32 | 32 |
| `0.125` | 256 | 256 |
| `0.25` | 512 | 512 |
| `0.5` | 1024 | 1016 |

All non-zero cases affected four pixels. The final difference equals the declared maximum rounding allowance of one RGBA8 step per affected premultiplied color and alpha channel. This provisionally accepted `mizchi/canvas` as a higher-fidelity observation backend.

These alternate-scale values are renderer QA data only. The canonical report retains the exact Computed Appearance delta and the Render Observation under its declared Comparison Profile, not a scale curve.

The experiment required a temporary one-line `Debug` derive in downloaded `mizchi/image@0.4.2` because the published dependency did not compile under the tested toolchain. That cache modification was never part of this repository. The current blocker is tracked in [`dependency-security.md`](../dependency-security.md).

## Disposition

The conservative widening and before/after union discipline are implemented in the production engine. The executable prototype was removed on 2026-07-14 because no experiment or production package depended on it and retaining a second implementation risked contract drift.
