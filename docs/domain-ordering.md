# Domain Ordering Policy

Status: current `v2_domain_lexicographic` contract

Last verified: 2026-07-14

`DomainOrdering` is a derived, versioned view over the authoritative raw `DifferenceMagnitude`. It answers only: “in what deterministic order should differences from this exact same domain be presented?” It is not a universal visual-importance score.

## V2 tuple families

Every component is nonnegative and compared in descending lexicographic order. Components use the units of their named magnitude fields without normalization or weighting.

| Exact domain family | Components, from most to least significant |
| --- | --- |
| `geometry.transform.translation` | `transform_effect.translation.norm_css_px`, `geometry_viewport_fraction`, `raster_changed_pixel_fraction` |
| `geometry.transform.rotation` | `transform_effect.rotation.abs_delta_degrees`, `raster_changed_pixel_fraction` |
| `geometry.transform.scale` | `transform_effect.scale.max_abs_delta`, `raster_changed_pixel_fraction` |
| `geometry.transform.skew` | `transform_effect.skew.abs_delta_degrees`, `raster_changed_pixel_fraction` |
| `geometry.transform.residual_matrix` | `raster_changed_pixel_fraction` |
| `geometry.*` | `geometry_displacement_css_px`, `geometry_viewport_fraction`, `raster_changed_pixel_fraction` |
| `paint.*` | `raster_linear_premultiplied_rgba_rmse`, `raster_rgba8_rmse`, `raster_changed_pixel_fraction` |
| `presence`, `presence.*` | `presence_painted_viewport_fraction`, `raster_changed_pixel_fraction` |
| Current fallback: `compositing.*`, `resource.*`, `text.*`, `document.*`, and any other domain | `raster_changed_pixel_fraction`, `raster_linear_premultiplied_rgba_rmse`, `raster_rgba8_rmse` |

The five exact transform rows take precedence over the broader `geometry.*` fallback. Their leading components retain deliberately different units: CSS pixels, degrees, or a unitless scale delta. The table defines tuple construction, not cross-family comparability. `geometry.position` and `geometry.size` use the same construction family but remain different domains and are not numerically ranked against one another. For guarded `geometry.path.*` differences, `geometry_displacement_css_px` is the optional isolated alpha-boundary maximum distance shared by that aligned path comparison; the exact normalized parameter delta remains separately available in `parameter_abs` and `parameter_symmetric_relative`.

## Missing values and ties

An unavailable magnitude remains `null` in `DifferenceMagnitude` and is omitted from the v2 component array; it is never changed to measured zero. Policy-construction tests pin this behavior for all current families. Consumers must not infer a universal component meaning without first dispatching on the exact domain and policy ID, and should read the named raw magnitude fields rather than reverse-engineering a shortened array.

Components compare left to right. The first unequal value ranks the larger value first. When every shared component is equal, the longer tuple ranks first. When tuples are equal, the producer compares stable report-local Atomic Difference IDs in ascending lexical order. Domain groups themselves retain deterministic first-occurrence order rather than receiving an implicit cross-domain rank.

The omitted-value representation is part of v2. Any future fixed-position representation, missing-value sentinel, component reordering, direction change, domain-family reassignment, or tie-break change requires a new policy ID under the [versioning contract](versioning.md#ranking-policy-compatibility).

Policy `v1_domain_lexicographic` remains valid only for legacy reports through Schema `1.5`. Its broad `geometry.*` tuple had no transform-component leading fields. Consumers must dispatch on `policy_id`; they must not reinterpret a v1 component vector using this v2 table.

## Consumer procedure

1. Reject or explicitly migrate an unknown `policy_id` before using components.
2. Group by exact `AtomicDifference.domain`.
3. Compare tuples only inside one exact-domain group and one policy ID.
4. Preserve `DifferenceMagnitude` as the evidence shown to the agent; the tuple is derived ordering metadata.
5. For a question about the “main” change across domains, use an explicitly versioned Impact Assessment when one exists. Schema `1.11` has none, so report the strongest domain-specific evidence and disclose the interpretation instead of comparing tuple numbers.

[ADR 0039](adr/0039-do-not-adopt-a-universal-cross-domain-scalar.md) records that future cross-domain assessment should preserve structured evidence, ties, and incomparability instead of introducing a universal scalar without a demonstrated Agent task and calibrated policy.
