# Feature Coverage Matrix

Status: current schema `1.4` coverage map

Last verified: 2026-07-14

This matrix connects the [v1 support contract](v1-scope.md) to the Diagnostics and tests that enforce it. It is an implementation index, not an expansion of the supported scope.

## Coverage states

| State | Meaning |
| --- | --- |
| Complete-eligible | The feature can participate in a `complete` report when every other encountered semantic is also covered. |
| Partial | The engine retains independently supported evidence but emits a Diagnostic that prevents a complete conclusion. |
| Failed | The engine cannot establish a valid comparison document and returns `failed`. |
| Deferred | The feature is intentionally outside schema `1.4`; current inputs are diagnosed through a partial guard. |

Coverage is evaluated for the whole comparison. One limited feature-layer cell makes the report partial even when every other row is covered.

## Runtime matrix contract

Every current report emits `coverage_matrix`. It is the sole canonical coverage summary; consumers must not derive coverage from difference counts or maintain a competing aggregate. Each row has a stable feature ID, a report subject, one status for each canonical evidence layer, and the Diagnostic IDs that explain limitations.

| Cell status | Source Semantics | Computed Appearance | Rendered Evidence |
| --- | --- | --- | --- |
| `covered` | The encountered authored feature is within the analyzer's source claim. | The analyzer can establish the supported resolved relation. | The analyzer can establish canonical rendered evidence, including measured zero. |
| `limited` | Source enumeration or provenance is incomplete. | The resolved relation is incomplete or indeterminate. | Rendering, magnitude, or raster localization is unavailable or unproven. |
| `not_applicable` | This row makes no Source Semantics claim. | This row makes no Computed Appearance claim. | This row makes no Rendered Evidence claim. |
| `failed` | The layer could not be established because the comparison failed. | Same. | Same. |

Feature IDs use five current namespaces:

| Feature ID form | Meaning |
| --- | --- |
| `document.xml` | XML parse and document construction. |
| `subject.<kind>` | One encountered supported visual subject kind. |
| `property.<name>` | One encountered supported authored property. |
| `domain.<difference-domain>` | One emitted Atomic Difference domain. |
| `guard.<diagnostic-code>` | One encountered unsupported, deferred, or failed feature guard. |
| `resource.<dimension>` | One fixed comparison budget that was exceeded. |

Rows are deterministically ordered by feature ID and then subject ID using MoonBit `String::compare` shortlex order: shorter ASCII report keys precede longer keys, and equal-length keys compare by code unit. `analysis_status` is derived from the strongest cell: `failed` outranks `limited`, and a matrix containing only `covered` and `not_applicable` cells is `complete`. `coverage_matrix` was introduced as an optional Schema `1.0` property and remains optional for compatible legacy reports; the current Schema `1.4` engine always emits it.

The canonical production-report examples validate nonempty and unique feature/subject keys, deterministic row order, all three layer states, Diagnostic closure for every limited or failed cell, and exact `analysis_status` derivation. This end-to-end check complements the MoonBit complete, partial, failed, and proof-obligation tests.

The matrix is validated by the [Coverage Proof Obligations](coverage-proof-obligations.md) before a report may remain complete. Missing rows, unjustified cells, dangling Diagnostics, and inconsistent status summaries emit `coverage_proof_incomplete` and reduce coverage.

## Complete-eligible capabilities

| Feature slice | Evidence layers | Diagnostic on the supported path | Executable coverage |
| --- | --- | --- | --- |
| Well-formed XML, namespaces, authored values, and source spans | Source | None | [`source_adapter_wbtest.mbt`](../engine/source_adapter_wbtest.mbt): `source adapter preserves authored attribute values`, `source adapter resolves namespace-qualified element names` |
| Formatting normalization for attribute order, quoting, tag closing, entities, and declaration whitespace | Source | None | [`solid_rect_slice_test.mbt`](../engine/solid_rect_slice_test.mbt): `XML formatting variation does not create a difference`, `declaration whitespace and XML entity spelling normalize` |
| Complete path-data grammar, absolute segment normalization, and segment Source Spans | Source inventory only; does not promote path computed or rendered coverage | `unsupported_visual_subject` continues to guard the path subject | [`path_data_wbtest.mbt`](../engine/path_data_wbtest.mbt): command inventory, shorthand controls, compact syntax, XML entity offset mapping, invalid-prefix rejection, and guarded subject integration |
| Supported presentation attributes and complete supported inline declarations, including conflicts | Source, computed, rendered where the property analyzer supplies them | None | [`declared_facts_wbtest.mbt`](../engine/declared_facts_wbtest.mbt): `declared rect facts cover the supported solid slice`, `inline style overrides presentation facts and keeps exact value spans`; [`renderer_input_wbtest.mbt`](../engine/renderer_input_wbtest.mbt): order-independent red pixels; [`solid_rect_slice_test.mbt`](../engine/solid_rect_slice_test.mbt): complete equality and visual-change preservation through the adapter |
| `rect`, `circle`, `ellipse`, `line`, `polyline`, and `polygon` subject inventory | Source, computed, rendered | None | [`generic_shape_diff_test.mbt`](../engine/generic_shape_diff_test.mbt): `circle geometry uses the generic aligned-subject engine`, `ellipse line polyline and polygon share generic enumeration` |
| Integer-valued basic geometry facts for the supported shapes | Source, computed, rendered | None | [`generic_shape_diff_test.mbt`](../engine/generic_shape_diff_test.mbt): `all changed facts across aligned subjects are enumerated` |
| Supported fill, stroke, stroke width, and leaf opacity `0` or `1` facts | Source, computed, rendered where available | None | [`generic_shape_diff_test.mbt`](../engine/generic_shape_diff_test.mbt): `ordinary inherited stroke changes are reported`; [`structured_report_test.mbt`](../engine/structured_report_test.mbt): `salient paint changes retain source computed and rendered evidence`, `zero-contribution insertion retains numeric presence footprint` |
| Equivalent color spelling such as `red` and `#ff0000` | Source distinction, equivalent computed relation, measured zero rendered response | None | [`structured_report_test.mbt`](../engine/structured_report_test.mbt): `equivalent paint syntax remains a source-level difference` |
| Subject correspondence, insertion, deletion, split, and merge for supported shapes | Source and computed alignment evidence, local ambiguity, and explicit uncalibrated confidence status | None | [`alignment_test.mbt`](../engine/alignment_test.mbt): unique, exact-duplicate tie, equal-distance tie, structural, unmatched, and merge cases |
| One-owner Visual Events with Changed Fact fan-out | Agent grouping, outcome localization, and causal traceability | None | [`generic_shape_diff_test.mbt`](../engine/generic_shape_diff_test.mbt): several differences per aligned-subject event; [`inherited_fill_test.mbt`](../engine/inherited_fill_test.mbt): one Changed Fact across two independently owned events; [`validate.py`](../evaluation/determinism/validate.py): exact one-event membership for every Atomic Difference |
| Exact parameter and geometry magnitude | Computed magnitude remains continuous and separate from guarded renderer observations | None | [`magnitude_test.mbt`](../engine/magnitude_test.mbt): `tiny geometry changes retain continuous magnitude independent of pixels` |
| Presence footprint and isolated painted coverage | Computed footprint and rendered measurements | None | [`magnitude_test.mbt`](../engine/magnitude_test.mbt): insertion/deletion and isolated coverage tests |
| Same-domain lexicographic ordering | Report ordering evidence | None | [`difference_ordering_wbtest.mbt`](../engine/difference_ordering_wbtest.mbt): all v1 tuple families, missing values, and comparator direction; [`magnitude_test.mbt`](../engine/magnitude_test.mbt): descending magnitude and stable equal-tuple tie-breaking |
| Connected pixel-mask Difference Regions | Rendered | None | [`difference_region_test.mbt`](../engine/difference_region_test.mbt): `spatially disconnected pixel changes produce separate regions` |
| Conservative computed-bounds regions when raster evidence is unavailable | Computed localization | The reason that made raster evidence unavailable remains present | [`difference_region_test.mbt`](../engine/difference_region_test.mbt): `source-only inheritance uses conservative computed bounds` |
| Cause Envelopes for a complete report | Rendered region plus conservative Changed Fact candidates | None; guarantee is `sound_overapproximation` | [`cause_envelope_test.mbt`](../engine/cause_envelope_test.mbt): complete, inherited paint, disjoint region, insertion, and deletion cases |

## Guarded, partial, and failed capabilities

Renderer-specific rows also produce one encountered `renderer_capability_gaps` record with stable capability ID, support status, and all establishing Diagnostic IDs. Analyzer-owned limitations such as unsupported `path` remain visible here and in Diagnostics but do not become renderer capability gaps. Executable mapping coverage lives in [`renderer_capabilities_test.mbt`](../engine/renderer_capabilities_test.mbt).

| Feature or condition | Report status | Diagnostic code | Constrained evidence | Executable coverage |
| --- | --- | --- | --- | --- |
| Malformed XML | Failed | `svg_parse_failed` | All layers | [`structured_report_test.mbt`](../engine/structured_report_test.mbt): `parse failure is diagnosed`; [`source_adapter_wbtest.mbt`](../engine/source_adapter_wbtest.mbt): `source adapter rejects malformed XML` |
| Input, structure, materialized reference graph, transitive expansion, raster, region, or report resource budget exceeded | Failed | `resource_limit_exceeded` for ordinary budgets; `reference_expansion_limit_exceeded` for transitive `<use>` expansion | All layers | [`resource_limits_wbtest.mbt`](../engine/resource_limits_wbtest.mbt): exact and one-past tests for all ten dimensions; [`test-cli.sh`](../scripts/test-cli.sh): public failed-report exit behavior |
| Accepted local-reference graph contains a cycle | Failed | `reference_cycle_detected` | All layers | [`resource_limits_wbtest.mbt`](../engine/resource_limits_wbtest.mbt): self, multi-node, resource, nested-scope, and duplicate-ID cycles; [`validate.py`](../evaluation/adversarial/validate.py): production-CLI cycle rejection |
| Unsupported visual element, including path geometry beyond its source-only segment IR | Partial | `unsupported_visual_subject` | Computed, rendered | [`path_data_wbtest.mbt`](../engine/path_data_wbtest.mbt): normalized source inventory remains partial; [`generic_shape_diff_test.mbt`](../engine/generic_shape_diff_test.mbt): `unsupported path semantics remain partial and diagnosed` |
| Unsupported visual attribute, including `transform` in v1 | Partial | `unsupported_visual_attribute` | Source, computed, rendered | [`generic_shape_diff_test.mbt`](../engine/generic_shape_diff_test.mbt): `unsupported visual attributes reduce subject coverage` |
| Non-identity root viewport semantics (`viewBox`, including `preserveAspectRatio`) | Partial | `viewport_semantics_unsupported` | Source, computed, rendered | [`unsupported_input_property_test.mbt`](../engine/unsupported_input_property_test.mbt): unsupported attribute family property test. An identity `0 0 <profile-width> <profile-height>` viewBox is a proven no-op. |
| Stylesheet, unknown inline declaration, selector, or unsupported cascade behavior | Partial | `css_cascade_unsupported` | Source and computed; rendered conclusions are not independently promoted to complete | [`solid_rect_slice_test.mbt`](../engine/solid_rect_slice_test.mbt): `unsupported CSS reduces coverage instead of proving equality`; [`generic_shape_diff_test.mbt`](../engine/generic_shape_diff_test.mbt): `incomplete inline style cannot produce complete equality` |
| Conflicting presentation attribute and inline declaration when the inline declaration parse is incomplete | Partial | `renderer_style_precedence_unresolved` | Computed, rendered | [`renderer_input_wbtest.mbt`](../engine/renderer_input_wbtest.mbt): incomplete source is not rewritten; [`solid_rect_slice_test.mbt`](../engine/solid_rect_slice_test.mbt): `incomplete inline style retains the renderer precedence guard` |
| Fractional basic-shape geometry | Partial | `renderer_fractional_geometry_unproven` | Rendered; source/computed numeric evidence and the pinned-renderer observation remain present | [`structured_report_test.mbt`](../engine/structured_report_test.mbt): `tiny geometry changes retain continuous computed magnitude`; [`unsupported_input_property_test.mbt`](../engine/unsupported_input_property_test.mbt): renderer-conformance family property test |
| Fractional leaf opacity | Partial | `renderer_fractional_opacity_unproven` | Rendered; source/computed numeric evidence and the pinned-renderer observation remain present | [`structured_report_test.mbt`](../engine/structured_report_test.mbt): `fractional leaf opacity retains numeric evidence behind a renderer guard`; [`unsupported_input_property_test.mbt`](../engine/unsupported_input_property_test.mbt): renderer-conformance family property test |
| Group or root opacity | Partial | `group_opacity_compositing_unsupported` | Source, computed, rendered; supported source difference is retained | [`generic_shape_diff_test.mbt`](../engine/generic_shape_diff_test.mbt): group, inline group, and root opacity tests |
| Unsupported paint syntax or unresolved paint reference | Partial | `paint_value_semantics_unsupported` | Computed, rendered | [`generic_shape_diff_test.mbt`](../engine/generic_shape_diff_test.mbt): `unsupported local paint values reduce coverage` |
| Referenced paint server outside the one proven single-rect gradient slice | Partial | `paint_server_analysis_unsupported` | Source, computed, rendered | [`generic_shape_diff_test.mbt`](../engine/generic_shape_diff_test.mbt): `gradient references outside the proven slice reduce coverage` |
| Gradient semantics beyond the validated first-stop case | Partial | `gradient_semantics_unsupported` | Source, computed, rendered | [`structured_report_test.mbt`](../engine/structured_report_test.mbt): self-closing and paired later-stop guard tests |
| Referenced-gradient raster, including the narrow first-stop/single-rect slice | Partial | `renderer_gradient_raster_unproven` | Rendered; narrow source/computed analysis and the pinned-renderer observation remain present | [`structured_report_test.mbt`](../engine/structured_report_test.mbt): `resource changes and entity outcomes share one rendered event`; [`unsupported_input_property_test.mbt`](../engine/unsupported_input_property_test.mbt): renderer-conformance family property test |
| Font-dependent text analysis | Partial | `font_analysis_deferred` | Computed, rendered; source `text.content` remains reportable | [`structured_report_test.mbt`](../engine/structured_report_test.mbt): `font-dependent text analysis is explicitly deferred` |
| Inherited declaration movement requiring unresolved rendered reconstruction | Partial | `inherited_fill_rendered_evidence_deferred` | Rendered | [`inherited_fill_test.mbt`](../engine/inherited_fill_test.mbt): `moving fill to an ancestor preserves resolved fill and changes provenance` |
| Inherited value semantics not yet computed | Partial | `computed_<property>_value_semantics_deferred` | Computed | [`inherited_fill_test.mbt`](../engine/inherited_fill_test.mbt): ancestor change and provenance cases |
| Ambiguous or unsupported source-subject alignment in the inheritance analyzer | Partial | `source_subject_alignment_unsupported` | Source, computed, rendered | Covered indirectly by the inheritance analyzer fallback; add a direct regression test before treating this code as a stable public diagnostic |
| Duplicate authored IDs that prevent sound source subject identity | Partial | `duplicate_source_subject_id` | Source, computed | [`inherited_fill_wbtest.mbt`](../engine/inherited_fill_wbtest.mbt) exercises hierarchy construction; a direct report-level regression test remains required |
| No specialized analyzer can prove coverage | Partial | `analysis_coverage_unproven` | Source, computed, rendered | [`structured_report_test.mbt`](../engine/structured_report_test.mbt): unsupported-subject equality guard |
| Final analyzer output does not satisfy the coverage proof obligations | Partial | `coverage_proof_incomplete` | Source, computed, rendered | [`coverage_proof_wbtest.mbt`](../engine/coverage_proof_wbtest.mbt): missing domain and property row downgrade tests |

## Diagnostic implementation sources

- Preflight feature guards: [`structured_report.mbt`](../engine/structured_report.mbt)
- Declared fact and CSS coverage: [`declared_facts.mbt`](../engine/declared_facts.mbt)
- Inheritance-specific coverage: [`inherited_fill.mbt`](../engine/inherited_fill.mbt)
- Solid-rect fallback coverage: [`solid_rect_report.mbt`](../engine/solid_rect_report.mbt)
- Cause Envelope guarantee downgrade: [`cause_envelopes.mbt`](../engine/cause_envelopes.mbt)
- Final complete-status proof gate: [`coverage_proof.mbt`](../engine/coverage_proof.mbt)
- Resource admission and bounded failure reports: [`resource_limits.mbt`](../engine/resource_limits.mbt)

## Maintenance rule

Every new complete-eligible feature must add a positive complete-status test and a mutation test for its supported facts. Every unsupported boundary must have a stable Diagnostic and a generated negative case proving it cannot produce complete equality. When a partial row becomes complete-eligible, update this matrix, [`unsupported-input-properties.md`](unsupported-input-properties.md), [`v1-scope.md`](v1-scope.md), the relevant tests, and the roadmap in the same item commit.

The [deterministic mutation suite](../evaluation/mutations/README.md) declares and enforces the current six-kind, eighteen-property coverage set independently of report output. Adding a kind or authored property to `alignment_property_order` requires updating that contract in the same change.
