# Unsupported-Input Property Tests

Status: current correctness regression suite

Last verified: 2026-07-15

The central safety property is:

```text
For every generated unsupported SVG input S,
compare(S, S) must not return analysis_status = complete
with an empty atomic_differences array.
```

Self-comparison is deliberate. An unchanged unsupported feature is the easiest place to produce false equality by treating “the specialized analyzer emitted nothing” as proof that nothing visual differs. A safe result is `partial` with limiting coverage and Diagnostics, or `failed` when the document cannot be analyzed.

[`unsupported_input_property_test.mbt`](../engine/unsupported_input_property_test.mbt) deterministically enumerates families rather than relying on a random seed:

- unsupported visual elements, both direct and nested in groups;
- unsupported attributes across every currently supported basic shape;
- invalid or non-positive `viewBox`, invalid `preserveAspectRatio`, and environment-dependent or arithmetic viewport lengths; valid unitless, CSS absolute-unit, percentage, static viewport-relative, meet, slice, none, root, and nested viewport mappings have moved to focused complete-path tests;
- unsupported CSS declarations and selector/stylesheet syntax outside the admitted static grammar; type, universal, ID, class, attribute presence/equality, compound, list, and four structural combinators have moved to focused complete-path and mutation tests;
- external or context paint, malformed fallback syntax, and paint outside the admitted solid, static-gradient, static-pattern, and local URL-fallback slices; missing and wrong-kind same-document paint targets now use deterministic fallback or no-paint semantics;
- malformed `paint-order`, `fill-rule`, or `clip-rule`; valid inherited declarations use active-operation and winding-rule semantics, while rectangular clip construction is admitted separately and other contours retain precise clip Diagnostics;
- clip-path locators or resources outside one static local non-rounded rectangle with admitted units and transforms, including external, missing, wrong-kind, invalid, nested, dynamic, multi-child, curved, use-instance, or unavailable-bound cases;
- missing, external, wrong-kind, unsupported-length, or invalid-viewport `use` instances; valid bounded same-document shape, group, SVG, symbol, and nested-use targets have moved to focused complete-path tests;
- group/root compositing and effect inputs.
- malformed transform lists and invalid gradient or pattern resource transforms;
- invalid and unsupported basic-shape geometry, including negative radii, malformed or odd point lists, and environment-dependent or arithmetic lengths;
- invalid or unsupported stroke geometry, including negative widths or miter limits, invalid cap/join keywords, negative or malformed dash lists, environment-dependent or arithmetic lengths, and unsupported vector effects;
- invalid or unsupported marker attachments and resources, including missing, wrong-kind, external, malformed, environment-dependent lengths, negative sizes, invalid orientations, unresolved reference points, and visible overflow;
- renderer-conformance guards for fractional geometry, rounded rectangles, polygons, active stroke outlines/joins/dashes/non-scaling-stroke, markers, fractional leaf opacity, general affine transforms outside the integer axis slice, transformed use placement, and referenced gradient or pattern rasterization.

Every generated case also asserts that the report contains Diagnostics and at least one limited or failed coverage cell. The generator is intentionally small and reviewable; adding a supported feature requires removing or narrowing its old unsupported generator only in the same change that adds complete-path mutation coverage.

This suite is a deterministic semantic property test, not a parser fuzzing or resource-exhaustion harness. Phase 11 fuzzing and input-limit work remains separate.
