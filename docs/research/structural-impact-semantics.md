# Structural Impact Semantics

Status: implementation evidence for ISS-108

Last verified: 2026-07-15

## Boundary

SVG painting order follows the rendering tree rather than XML text in isolation. A sibling reorder matters only through the effective draw operations it changes. Parentage can also alter ordinary inheritance, selector applicability, cumulative transforms, nested viewports, instance placement, and reference-mediated outcomes. The current svgdiff slice therefore compares evaluated structural relationships, not arbitrary XML trees.

The implementation reuses the authored structure index, rendered-subject plans, one-to-one Subject Alignments, computed property comparisons, transform and viewport consequences, instance context, conservative painted bounds, and final raster evidence. It does not introduce a second tree matcher.

## Parent and instance relationships

Each rendered subject receives a private parent-path signature made from the rendered ancestry's element kinds and same-kind sibling ordinals. The subject's own segment is excluded, so a leaf sibling reorder does not look like reparenting. Authored IDs remain provenance and do not make an ID rename structural identity.

The separate instance-resolution signature distinguishes direct placement from use-mediated placement and retains the selected definition identity and nesting depth. A changed parent or instance signature becomes a Changed Fact only when the aligned subject already has a supported computed consequence. That relationship fact is then added to the consequence difference's candidate causes.

## Stacking relationships

For each pair of one-to-one aligned rendered subjects, svgdiff compares their before and after source indices. An inversion is admitted when their conservative painted bounds overlap on either side; unavailable bounds widen rather than prune. A final nonzero raster difference is required before the relationship is emitted. Disjoint reorders and overlapping reorders with identical final pixels therefore remain absent.

This establishes that the evaluated order changed and that the pair may influence the observed image. It does not establish an exact per-pixel contribution. Every admitted pair remains in the Changed Fact universe and flows through the conservative Cause Envelope fallback, which is allowed to contain false positives but may not omit the real changed cause.

## Evidence

Focused MoonBit tests cover active stacking, disjoint and equal-paint reorder controls, inherited and transformed reparenting, use-target resolution, ID renames, linked Cause Envelopes, and numeric magnitude ordering. The mutation suite carries a relationship-shaped actual-cause oracle in both directions. The adversarial suite rejects the former false complete equality. Two Chromium fixtures prove that both stacking orders are exact against the pinned renderer under conformance profile `/19`.

The unified resource graph, unsupported structural effects, source-only tree auditing, exact contribution indices, and cross-subject outcome aggregation remain outside this implementation.
