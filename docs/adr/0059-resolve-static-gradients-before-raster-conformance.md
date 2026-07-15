# ADR 0059: Resolve Static Gradients Before Raster Conformance

Status: accepted and implemented for static same-document sRGB gradients

## Context

The earlier gradient slice compared one linear-gradient stop on one rectangle. It could not enumerate every possible semantic cause, distinguish resource changes from consumer outcomes, or prove equivalence across direct and template-based authoring. The pinned renderer also disagrees substantially with Chromium on gradient sampling, so raster pixels cannot safely stand in for the missing computed model.

SVG gradients combine two levels. A paint-server resource owns geometry, units, spreading, transforms, stops, and template references; a fill or stroke consumer supplies the viewport and, for `objectBoundingBox`, the target bounds needed to compute its actual coordinate mapping. A complete causal inventory must retain both levels without multiplying one authored resource edit into several fake edits.

## Decision

Own a renderer-independent static gradient model for `linearGradient` and `radialGradient`. Resolve default and explicit geometry, `gradientUnits`, `spreadMethod`, `gradientTransform`, every stop, clamped monotonic offsets, sRGB stop color and opacity, and recursive same-document `href`/`xlink:href` inheritance. Apply SVG's missing-attribute inheritance and child-set replacement rules, including cross-kind template chains. Compute object-bounding-box or user-space coordinates separately for every fill and stroke consumer.

Emit resource-component Atomic Differences separately from downstream `paint.fill` and `paint.stroke` outcomes. One Changed Fact retains its resource or template ownership and lists every affected consumer. An unreferenced resource stays resource-only; a direct/template rewrite may be source-visible but computed-equivalent. Zero-stop, one-stop, and degenerate gradient modes are explicit rather than inferred from renderer output.

Keep `renderer_gradient_raster_unproven` until browser conformance demonstrates an acceptable renderer path. Use precise guards for external or invalid references, cycles, dynamic content, malformed syntax, missing target bounds, and non-sRGB interpolation instead of the retired broad gradient and paint-server guards.

## Consequences

Text-only agents can enumerate all modeled gradient causes, quantify every changed component, and connect one resource change to all consumers without image access. Static source and computed semantics can be complete even when Rendered Evidence is limited. Six browser fixtures establish that the current dependency still differs on linear/radial units, transforms, templates, and multi-stop opacity, so this decision does not claim raster equivalence.

Patterns, external resource bundles, animation or script mutation, non-sRGB interpolation, and exact gradient rasterization remain future work.
