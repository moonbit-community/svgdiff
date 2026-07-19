# GitHub Page SVG Example Candidates

Status: research note

Evidence snapshot: 2026-07-19

## Conclusion

The GitHub Page should not use several zero-raster-difference examples at once. A useful first public set is one visually equivalent pair followed by five or six nonzero pairs that exercise different causal shapes: a tiny geometric displacement, an ordinary color change, a child deletion, a path-data change, a shared-resource fan-out, and a coordinated multi-element edit.

The strongest screenshot shortlist is:

1. SVGO absolute-unit normalization: exact visual equivalence;
2. Lucide Search: small but nonzero circle displacement;
3. Bootstrap Toggle: obvious solid-color change;
4. Lucide Badge Plus to Badge Minus: one visual child removed;
5. Tabler Chart Line: one data point moved;
6. Apache Batik Gradients: one shared gradient stop affects repeated consumers;
7. Apache Batik Bar Chart: one logical data correction changes three coordinated faces.

This gives only one intentional `0%` example. The zero is meaningful because the authored values differ while the used dimensions agree. The remaining examples should produce visible raster evidence at the comparison viewport, subject to the current renderer guards documented below.

## Source and licensing audit

Only first-party repositories were used. Links are pinned to the inspected commits so the candidate source does not drift.

| Source | Inspected revision | License | Relevant evidence |
| --- | --- | --- | --- |
| SVGO | `c34c0a8bdd52d56f1ce54974b7db2e13b4bbef0c` | MIT; retain copyright and permission notice | [repository](https://github.com/svg/svgo/tree/c34c0a8bdd52d56f1ce54974b7db2e13b4bbef0c), [license](https://github.com/svg/svgo/blob/c34c0a8bdd52d56f1ce54974b7db2e13b4bbef0c/LICENSE), [numeric cleanup fixture](https://github.com/svg/svgo/blob/c34c0a8bdd52d56f1ce54974b7db2e13b4bbef0c/test/plugins/cleanupNumericValues.01.svg.txt), [color fixture](https://github.com/svg/svgo/blob/c34c0a8bdd52d56f1ce54974b7db2e13b4bbef0c/test/plugins/convertColors.01.svg.txt), [path fixture](https://github.com/svg/svgo/blob/c34c0a8bdd52d56f1ce54974b7db2e13b4bbef0c/test/plugins/convertPathData.14.svg.txt) |
| Lucide | `658573b0171e693bc965c167592cc0b92d002a3e` | ISC for Lucide work; the license also records MIT attribution for named Feather-derived icons | [repository](https://github.com/lucide-icons/lucide/tree/658573b0171e693bc965c167592cc0b92d002a3e), [license](https://github.com/lucide-icons/lucide/blob/658573b0171e693bc965c167592cc0b92d002a3e/LICENSE), [Search](https://github.com/lucide-icons/lucide/blob/658573b0171e693bc965c167592cc0b92d002a3e/icons/search.svg), [Badge Plus](https://github.com/lucide-icons/lucide/blob/658573b0171e693bc965c167592cc0b92d002a3e/icons/badge-plus.svg), [Badge Minus](https://github.com/lucide-icons/lucide/blob/658573b0171e693bc965c167592cc0b92d002a3e/icons/badge-minus.svg) |
| Tabler Icons | `e7e5559d00684c7be15c3d8be6b18df3908a61cf` | MIT; retain copyright and permission notice | [repository](https://github.com/tabler/tabler-icons/tree/e7e5559d00684c7be15c3d8be6b18df3908a61cf), [license](https://github.com/tabler/tabler-icons/blob/e7e5559d00684c7be15c3d8be6b18df3908a61cf/LICENSE), [Chart Line](https://github.com/tabler/tabler-icons/blob/e7e5559d00684c7be15c3d8be6b18df3908a61cf/icons/outline/chart-line.svg), [Layers Intersect](https://github.com/tabler/tabler-icons/blob/e7e5559d00684c7be15c3d8be6b18df3908a61cf/icons/outline/layers-intersect.svg) |
| Bootstrap Icons | `f193d3f40caf1c57d88b571ce5643a2f6a51930f` | MIT; retain copyright and permission notice | [repository](https://github.com/twbs/icons/tree/f193d3f40caf1c57d88b571ce5643a2f6a51930f), [license](https://github.com/twbs/icons/blob/f193d3f40caf1c57d88b571ce5643a2f6a51930f/LICENSE), [Toggle On](https://github.com/twbs/icons/blob/f193d3f40caf1c57d88b571ce5643a2f6a51930f/icons/toggle-on.svg) |
| Apache Batik | `21a1ff1023186cc2694a6c210a64b28877eb36e3` | Apache License 2.0 stated in each selected SVG; preserve the license notice and provide the license text when redistributing derivatives | [repository](https://github.com/apache/xmlgraphics-batik/tree/21a1ff1023186cc2694a6c210a64b28877eb36e3), [Bar Chart](https://github.com/apache/xmlgraphics-batik/blob/21a1ff1023186cc2694a6c210a64b28877eb36e3/samples/barChart.svg), [Gradients](https://github.com/apache/xmlgraphics-batik/blob/21a1ff1023186cc2694a6c210a64b28877eb36e3/samples/gradients.svg), [GVT filters](https://github.com/apache/xmlgraphics-batik/blob/21a1ff1023186cc2694a6c210a64b28877eb36e3/samples/GVT.svg) |

The Page implementation should add a compact attribution section or a repository notice file before shipping derivatives. In particular, embedding an SVG as a JavaScript string must not silently discard the notice required by its source license.

## Candidate matrix

The `before` and `after` recipes below intentionally isolate one logical change. Exact viewport dimensions should be pinned in the example definition so that reported percentages and screenshots remain stable.

| ID | Pair construction | Expected result | Why it is representative | Page fit |
| --- | --- | --- | --- | --- |
| E01 | Adapt the SVGO numeric fixture into a visible rectangle. Use `width="1in" height="12pt"` before and `width="96" height="16"` after inside the same fixed `viewBox`. Keep every other attribute identical. | Source spelling differs; used geometry and rendered pixels should be equal. | Demonstrates semantic unit normalization, which is more instructive than only `red` versus `#ff0000`. | Core; intentional zero example. |
| E02 | Adapt the SVGO color fixture into a visible filled shape: `fill="rgb(64 64 64)"` versus `fill="#404040"`. | Computed color and pixels should be equal. | Real optimizer transformation and a compact sanity check for color canonicalization. | Optional; do not show alongside E01 in the default short list because both are zero. |
| E03 | Start with Lucide Search and change only `circle cx="11"` to `cx="11.05"`. Replace `currentColor` with one explicit sRGB color on both sides. At a 256 by 256 comparison viewport, the authored displacement is about `0.53` CSS pixel after viewBox scaling. | Small nonzero geometry and pixel evidence; likely partial because curved-shape and stroke raster conformance are guarded. | Shows why exact parameter magnitude and raster magnitude are separate, while still avoiding the confusing all-zero tiny example. | Core after confirming nonzero pixels in the built Page. |
| E04 | Compare the first path in SVGO `convertPathData.14`: cubic path `M0 0L0 0c2.761 0 5 2.239 5 5` with its optimizer output `M0 0a5 5 0 0 1 5 5`. Add the same explicit fill/stroke and a tight viewBox to both. | Near-equivalent optimizer rewrite; may produce a very small nonzero boundary difference because the cubic approximation and arc are not mathematically identical. | Separates optimizer tolerance from exact visual equality and tests path command/topology reporting. | Advanced; verify carefully before claiming equivalence. |
| E05 | Use the upstream Lucide Badge Plus as `before` and Badge Minus as `after`. Their outer badge and horizontal line are identical; the vertical `<line>` exists only before. Replace `currentColor` identically on both sides. | One structural deletion with a large localized visual consequence. | Cleanest child-removal case: the cause envelope should point at one missing visual subject rather than treating the whole badge as replaced. | Core. |
| E06 | Start with Tabler Chart Line. In the data path `M4 15l4 -6l4 2l4 -5l4 4`, move only the middle data point by changing one vertical parameter, for example the segment corresponding to `l4 2` to `l4 4`. Keep axes unchanged. | Nonzero path geometry concentrated around two adjacent segments. | Resembles a real chart-data correction and tests path parameter attribution rather than a whole-object translation. | Core; path evidence remains guarded but informative. |
| E07 | Start with Bootstrap Toggle On and replace `fill="currentColor"` with `fill="#0d6efd"` before and `fill="#dc3545"` after. | Same geometry, obvious nonzero color difference over a stable footprint. | A familiar filled icon makes the meaning of color, changed-pixel fraction, and perceptual score immediately legible. | Core. |
| E08 | Extract the Batik `barChart` group, remove text labels and the external Batik-logo `<use>`, and keep the four three-face bars. Change the Car bar height by editing all three affected face paths coherently. | Several atomic path changes, one logical visual event, nonzero geometry over a moderate region. | Tests whether the report can group coordinated low-level path edits into one understandable chart correction. | Core complex example; derivative attribution required. |
| E09 | Extract the self-contained content of Batik Gradients, remove the final external Batik-logo `<use>`, and change the middle stop of `patternBall` from `#666688` to a nearby purple. The resource is consumed through repeated `<use>` instances. | One source-resource change fans out to many rendered instances; gradient raster evidence is expected to be partial. | Exercises resource-to-consumer provenance and shows why one authored cause can create many regions without becoming many root causes. | Core diagnostic example if the Page explains `partial`; otherwise advanced. |
| E10 | From Batik GVT, isolate one simple shape and the `dropShadow` filter. Change `feOffset dx="4" dy="4"` to a visibly different offset while leaving the source shape unchanged. | Effect-region displacement; Gaussian blur makes current rendered evidence partial. | Demonstrates that the visual cause can live in an effect graph rather than in the painted shape itself. | Advanced capability-boundary example, not a default beginner example. |
| E11 | Start with Tabler Layers Intersect. Apply `transform="translate(1 0)"` only to the second path in `after`. | Nonzero rigid movement with overlapping before/after regions. | Useful for hover localization: both the old and new extent should be highlighted, rather than only a single bounding box around the final position. | Optional core geometry example. |

## Recommended screenshot set

For the user's requested visual review, render these seven first:

1. **E01 Unit equivalence** — establishes the meaning of a legitimate `0%` result;
2. **E03 Tiny Search displacement** — establishes a small but nonzero result;
3. **E07 Toggle color** — provides an obvious baseline;
4. **E05 Badge Plus to Minus** — shows structural deletion;
5. **E06 Chart Line correction** — shows path-local geometry;
6. **E09 Shared gradient stop** — shows resource fan-out and a deliberately partial analysis;
7. **E08 Bar Chart correction** — tests grouping on a realistic multi-element drawing.

If only six screenshots fit comfortably, omit E09 from the first review and retain it for a separate “advanced/partial analysis” section. The default Page list should not include E01 and E02 simultaneously because two different equivalence lessons still look like duplicate `0%` examples to a first-time visitor.

## Preparation constraints

- Pin a single comparison viewport and background per example. Otherwise a tiny displacement can change score merely because the Page configuration changed.
- Replace `currentColor` with an explicit color in Lucide, Tabler, and Bootstrap derivatives. The example must not inherit color from the Page environment.
- Keep the original `viewBox`; scale through the comparison viewport rather than rewriting every coordinate.
- Remove external references from Batik samples. The canonical analyzer performs no implicit I/O, and the examples must be self-contained.
- Remove Batik text labels from the extracted Bar Chart because deterministic font rendering remains deferred. The bars, axes, grid, and fills are sufficient.
- Preserve Apache and permissive-license attribution outside the source text if minification removes comments.
- Do not label E04 as visually equivalent until the actual Page run shows the intended magnitude. It is specifically valuable as an optimizer-tolerance case.
- A `partial` report for E03, E04, E06, E09, or E10 is expected under current conformance guards. The Page should explain that partial means some evidence is retained while a stronger renderer claim is withheld.

## Selection rationale

The candidates cover distinct questions an Agent must answer:

| Question | Candidate |
| --- | --- |
| Did source text change without changing used values or pixels? | E01, E02 |
| Is a small numeric change actually visible at this viewport? | E03, E04 |
| Did paint change while geometry stayed fixed? | E07 |
| Was a visual child added or removed? | E05 |
| Which path parameter changed the depicted data? | E06 |
| Did several low-level edits represent one user-level change? | E08 |
| Did one resource change affect many consumers? | E09 |
| Did an effect parameter move the result without moving the source shape? | E10 |
| Does localization contain both old and new spatial extents? | E11 |

This distribution is more useful than a gallery of unrelated attractive SVGs: every example has one controlled semantic lesson, and together they exercise the report abstractions the product is intended to expose to non-multimodal Agents.
