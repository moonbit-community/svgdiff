# Domain Ordering Policy

Status: current `v1_domain_lexicographic` contract

Last verified: 2026-07-14

`DomainOrdering` is a derived, versioned view over the authoritative raw `DifferenceMagnitude`. It answers only: “in what deterministic order should differences from this exact same domain be presented?” It is not a universal visual-importance score.

## V1 tuple families

Every component is nonnegative and compared in descending lexicographic order. Components use the units of their named magnitude fields without normalization or weighting.

| Exact domain family | Components, from most to least significant |
| --- | --- |
| `geometry.*` | `geometry_displacement_css_px`, `geometry_viewport_fraction`, `raster_changed_pixel_fraction` |
| `paint.*` | `raster_linear_premultiplied_rgba_rmse`, `raster_rgba8_rmse`, `raster_changed_pixel_fraction` |
| `presence`, `presence.*` | `presence_painted_viewport_fraction`, `raster_changed_pixel_fraction` |
| Current fallback: `compositing.*`, `resource.*`, `text.*`, `document.*`, and any other domain | `raster_changed_pixel_fraction`, `raster_linear_premultiplied_rgba_rmse`, `raster_rgba8_rmse` |

The table defines tuple construction, not cross-family comparability. `geometry.position` and `geometry.size` use the same construction family but remain different domains and are not numerically ranked against one another.

## Missing values and ties

An unavailable magnitude remains `null` in `DifferenceMagnitude` and is omitted from the v1 component array; it is never changed to measured zero. Policy-construction tests pin this behavior for all current families. Consumers must not infer a universal component meaning without first dispatching on the exact domain and policy ID, and should read the named raw magnitude fields rather than reverse-engineering a shortened array.

Components compare left to right. The first unequal value ranks the larger value first. When every shared component is equal, the longer tuple ranks first. When tuples are equal, the producer compares stable report-local Atomic Difference IDs in ascending lexical order. Domain groups themselves retain deterministic first-occurrence order rather than receiving an implicit cross-domain rank.

The omitted-value representation is part of v1. Any future fixed-position representation, missing-value sentinel, component reordering, direction change, domain-family reassignment, or tie-break change requires a new policy ID under the [versioning contract](versioning.md#ranking-policy-compatibility).

## Consumer procedure

1. Reject or explicitly migrate an unknown `policy_id` before using components.
2. Group by exact `AtomicDifference.domain`.
3. Compare tuples only inside one exact-domain group and one policy ID.
4. Preserve `DifferenceMagnitude` as the evidence shown to the agent; the tuple is derived ordering metadata.
5. For a question about the “main” change across domains, use an explicitly versioned Impact Assessment when one exists. Schema `1.3` has none, so report the strongest domain-specific evidence and disclose the interpretation instead of comparing tuple numbers.

[ADR 0039](adr/0039-do-not-adopt-a-universal-cross-domain-scalar.md) records that future cross-domain assessment should preserve structured evidence, ties, and incomparability instead of introducing a universal scalar without a demonstrated Agent task and calibrated policy.
