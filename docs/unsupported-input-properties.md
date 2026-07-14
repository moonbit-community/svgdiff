# Unsupported-Input Property Tests

Status: current correctness regression suite

Last verified: 2026-07-14

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
- non-identity root viewport semantics (`viewBox` and its `preserveAspectRatio` behavior); identity view boxes matching the explicit Comparison Profile are a proven no-op;
- unsupported CSS declarations and stylesheets;
- unresolved paint values and paint servers;
- group/root compositing and effect inputs.
- malformed transform lists and guarded gradient/pattern resource transforms;
- renderer-conformance guards for fractional geometry, fractional leaf opacity, general affine transforms outside the integer axis slice, and the narrow referenced-gradient slice.

Every generated case also asserts that the report contains Diagnostics and at least one limited or failed coverage cell. The generator is intentionally small and reviewable; adding a supported feature requires removing or narrowing its old unsupported generator only in the same change that adds complete-path mutation coverage.

This suite is a deterministic semantic property test, not a parser fuzzing or resource-exhaustion harness. Phase 11 fuzzing and input-limit work remains separate.
