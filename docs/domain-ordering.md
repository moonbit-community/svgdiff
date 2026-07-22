# Domain Ordering Policy

Status: current `v2_domain_lexicographic` contract

Last verified: 2026-07-16

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
| `resource.image.content` | `intrinsic_raster.linear_premultiplied_rgba_rmse`, `intrinsic_raster.rgba8_rmse`, `intrinsic_raster.changed_pixel_fraction` |
| Current fallback: `compositing.*`, `resource.*`, `text.*`, `document.*`, and any other domain | `raster_changed_pixel_fraction`, `raster_linear_premultiplied_rgba_rmse`, `raster_rgba8_rmse` |

The five exact transform rows take precedence over the broader `geometry.*` fallback, and `resource.image.content` takes precedence over the broad resource fallback. Their leading components retain deliberately different units: CSS pixels, degrees, a unitless scale delta, or normalized pixel error. The table defines tuple construction, not cross-family comparability. `geometry.position` and `geometry.size` use the same construction family but remain different domains and are not numerically ranked against one another. For guarded `geometry.path.*` differences, `geometry_displacement_css_px` is the optional isolated alpha-boundary maximum distance shared by that aligned path comparison; the exact normalized parameter delta remains separately available in `parameter_abs` and `parameter_symmetric_relative`.

`resource.filter.primitive.source` has no computed magnitude by design. Its v2 component array is therefore empty, not a measured zero or evidence that two opaque changes are equally important. Stable difference-ID tie-breaking provides deterministic presentation within that exact domain without inventing an ordering signal.

## Missing values and ties

An unavailable magnitude remains `null` in `DifferenceMagnitude` and is omitted from the v2 component array; it is never changed to measured zero. Policy-construction tests pin this behavior for all current families. Consumers must not infer a universal component meaning without first dispatching on the exact domain and policy ID, and should read the named raw magnitude fields rather than reverse-engineering a shortened array.

Schema `1.36` added exact `parameter_abs_css_px`, `parameter_viewport_fraction`, and `parameter_entity_fraction` raw fields without adding them to v2 tuples. Schema `1.37` likewise added `painted_boundary_displacement`, and Schema `1.38` adds `painted_coverage_difference`, without changing tuple construction. This preserves the accepted ordering identity: the new measurements are available for direct Agent explanation and future calibrated policy work, while existing domain tuples continue to use their established geometry and raster components.

Components compare left to right. The first unequal value ranks the larger value first. When every shared component is equal, the longer tuple ranks first. When tuples are equal, the producer compares stable report-local Atomic Difference IDs in ascending lexical order. Domain groups themselves retain deterministic first-occurrence order rather than receiving an implicit cross-domain rank.

The omitted-value representation is part of v2. Any future fixed-position representation, missing-value sentinel, component reordering, direction change, domain-family reassignment, or tie-break change requires a new policy ID under the [versioning contract](versioning.md#ranking-policy-compatibility).

Policy `v1_domain_lexicographic` remains valid only for legacy reports through Schema `1.5`. Its broad `geometry.*` tuple had no transform-component leading fields. Consumers must dispatch on `policy_id`; they must not reinterpret a v1 component vector using this v2 table.

## Consumer procedure

1. Reject or explicitly migrate an unknown `policy_id` before using components.
2. Group by exact `AtomicDifference.domain`.
3. Compare tuples only inside one exact-domain group and one policy ID.
4. Preserve `DifferenceMagnitude` as the evidence shown to the agent; the tuple is derived ordering metadata.
5. For a question about the “main” change across domains, Schema `1.46` supplies no universal ordering. Report the independent measurements and ask for a caller concern or policy rather than comparing unlike tuple components.

[ADR 0039](adr/0039-do-not-adopt-a-universal-cross-domain-scalar.md) records that future cross-domain assessment should preserve structured evidence, ties, and incomparability instead of introducing a universal scalar without a demonstrated Agent task and calibrated policy.
