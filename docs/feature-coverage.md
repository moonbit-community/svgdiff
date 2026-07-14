# Feature Coverage Matrix

Status: current schema `1.0` coverage map

Last verified: 2026-07-14

This matrix connects the [v1 support contract](v1-scope.md) to the Diagnostics and tests that enforce it. It is an implementation index, not an expansion of the supported scope.

## Coverage states

| State | Meaning |
| --- | --- |
| Complete-eligible | The feature can participate in a `complete` report when every other encountered semantic is also covered. |
| Partial | The engine retains independently supported evidence but emits a Diagnostic that prevents a complete conclusion. |
| Failed | The engine cannot establish a valid comparison document and returns `failed`. |
| Deferred | The feature is intentionally outside schema `1.0`; current inputs are diagnosed through a partial guard. |

Coverage is evaluated for the whole comparison. One partial feature makes the report partial even when every other row is complete-eligible.

## Complete-eligible capabilities

| Feature slice | Evidence layers | Diagnostic on the supported path | Executable coverage |
| --- | --- | --- | --- |
| Well-formed XML, namespaces, authored values, and source spans | Source | None | [`source_adapter_wbtest.mbt`](../engine/source_adapter_wbtest.mbt): `source adapter preserves authored attribute values`, `source adapter resolves namespace-qualified element names` |
| Formatting normalization for attribute order, quoting, tag closing, entities, and declaration whitespace | Source | None | [`solid_rect_slice_test.mbt`](../engine/solid_rect_slice_test.mbt): `XML formatting variation does not create a difference`, `declaration whitespace and XML entity spelling normalize` |
| Supported presentation attributes and non-conflicting inline declarations | Source, computed, rendered where the property analyzer supplies them | None | [`declared_facts_wbtest.mbt`](../engine/declared_facts_wbtest.mbt): `declared rect facts cover the supported solid slice`, `inline style overrides presentation facts and keeps exact value spans` |
| `rect`, `circle`, `ellipse`, `line`, `polyline`, and `polygon` subject inventory | Source, computed, rendered | None | [`generic_shape_diff_test.mbt`](../engine/generic_shape_diff_test.mbt): `circle geometry uses the generic aligned-subject engine`, `ellipse line polyline and polygon share generic enumeration` |
| Basic geometry facts for the supported shapes | Source, computed, rendered | None | [`generic_shape_diff_test.mbt`](../engine/generic_shape_diff_test.mbt): `all changed facts across aligned subjects are enumerated` |
| Supported fill, stroke, stroke width, and leaf opacity facts | Source, computed, rendered where available | None | [`generic_shape_diff_test.mbt`](../engine/generic_shape_diff_test.mbt): `ordinary inherited stroke changes are reported`; [`structured_report_test.mbt`](../engine/structured_report_test.mbt): `salient paint changes retain source computed and rendered evidence` |
| Equivalent color spelling such as `red` and `#ff0000` | Source distinction, equivalent computed relation, measured zero rendered response | None | [`structured_report_test.mbt`](../engine/structured_report_test.mbt): `equivalent paint syntax remains a source-level difference` |
| Subject correspondence, insertion, deletion, split, and merge for supported shapes | Source and computed alignment evidence | None | [`alignment_test.mbt`](../engine/alignment_test.mbt): all alignment tests, including `a visual merge is represented set to set and serialized` |
| Exact parameter and geometry magnitude | Computed and rendered measurements remain separate | None | [`magnitude_test.mbt`](../engine/magnitude_test.mbt): `tiny geometry changes retain continuous magnitude independent of pixels` |
| Presence footprint and isolated painted coverage | Computed footprint and rendered measurements | None | [`magnitude_test.mbt`](../engine/magnitude_test.mbt): insertion/deletion and isolated coverage tests |
| Same-domain lexicographic ordering | Report ordering evidence | None | [`magnitude_test.mbt`](../engine/magnitude_test.mbt): `same-domain differences are ordered by descending magnitude` |
| Connected pixel-mask Difference Regions | Rendered | None | [`difference_region_test.mbt`](../engine/difference_region_test.mbt): `spatially disconnected pixel changes produce separate regions` |
| Conservative computed-bounds regions when raster evidence is unavailable | Computed localization | The reason that made raster evidence unavailable remains present | [`difference_region_test.mbt`](../engine/difference_region_test.mbt): `source-only inheritance uses conservative computed bounds` |
| Cause Envelopes for a complete report | Rendered region plus conservative Changed Fact candidates | None; guarantee is `sound_overapproximation` | [`cause_envelope_test.mbt`](../engine/cause_envelope_test.mbt): complete, inherited paint, disjoint region, insertion, and deletion cases |

## Guarded, partial, and failed capabilities

| Feature or condition | Report status | Diagnostic code | Constrained evidence | Executable coverage |
| --- | --- | --- | --- | --- |
| Malformed XML | Failed | `svg_parse_failed` | All layers | [`structured_report_test.mbt`](../engine/structured_report_test.mbt): `parse failure is diagnosed`; [`source_adapter_wbtest.mbt`](../engine/source_adapter_wbtest.mbt): `source adapter rejects malformed XML` |
| Unsupported visual element, including `path` in v1 | Partial | `unsupported_visual_subject` | Computed, rendered | [`generic_shape_diff_test.mbt`](../engine/generic_shape_diff_test.mbt): `unsupported path semantics remain partial and diagnosed` |
| Unsupported visual attribute, including `transform` in v1 | Partial | `unsupported_visual_attribute` | Source, computed, rendered | [`generic_shape_diff_test.mbt`](../engine/generic_shape_diff_test.mbt): `unsupported visual attributes reduce subject coverage` |
| Stylesheet, unknown inline declaration, selector, or unsupported cascade behavior | Partial | `css_cascade_unsupported` | Source and computed; rendered conclusions are not independently promoted to complete | [`solid_rect_slice_test.mbt`](../engine/solid_rect_slice_test.mbt): `unsupported CSS reduces coverage instead of proving equality`; [`generic_shape_diff_test.mbt`](../engine/generic_shape_diff_test.mbt): `incomplete inline style cannot produce complete equality` |
| Conflicting presentation attribute and inline declaration | Partial | `renderer_style_precedence_unresolved` | Computed, rendered | [`solid_rect_slice_test.mbt`](../engine/solid_rect_slice_test.mbt): `renderer style precedence conflict cannot produce complete equality` |
| Group or root opacity | Partial | `group_opacity_compositing_unsupported` | Source, computed, rendered; supported source difference is retained | [`generic_shape_diff_test.mbt`](../engine/generic_shape_diff_test.mbt): group, inline group, and root opacity tests |
| Unsupported paint syntax or unresolved paint reference | Partial | `paint_value_semantics_unsupported` | Computed, rendered | [`generic_shape_diff_test.mbt`](../engine/generic_shape_diff_test.mbt): `unsupported local paint values reduce coverage` |
| Referenced paint server outside the one proven single-rect gradient slice | Partial | `paint_server_analysis_unsupported` | Source, computed, rendered | [`generic_shape_diff_test.mbt`](../engine/generic_shape_diff_test.mbt): `gradient references outside the proven slice reduce coverage` |
| Gradient semantics beyond the validated first-stop case | Partial | `gradient_semantics_unsupported` | Source, computed, rendered | [`structured_report_test.mbt`](../engine/structured_report_test.mbt): self-closing and paired later-stop guard tests |
| Font-dependent text analysis | Partial | `font_analysis_deferred` | Computed, rendered; source `text.content` remains reportable | [`structured_report_test.mbt`](../engine/structured_report_test.mbt): `font-dependent text analysis is explicitly deferred` |
| Inherited declaration movement requiring unresolved rendered reconstruction | Partial | `inherited_fill_rendered_evidence_deferred` | Rendered | [`inherited_fill_test.mbt`](../engine/inherited_fill_test.mbt): `moving fill to an ancestor preserves resolved fill and changes provenance` |
| Inherited value semantics not yet computed | Partial | `computed_<property>_value_semantics_deferred` | Computed | [`inherited_fill_test.mbt`](../engine/inherited_fill_test.mbt): ancestor change and provenance cases |
| Ambiguous or unsupported source-subject alignment in the inheritance analyzer | Partial | `source_subject_alignment_unsupported` | Source, computed, rendered | Covered indirectly by the inheritance analyzer fallback; add a direct regression test before treating this code as a stable public diagnostic |
| Duplicate authored IDs that prevent sound source subject identity | Partial | `duplicate_source_subject_id` | Source, computed | [`inherited_fill_wbtest.mbt`](../engine/inherited_fill_wbtest.mbt) exercises hierarchy construction; a direct report-level regression test remains required |
| No specialized analyzer can prove coverage | Partial | `analysis_coverage_unproven` | Source, computed, rendered | [`structured_report_test.mbt`](../engine/structured_report_test.mbt): unsupported-subject equality guard |

## Diagnostic implementation sources

- Preflight feature guards: [`structured_report.mbt`](../engine/structured_report.mbt)
- Declared fact and CSS coverage: [`declared_facts.mbt`](../engine/declared_facts.mbt)
- Inheritance-specific coverage: [`inherited_fill.mbt`](../engine/inherited_fill.mbt)
- Solid-rect fallback coverage: [`solid_rect_report.mbt`](../engine/solid_rect_report.mbt)
- Cause Envelope guarantee downgrade: [`cause_envelopes.mbt`](../engine/cause_envelopes.mbt)

## Maintenance rule

Every new complete-eligible feature must add a positive complete-status test and a mutation test for its supported facts. Every unsupported boundary must have a stable Diagnostic and a negative test proving it cannot produce complete equality. When a partial row becomes complete-eligible, update this matrix, [`v1-scope.md`](v1-scope.md), the relevant tests, and the roadmap in the same item commit.
