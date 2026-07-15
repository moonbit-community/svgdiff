# Resource Outcome Policy

Status: current contract for schema `1.27`

Last verified: 2026-07-15

This document defines how the comparison classifies missing, cyclic, invalid, and unused resources. It is a cross-family decision policy, not a replacement for the precise gradient, pattern, marker, use, image, clip, mask, or filter analyzers.

## Independent axes

Do not reduce a resource occurrence to a single `resolved` boolean. The engine evaluates five independent questions:

1. **Locator state:** Is the authored locator local, missing, external, a data URI, or syntactically invalid?
2. **Target kind:** When a local ID resolves, is the target one of the kinds accepted by this consumer?
3. **Semantic validity:** Can the referenced definition or supplied content be interpreted completely by its bounded family-specific analyzer?
4. **Graph safety:** Is the accepted local-reference graph acyclic and within fixed edge and transitive-expansion budgets?
5. **Activity:** Does the resource affect a rendered consumer in this document, or is it currently unused?

These axes have deliberately different consequences. A missing paint server can have a complete fallback; an invalid raster payload cannot. An unused valid definition can have source differences without a rendered consequence; an unused local cycle still fails the graph-safety gate.

## Outcome matrix

The first matching row determines the report-level outcome. Family-specific Diagnostics remain authoritative for the exact condition and affected evidence layers.

| Condition | Status | Retained evidence | Required interpretation |
| --- | --- | --- | --- |
| Malformed XML | `failed` | Bounded failure Diagnostic and parser location | No resource or difference inventory is usable. |
| Invalid caller bundle configuration, including empty/reserved/duplicate keys or unsupported declared MIME | `failed` | `resource_bundle_invalid`; no payload bytes | Caller input is rejected before SVG semantic analysis, whether or not an entry is referenced. |
| Fixed input, graph, expansion, bundle, decoder, raster, region, or report budget exceeded | `failed` | Bounded failure Diagnostic and an offending location where available | The engine cannot promise a complete, untruncated inventory. |
| Any accepted local-reference cycle, active or unused | `failed` | `reference_cycle_detected` and establishing reference locations | Cycle safety is a whole accepted-source admission invariant, not a reachability optimization. |
| Valid expected target and supported bounded semantics | `complete`-eligible | Source, computed, provenance, consumer fan-out, and rendered evidence where independently admitted | Later renderer guards may still make the overall report partial without invalidating resolved source/computed facts. |
| Missing or wrong-kind local `fill`/`stroke` target with an admitted fallback | `complete`-eligible | Exact authored URL and fallback, selected fallback value, active dependencies | Select the fallback; do not diagnose the missing server as indeterminate. |
| Missing or wrong-kind local `fill`/`stroke` target without a fallback | `complete`-eligible | Exact authored URL and deterministic no-paint result | Select no paint. This is not an unknown resource result. |
| Missing or wrong-kind local target for another consumer | `partial` | Exact locator/reference fact and Source Span plus independently supported facts | Emit the precise family Diagnostic, such as `use_target_missing`, `use_target_kind_unsupported`, or `marker_semantics_unsupported`. |
| External locator outside an explicit admitted bundle-backed raster image | `partial` | Exact authored locator and independently supported facts | Do not fetch. Use the family-specific external-reference or missing-bundle Diagnostic. |
| Malformed, unsupported, or semantically invalid referenced definition or payload | `partial` | Exact source facts, Source Spans, and every independently resolved component | Block only the evidence layers named by the family Diagnostic; do not substitute a guessed value or measured zero. |
| Valid unused SVG definition | `complete`-eligible | Resource-role source/computed differences, with no affected rendered-subject fan-out | Preserve latent visual semantics. Do not invent a consumer or nonzero final rendered outcome. |
| Invalid unused SVG definition | `partial` | Exact authored definition evidence and family Diagnostic | Activity does not make authored visual-resource syntax valid or prove source-semantic equality. |
| Unused caller-bundle entry with valid global configuration | No report difference | None; bytes remain caller acquisition context | Do not decode content or compare bundles independently of SVG references. |

`complete`-eligible means this resource condition does not itself force a lower status. The overall comparison can still be partial because another feature or rendered-evidence layer is guarded.

## Ordering of decisions

The engine applies the policy in this order:

1. validate caller bundle shape and fixed byte budgets;
2. parse the bounded SVG source and construct the typed dependency graph;
3. reject graph cycles, reference-edge overflow, and explosive `<use>` expansion;
4. resolve each family-specific reference and its deterministic fallback, if any;
5. analyze only referenced bundle content while retaining SVG-authored resource definitions for source-semantic comparison;
6. compose per-feature coverage into `failed > partial > complete`.

This ordering explains two superficially different unused cases. An unused bundle payload is not SVG-authored content and is never reached by a consumer, so its signature and pixels are not decoded. An unused SVG definition is part of the authored visual-resource source, so supported changes remain reportable and invalid semantics remain guarded. Bundle entry count, media type, key validity, and byte budgets are still global caller-input invariants because the bytes have already been supplied to the comparison.

## Agent reading rule

A text-only Agent must not infer resource meaning from the absence of an Atomic Difference alone. Read `analysis_status`, then the coverage matrix and Diagnostics. For `partial`, report the independently supported findings but never claim equality. For `failed`, stop interpreting difference arrays. For an unused resource difference, describe it as a source-visible latent resource change with no current consumer fan-out; do not call it a current pixel change. For missing paint targets, report the selected fallback or no-paint result rather than calling the paint indeterminate.

## Executable enforcement

- Cross-family outcome matrix: [`resource_outcome_policy_wbtest.mbt`](../engine/resource_outcome_policy_wbtest.mbt)
- Graph cycle, non-cycle, edge, and expansion safety: [`resource_limits_wbtest.mbt`](../engine/resource_limits_wbtest.mbt)
- Precise graph states and reachability: [`resource_dependency_graph_wbtest.mbt`](../engine/resource_dependency_graph_wbtest.mbt)
- Paint fallback selection: [`paint_fallback_wbtest.mbt`](../engine/paint_fallback_wbtest.mbt)
- Structural reuse failures and unused definitions: [`structure_semantics_wbtest.mbt`](../engine/structure_semantics_wbtest.mbt)
- Invalid gradient, pattern, clip, marker, and raster boundaries: [`gradient_diff_wbtest.mbt`](../engine/gradient_diff_wbtest.mbt), [`pattern_semantics_wbtest.mbt`](../engine/pattern_semantics_wbtest.mbt), [`clip_semantics_wbtest.mbt`](../engine/clip_semantics_wbtest.mbt), [`marker_geometry_wbtest.mbt`](../engine/marker_geometry_wbtest.mbt), and [`embedded_image_diff_wbtest.mbt`](../engine/embedded_image_diff_wbtest.mbt)
- Bundle configuration and lazy content validation: [`resource_bundle_wbtest.mbt`](../engine/resource_bundle_wbtest.mbt)
