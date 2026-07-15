# Research Index

Research notes preserve dated evidence and rejected alternatives. They are not current product contracts. Consult the [documentation guide](../README.md), [current v1 scope](../v1-scope.md), and [renderer decision](../renderer-evaluation.md) before turning a research conclusion into an implementation assumption.

| Note | Evidence snapshot | Role |
| --- | --- | --- |
| [SVG difference detection feasibility](detection-feasibility.md) | 2026-07-13; `resvg`/`usvg` 0.47.0 | Establishes that scene, geometry, raster, and text evidence are technically obtainable, and records attribution limits. |
| [MoonBit SVG ecosystem survey](moonbit-svg-ecosystem.md) | Registry snapshot 2026-07-10; refreshed 2026-07-13 | Selects the MoonBit-native stack for the initial implementation. |
| [Visual difference metrics](visual-difference-metrics.md) | 2026-07-13 | Explains why magnitude is a vector and surveys possible future metrics. |
| [XMLParser 0.2.5 evaluation](xmlparser-evaluation.md) | 2026-07-13 | Rejected dependency evaluation retained for rationale. |
| [Milky XML 0.4.0 evaluation](milky-xml-evaluation.md) | 2026-07-13 | Accepted dependency evidence for authored parsing and spans. |
| [Influence Provenance prototype verdict](influence-provenance-prototype.md) | 2026-07-10 to 2026-07-13 | Archives the removed prototype's causal propagation and renderer experiments. |
| [Historical structured-report prototype verdict](structured-report-prototype.md) | 2026-07-13 to 2026-07-14 | Records the prototype findings later promoted into `engine`. |
| [Deterministic SVG solid color and opacity](css-color-opacity.md) | 2026-07-15 | Fixes the normative sRGB and opacity boundary, records the MoonBit dependency audit, and reports Chromium conformance evidence. |
| [SVG gradient semantics](svg-gradient-semantics.md) | 2026-07-15 | Fixes the static same-document gradient boundary and records the browser-conformance guard. |
| [SVG pattern semantics](svg-pattern-semantics.md) | 2026-07-15 | Fixes the admitted static same-document pattern boundary and records its coordinate, template, child, and raster-conformance semantics. |
| [SVG paint fallbacks](svg-paint-fallbacks.md) | 2026-07-15 | Fixes the URL fallback grammar, missing and wrong-kind target behavior, local-reference boundary, and renderer ownership. |
| [SVG paint order and winding rules](svg-paint-order-and-winding-rules.md) | 2026-07-15 | Fixes inherited `paint-order`, `fill-rule`, and `clip-rule`, active-operation normalization, and the clip-path boundary. |
| [SVG structure and use semantics](svg-structure-and-use-semantics.md) | 2026-07-15 | Fixes direct-versus-definition rendering, use-instance identity, inheritance, viewport placement, reference admission, and renderer guards. |
| [Structural impact semantics](structural-impact-semantics.md) | 2026-07-15 | Fixes consequence-aware ancestry, instance-resolution, stacking, and conservative causal attribution. |
| [SVG resource dependency graph](svg-resource-dependency-graph.md) | 2026-07-15 | Records typed nodes, reference edges, locator states, traversal, safety reuse, and report projection. |
| [Embedded raster resource policy](embedded-raster-resource-policy.md) | 2026-07-15 | Fixes the admitted PNG/JPEG data-URL subset, bounded decoder boundary, intrinsic metrics, no-I/O rule, and renderer gap. |
| [Explicit local resource bundle policy](local-resource-bundle-policy.md) | 2026-07-15 | Fixes opaque exact locator matching, separate before/after bundles, bundle budgets, explicit CLI acquisition, and the zero-implicit-I/O boundary. |

Research should be amended only to correct factual errors or to add an explicitly dated follow-up. Changes to current product policy belong in an ADR and the current contract documents.
