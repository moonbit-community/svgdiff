# Coverage Proof Obligations

Status: enforced engine contract

Last verified: 2026-07-14

No analyzer may contribute a `complete` Structured Report merely by returning `analysis_status: "complete"`. Every analyzer result passes through one engine-owned proof gate after alignment, regions, Cause Envelopes, magnitudes, and feature coverage have been attached.

## Obligations

The final report must satisfy all of the following:

1. The coverage matrix is nonempty and contains `document.xml` for `document`.
2. Every coverage cell uses `covered`, `limited`, `not_applicable`, or `failed`.
3. Every `limited` or `failed` cell is justified by a referenced Diagnostic that constrains that exact evidence layer.
4. Every referenced Diagnostic exists, every report Diagnostic is referenced by at least one row, and every affected evidence layer is witnessed by a limited or failed cell.
5. Every encountered supported subject and every explicitly authored supported property has a matching `subject.*` or `property.*` row.
6. Every subject in Subject Alignment has a matching subject coverage row.
7. Every Atomic Difference has a `domain.*` row for its event subject.
8. A computed `indeterminate` relation has a limited Computed Appearance cell; unavailable rendered evidence has a limited Rendered Evidence cell.
9. `analysis_status` equals the summary of the matrix: failed cells produce `failed`, otherwise limited cells produce `partial`, otherwise the result is `complete`.

These obligations establish conservative coverage bookkeeping, not browser conformance or semantic completeness for a feature. A feature may be marked `covered` only within the implemented support contract and pinned Comparison Profile.

## Failure behavior

If any obligation fails, the gate emits one or more `coverage_proof_incomplete` Diagnostics, adds a guard row limiting all three evidence layers, and prevents `complete`. Failure identifiers name the violated obligation so tests and maintainers can locate the missing declaration. The gate never invents missing evidence or converts an unavailable measurement to zero.

The proof gate is centralized behind the engine module interface. Individual analyzers construct their normal report slices; callers and tests observe only the validated final Structured Report.
