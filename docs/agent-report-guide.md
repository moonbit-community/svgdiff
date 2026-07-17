# Text-Only Agent Report Guide

Status: current schema `1.44` interpretation guide

Last verified: 2026-07-17

This guide explains how an agent without image access should turn a Structured Report into a faithful description of the SVG changes. It is a reading procedure, not a replacement for the complete JSON evidence.

The accepted [report-only language-model observation](../evaluation/language-model-benchmark/README.md) demonstrates that a pinned text-only model can recover the currently scored evidence under explicit normalized-answer rules. Those rules flatten only Atomic Difference magnitude fields; event regions, rendered outcomes, perceptual statistics, source values, and Diagnostics must not be invented as magnitude claims. The observation does not turn this guide into report evidence, relax any coverage rule below, or guarantee another model/version will produce the same answer.

When input arrives as `svgdiff-agent-projection/1` JSONL, validate its header, sequence, section counts, and source Schema identity first, then follow the same reading order across the corresponding records. The projection partitions the report but does not change field meanings or permit omitted records in a complete answer.

An optional Markdown summary may help with orientation, but it is derived and incomplete presentation. Do not use it as the evidence source for an Agent answer; resolve every statement against canonical JSON or a validated complete Agent projection.

The current report contains one renderer/profile execution and no multi-renderer matrix. Do not infer cross-browser stability, profile invariance, or renderer consensus from it. If a future [`svgdiff-renderer-experiment-matrix/1`](multi-renderer-profiles.md) accompanies reports, preserve its separate authority: use only versioned cross-cell mappings, retain every disagreeing or unavailable cell, and never extend one cell's equality or completeness to the matrix.

The current profile also never executes SVG scripts. A script Diagnostic means the realized dynamic state was not computed, even when script bytes are identical or an external browser capture shows no changed pixels. If a future [`svgdiff-script-observation/1`](script-execution-boundary.md) accompanies the report, describe its exact target and scenario separately; never turn its DOM, transcript, or pixels into canonical Atomic Differences, equality, Impact, regions, or causes.

The current profile declares no interaction checkpoint, so an unsupported `:hover`, `:focus`, or related selector is not equivalent to a false match. If future [interaction artifacts](interaction-state-profiles.md) accompany a report, distinguish requested checkpoint seeds, project-derived match state, action intent, and target-local achieved state. A failed replay, missing target, unstable hit-test loop, or different achieved postcondition is unavailable evidence, not “not hovered” or equality.

The current profile disables animation; it does not show the frame at `t = 0`. If future [animation timeline artifacts](animation-timeline-model.md) accompany a report, distinguish authored timing, generated effects, checkpoint kind, synchronization mode, requested and achieved time/state, sampled frame evidence, and interval-proof status. Matching finite samples do not mean equal animation, and effect-phase similarity does not mean same-document-time equality.

The current profile does not lay out `foreignObject`. If future [foreign-content artifacts](foreign-object-layout-boundary.md) accompany a report, distinguish the outer SVG rectangle, namespace-qualified source tree, host-language handler, computed style, layout fragments, fonts and replaced resources, isolated surface, final SVG compositing, and coverage. Unknown namespaces or missing fonts/resources are not empty content, and matching browser pixels are not canonical semantic equality.

For future [resource snapshot artifacts](general-resource-snapshot-bundles.md), distinguish authored locator, effective base and resolved request, response or failure snapshot, exact representation bytes, family interpretation, reachability, consumer result, rendered consequence, and independent acquisition provenance. Equal URLs do not imply equal side bytes; equal bytes do not imply equal interpretation; unused package members are not SVG changes; and an absent snapshot is not evidence about the live network.

These boundaries are checked together by the [M5 explicit non-goal coverage gate](../evaluation/m5-nongoal-coverage-gate/README.md). Its manifest records future identities and non-goal dispositions, not available evidence. Until a separately versioned capability is actually adopted, an Agent must treat its Diagnostic as a limit on conclusions and must not use a browser, platform, display, or cross-renderer observation to repair canonical equality, magnitude, Impact, regions, or causes.

## Reading order

Read the report in this order:

1. `schema_version`: stop or use a compatible parser if the version is unknown.
2. `analysis_status`: decide whether equality is even a permitted conclusion.
3. `profile`: state the viewport, renderer identity, and renderer conformance profile that bound the result.
4. `coverage_matrix`: identify the exact feature and evidence-layer cells that are covered, limited, not applicable, or failed.
5. `diagnostics`: explain every limited or failed coverage row.
6. `renderer_capability_gaps`: identify encountered renderer-specific limits without inferring them from Diagnostic code names.
7. `subject_alignments`: inspect selection evidence and state local ambiguity without inventing identity confidence.
8. `events`: use these as the primary navigation and localization units.
9. `atomic_differences`: explain exactly what changed and at which evidence layers.
10. `magnitude` and `domain_ordering`: quantify and order differences without inventing a universal score.
11. `difference_regions`: describe where the outcome occurs.
12. `cause_envelope`: list possible Changed Fact causes with the correct guarantee.
13. `changed_facts` and source spans: recover authored provenance when needed.

Never start by counting `atomic_differences`. A partial report with zero differences is not equality, while a complete report may contain a source distinction with zero visual effect.

Do not search Structured Report for pure accessibility descriptions, RDF payloads, or custom-data changes. They are deliberately outside visual Atomic Differences. If the caller separately supplies a `SourceAuditReport`, describe it as a source-only audit and do not merge its records into Visual Events, magnitudes, regions, or main visual changes. A selector-mediated consequence from `data-*`, `aria-*`, or an outer descriptive element remains an ordinary visual property difference and should be reported from Structured Report.

Treat `coverage_matrix` itself as the complete coverage summary. Group or filter its rows by `subject_id`, `feature_id`, or evidence-layer state when answering a question; do not infer a second summary from events, differences, or Diagnostic code names.

For every limiting or failed Diagnostic, read `source_locations` before searching the raw SVG. Each entry names the `before` or `after` input and a half-open UTF-16 offset span in that exact source. Several entries under one Diagnostic mean the same stable condition is established at several declarations or on both sides; they are not duplicate Diagnostics. An empty array means the condition is comparison-global or derived and has no honest source anchor. Legacy Schema `1.0` and `1.1` reports, and tolerated `1.2`, `1.3`, or `1.4` reports, may omit the optional field; absence means locations were not reported, not that no relevant source exists.

## Alignment evidence and uncertainty

For each referenced Subject Alignment, read `evidence` before describing the aligned subjects as corresponding. `score_kind` and `selected_score` state how the selected endpoint was evaluated; `candidate_count` and `equal_score_candidate_count` expose the local alternative set. Interpret `ambiguity` as follows:

- `unique` means only that one candidate has the selected local score;
- `tied` means the deterministic policy selected among equal local scores;
- `not_assessed` means the applicable structural or unmatched rule did not assess comparable alternatives.

Local uniqueness is not proof of authored identity or global assignment uniqueness. A deterministic tie-break is not confidence. Current reports therefore use `confidence: null` with `confidence_status: "not_calibrated"`; never derive a probability from candidate counts. Because `evidence` is additive and optional in Schema `1.1`, absence means uncertainty evidence was not reported and must not be rewritten as `unique`.

Keep alignment ambiguity separate from interpretation uncertainty. Alignment `ambiguity` describes the local correspondence-selection evidence. An Atomic Difference with `computed_relation.status: indeterminate` instead means supported semantics cannot establish equivalence or difference; follow its `diagnostic_ids` and the limited coverage cells. Do not invent a shared numeric confidence scale across these two questions.

Schema `1.44` distinguishes entity and resource alignments with `subject_role`. `use_instance_path`, transform- and bounds-aware visual signatures, and `rendered_geometry_feature_distance_v1` concern rendered entities. `resource_semantic_signature`, `resource_authored_id`, `resource_path`, and `resource_stable_kind_order` concern resource definitions; an image may have both a resource alignment for its content and an entity alignment for its placement. Every resource Atomic Difference references a resource-role alignment, but that correspondence does not prove that consumers, computed paints, or rendered pixels agree. Preserve separately reported mediated entity differences and Changed Fact fan-out.

Read `profile.perceptual_background` as display policy, not SVG content or raw-render state. Null means no background was declared and `rendered_outcome.perceptual_color` must say `not_computed/perceptual_background_absent`. With a present background and available raw event pixels, quote the recorded color, method ID, sample count, and mean DeltaEOK. The metric composites both sides over that color without changing transparent-canvas evidence. It is not a visibility boolean, JND threshold, severity label, FLIP score, or proof that the SVG authored a background.

Read `profile.flip_viewing_conditions`, `profile.flip_error_threshold`, and `rendered_outcome.perceptual_flip` together. Null Viewing Conditions mean FLIP was not requested; do not assume 67 PPD or infer display geometry. A computed map records its method, event-local pixel bounds, uint16 big-endian base64 encoding, and quantization step. Decode samples row-major only when spatial inspection is needed, map them back through `pixel_x`, `pixel_y`, `pixel_width`, and `pixel_height`, and retain Difference Regions as the causal-localization surface. Prefer the accompanying unquantized statistics for pooling: compare `canvas_mean`, `event_region_mean`, `response_p95`, and `response_maximum` with their three sample counts rather than mixing their denominators. `area_above_threshold` is null unless the profile explicitly supplies the same threshold; when present, quote both strict-above pixel count and whole-canvas fraction. The threshold is reporting policy, not a JND. The map uses the before rendering as unchanged context, so a reversed comparison may legitimately differ when surrounding events also changed. The FLIP response may extend beyond raw-different pixels because spatial and feature filters need context; that spread is not evidence of extra authored causes. Do not convert any map or statistic into an unstated visibility claim, severity label, equality decision, or Impact Assessment. Distinguish `flip_not_requested`, `perceptual_background_absent`, `rendered_evidence_unavailable`, and `perceptual_map_budget_exceeded` exactly.

The feature score is a bounded, dimensionless candidate-selection cost; a lower value means only that the selected same-kind endpoints were closer under this versioned geometry/appearance/hierarchy/path policy. `exact_visual_equivalence_class` and multi-endpoint semantic-signature alignments are sets, not ordered pairs: never zip `before` and `after`, and do not claim that matching array positions identify the same object. Weaker authored-ID, path, and stable-order rules are correspondence hints for changed subjects. Do not report any alignment evidence as visual magnitude, rendered equality, perceptual distance, calibrated confidence, or a cross-report comparable quality score. A text alignment does not remove `font_analysis_deferred`.

Interpret relation and cardinality together. An empty side is insertion or deletion; one-to-many and many-to-one sets are split and merge membership; an exact many-to-many correspondence is an equivalence class only under its recorded basis. None of these array layouts authorizes positional pairing. Mixed-change or unequal repeated clusters may remain several conservative correspondences plus presence alignments, so do not regroup them into an invented N-to-M event.

## Events and shared causes

Treat a Visual Event as one aligned-subject outcome, not as one source edit. Every Atomic Difference appears in exactly one owning event, and several differences for that outcome may share its one rendered measurement and region set. Do not add child raster magnitudes to reconstruct the event magnitude.

One Changed Fact may appear through different Atomic Differences in several events when a shared or inherited declaration affects several subjects. Describe this as one possible authored cause with multiple outcomes; do not collapse those events or report the Changed Fact several times as though it were several edits. The reverse also holds: one event may contain differences that reference several Changed Facts.

Resource and entity differences may share an event only when the resource has that sole mediated entity outcome in the current report. An unreferenced resource difference can have its own zero-rendered event, and a shared clip resource uses one resource event whose Changed Facts list every consumer. Do not infer an arbitrary entity owner for other resource fan-out or duplicate one Atomic Difference across events.

For gradients, distinguish three levels. `resource.gradient.*` domains describe the paint server itself: geometry, units, spread method, transform, and every stop. `paint.fill` or `paint.stroke` describes the computed consequence on a particular consumer. Changed Facts identify the authored gradient or template declaration and list every affected consumer ID. A direct gradient and an inherited template chain may therefore differ at the source level while producing equivalent computed paint; conversely, one resource fact may mediate several entity events. Never report one stop edit once per consumer as though it were several authored edits, and never treat `renderer_gradient_raster_unproven` as uncertainty about the already resolved static gradient parameters—it constrains only Rendered Evidence.

Apply the same separation to patterns. `resource.pattern.*` domains describe tile geometry, coordinate systems, transforms, viewport mapping, templates, and child operations; `paint.fill` or `paint.stroke` describes one consumer's resolved consequence. Child IDs appear in difference IDs and Changed Fact properties, not in the stable domain taxonomy. A resource Changed Fact lists all affected consumers, while an unreferenced pattern event can correctly have zero changed pixels. `renderer_pattern_raster_unproven` constrains only Rendered Evidence, not already resolved static pattern parameters.

For clipping, `clipping.path` is the non-inherited host attachment and `resource.clip.*` is the referenced clip definition. Treat `resource.clip.presence`, `.units`, `.transform`, `.geometry`, and `.rule` as distinct authored changes and use each Changed Fact's affected-subject list for fan-out. A rectangle effect bound is a conservative location where the clip can matter, not the exact clip mask and not a visibility boolean. A complete empty intersection contributes no side bound; the event then uses the other side's nonempty bound, if any. Read any `clip_path_*` Diagnostic before interpreting pixels: unsupported content or bounds keeps exact source and numeric findings but revokes complete rendered and causal claims.

For masking, `masking.attachment` and `masking.mode` belong to the non-inherited host, while `resource.mask.presence`, `.units`, `.type`, `.color_space`, `.transform`, `.geometry`, `.color`, and `.alpha` belong to the definition. Do not collapse these domains or turn their numeric values into visible/not-visible booleans. `alpha` mode ignores RGB-only changes; `luminance` uses sRGB channel weights times alpha; `match-source` delegates that choice to the resource `mask-type`. Use `affected_subject_ids` to explain shared-resource fan-out and the event regions to localize the union of before/after effects. A missing, wrong-kind, empty, or non-positive-region admitted mask is deterministic transparent black, not indeterminate. Any `mask_*` Diagnostic means the exact source facts remain usable but complete rendered and Cause Envelope claims do not.

For filtering, `filtering.attachment` belongs to the non-inherited host. `resource.filter.presence`, `.units`, `.region`, `.primitive.presence`, `.primitive.graph`, and `.primitive.offset` belong to the admitted definition and its ordered graph. SourceGraphic and SourceAlpha name original isolated host inputs; `__previous__` in computed values means the immediately preceding primitive; other input names refer only to earlier `result` names. Report dx/dy deltas as continuous geometric parameters, not visible/not-visible booleans. Use `affected_subject_ids` for shared-resource fan-out and per-side Difference Regions for the conservative union of translated, clipped intermediate/final bounds. A computed-equivalent spelling such as `1` versus `1.0` remains a source change with zero parameter delta. A missing or wrong-kind local target means no filter is applied, while an empty admitted graph makes the host transparent.

`resource.filter.primitive.source` is deliberately different: either the before or after primitive is unsupported, so the entire direct-child subtree is one byte-preserving source fact aligned only by position. Read `source_before` and `source_after` to identify type, attributes, nested elements, text, comments, spelling, insertion, or deletion, then use the Changed Fact's `affected_subject_ids` to name every possible consumer. A shifted sequence may yield several conservative items. Do not parse an opaque item into invented typed semantics, call formatting differences visible, assign a numeric magnitude, use its empty ordering tuple as zero, or infer pixels from the raw renderer. Its computed relation must be `indeterminate`, evidence must be source-only, rendered outcome must be `not_computed`, regions must be empty, and causal completeness is unavailable. Any `filter_*` Diagnostic keeps those exact source facts usable but forbids complete graph execution, final-pixel, or `sound_overapproximation` causal claims for the affected event.

The producer also maintains a private typed resource graph across every admitted or guarded resource family, but does not serialize unchanged topology into the report. Use `ChangedFact.affected_subject_ids`, resource and entity Atomic Differences, and Diagnostics as the graph's difference-relevant projection. Do not infer that an absent full graph means direct-only dependencies, and do not invent general clip, mask, filter-primitive, external-resource, or final image-compositing effects when their Diagnostics keep analysis partial.

Apply the [Resource Outcome Policy](resource-outcome-policy.md) before summarizing an unresolved or inactive resource. Missing and wrong-kind local paint servers may be completely resolved through a selected fallback or no-paint branch; the same states on another consumer remain partial. An unused SVG definition difference is a latent resource-source change, not a current pixel change, and should have no affected rendered-subject fan-out. An unused caller-bundle entry produces no difference because it is acquisition context rather than SVG source. Any accepted local cycle is failed admission even when no rendered consumer reaches it, so stop interpreting its difference arrays.

For embedded or explicitly bundled images, distinguish the locator representation, decoded resource, placement, and final canvas. `resource.image.source` can be computed-equivalent when data-URL and caller-bundle representations decode to identical dimensions and RGBA8 pixels. `resource.image.intrinsic_width`, `resource.image.intrinsic_height`, and `resource.image.content` describe decoded content; the last may carry `magnitude.intrinsic_raster`. Geometry, fitting, opacity, transform, insertion, and deletion remain separate differences. Never call `intrinsic_raster.changed_pixel_fraction` a viewport changed-pixel fraction: it is relative to the decoded resource and does not include scaling, clipping, overlap, or compositing. `renderer_embedded_raster_unavailable` means final-canvas Rendered Evidence is absent, while computed bounds still localize where the image may differ.

For `compositing.opacity`, interpret the numeric parameter as the non-inherited container opacity, not as opacity copied to each child. The rendered outcome comes from an isolated completed child layer; overlapping siblings therefore retain their internal top-to-bottom result before one alpha factor is applied. Its complete Cause Envelope contains the group and descendant input tokens plus every concurrent event token sharing the exact Difference Region. This preserves a changed overlapping backdrop while allowing a disjoint later subject to be pruned. It remains a sound overapproximation, not a claim that every candidate visibly contributed.

For `compositing.blend_mode` and `compositing.isolation`, treat the computed values as categories, not points on one numeric scale. Do not invent a magnitude between `multiply` and `screen`, or reduce `auto` versus `isolate` to a visibility boolean. The foreground blends against the ordered backdrop prefix inside its nearest isolation boundary; `isolate` resets that backdrop to transparent before the completed layer returns to its parent. Use `affected_subject_ids` to name the foreground and every conservatively relevant backdrop subject, and use measured pixels to describe the final response. Complete events query that operation-participant set and add concurrent event tokens sharing the exact Difference Region, so a simultaneous backdrop, isolation, or stacking change remains possible without making every comparison fact a candidate. False positives remain acceptable under `sound_overapproximation`. Any `blend_*` or `isolation_*` Diagnostic keeps exact CSS facts but revokes complete rendered and causal claims for that path.

For a paint URL with a fallback, distinguish the authored token from its selected branch. A valid local gradient or pattern makes the fallback inactive; a missing or wrong-kind local target selects the fallback, and no fallback means no paint. Report inactive fallback edits as source-visible computed equivalence. Report target-validity changes through the resulting consumer paint outcome and any resource presence facts. Only an active `currentColor` fallback should carry a color dependency; an external URL remains indeterminate rather than being described as missing.

## Interpreting one Atomic Difference

Use the independent dimensions rather than collapsing them into one label:

| Question | Field |
| --- | --- |
| What kind of thing changed? | `domain` |
| What was authored before and after? | `source_before`, `source_after`, `source_fact_before`, `source_fact_after` |
| At which layers does the distinction exist? | `evidence_layers` |
| Do the supported resolved facts agree? | `computed_relation` |
| How large is the change in meaningful units? | `magnitude` and `presence_magnitude` |
| How should same-domain items be ordered? | `domain_ordering` |
| Which event and subject does it belong to? | `subject_alignment_id` and the referencing event |

The following outcomes are deliberately different:

- source difference + computed `equivalent` + rendered zero: authored representation changed, visual meaning did not;
- computed `different` + rendered zero: visual parameters changed, but the canonical raster observation did not respond;
- computed `different` + rendered nonzero: both semantic appearance and canonical pixels changed;
- computed `indeterminate`: the engine cannot soundly decide because a Diagnostic constrains coverage;
- computed `not_applicable`: one side has no comparable fact, as in insertion or deletion.

Use this field-only decision table; do not substitute prose labels or source inspection:

| Outcome | Required report evidence |
| --- | --- |
| Supported authored representation change with no computed or rendered effect | An Atomic Difference exists, `evidence_layers` is source-only, `computed_relation.status` is `equivalent`, and the owning event has measured zero rendered magnitude. |
| Computed change with measured zero rendered response | `computed_relation.status` is `different`, while the owning event has `rendered_outcome.status: computed` and zero changed pixels and raster error. |
| Measured rendered change | The owning event has `rendered_outcome.status: computed` and at least one nonzero rendered magnitude. |
| Partial comparison | `analysis_status` is `partial`; read every limited coverage cell and referenced Diagnostic before using the retained supported evidence. |
| Failed analysis | `analysis_status` is `failed`; do not interpret the deliberately incomplete semantic inventories. |

Pure XML formatting variation is intentionally not a Visual Difference. Attribute order, quote style, tag-closing style, entity spelling, declaration whitespace, and source-offset movement alone create no Atomic Difference. Therefore an empty complete Structured Report establishes profile-scoped visual equality, but it cannot distinguish byte-identical inputs from inputs that differ only in those formatting choices. Do not claim source-byte equality from it.

`subtle`, `salient`, `major`, and similar terms are not current report outcome classes. Describe the raw measurements and uncalibrated Impact frontier instead. Human corpus tiers remain evaluation-only until a future calibrated policy satisfies the recorded prerequisites.

For transforms, keep `geometry.transform.list`, `geometry.transform.cumulative_matrix`, and the five effect domains distinct. The first identifies the authored transform declaration and may be computed-equivalent to another list; the second identifies the resulting root-to-subject affine mapping. `geometry.transform.translation`, `.rotation`, `.scale`, and `.skew` carry a tagged `magnitude.transform_effect` with before, after, and domain-specific delta fields. Translation uses CSS pixels, rotation and skew use shortest signed degree deltas, and signed X/Y scales preserve reflections. `geometry.transform.residual_matrix` retains exact coefficients when a singular linear transform has no unique finite decomposition; do not turn those coefficients into a scalar distance. These domains are separate evidence and must not be added or compared across units. Transform events select connected changed-pixel components intersecting the union of their before/after cumulative conservative painted bounds, including admitted stroke, marker, clip, and mask effects. That selection excludes disjoint scene changes but does not turn the bounds into exact continuous outlines or a contributor map.

Read `document.viewport` the same way as an authored coordinate-system cause, not as a second raster canvas. Resolve its Changed Fact to see whether `x`, `y`, `width`, `height`, `viewBox`, or `preserveAspectRatio` changed, then follow linked cumulative-matrix and typed effect differences to describe the consequence for each affected leaf. A root intrinsic `width` or `height` change can be computed-equivalent because the recorded profile still supplies one common viewport. A `preserveAspectRatio` change without a `viewBox` is likewise ignored by computed mapping. Do not hide either source distinction, and do not claim that the two inputs were rendered at different sizes.

## Magnitude and importance

Magnitude fields are evidence, not severity labels:

- `parameter_abs_user_units` and `parameter_signed_user_units` describe the canonical local scalar delta; authored spelling and units remain in the source facts;
- `parameter_abs_css_px` describes exact device-space scalar displacement only under one complete mapping shared by both sides, `parameter_viewport_fraction` divides it by the recorded viewport diagonal, and `parameter_entity_fraction` divides it by the maximum nonzero before/after entity-bounds diagonal;
- geometry displacement fields describe outcome-oriented boundary or geometry evidence and must not be substituted for exact parameter displacement;
- `painted_boundary_displacement` describes the pinned renderer's symmetric nearest-boundary pixel-center distribution; compare its mean, p95, and maximum together and retain both sample counts; mean and p95 are independent summaries, so sparse outliers can produce a positive mean with p95 equal to zero;
- `painted_coverage_difference` compares only isolated alpha coverage; retain both side areas, absolute difference, union, and fraction, and use the absolute CSS area to distinguish tiny from canvas-sized changes that both have fraction `1`;
- tagged transform-effect fields describe canonical affine component changes in their declared CSS-pixel, degree, scale, or exact-matrix units;
- presence fields describe bounds and painted footprint on the side where the subject exists;
- raster fields describe the canonical rendered response;
- null or absent fields mean not computed, not zero.

Do not infer visibility from any one parameter, boundary, or coverage field. A nonzero exact parameter value can coexist with zero painted-boundary and coverage observations or zero changed pixels, and a null contextual, boundary, or coverage field can coexist with a valid local delta when transforms conflict, isolation is unsupported, a stroke mapping is anisotropic, or entity bounds are zero or unavailable. A large boundary maximum with a much smaller mean or p95 indicates a localized outlier under nearest-boundary matching, not automatically a major visual change. A zero coverage fraction means alpha coverage is unchanged, not that visible RGB color is unchanged. Do not compare a viewport fraction with an entity fraction as if they used the same denominator, and do not turn any raw statistic into an Impact Assessment label.

Use `domain_ordering.components` only to order items from the exact same domain under the same `policy_id`; the [v2 policy](domain-ordering.md) defines component meanings and tie-breaking. For the "main" differences across domains, read the required `impact_assessment` instead. Under `event_rendered_pareto/v1`, report every frontier group, describe exact-vector groups as ties, describe distinct groups as incomparable under the policy, and disclose `partial` status or null measurements. The frontier is not a severity label or total order.

The named raw magnitude fields remain authoritative; `domain_ordering.components` is only a derived projection of those fields. Corpus categories and human annotation tiers are hidden evaluation data, not engine severity labels. The complete current and future-policy boundary is defined in [Raw Magnitudes and Impact Assessment](impact-assessment.md).

### Caller-supplied semantic concerns

Semantic importance can come from the caller even when visual magnitude is small. Start from every event and Atomic Difference, not only `impact_assessment.frontier_groups`. If caller context resolves to a report subject, event, difference, Changed Fact, source location, or region, report every matching item. A dominated match remains required; cite its domination witness to explain only why it is not a context-free main event.

The caller's statement supplies the semantic priority. An authored ID or text token may help locate a target explicitly named by the caller, but its spelling does not independently prove importance. If a phrase such as “the safety icon” cannot be mapped to report evidence, say that the target is not identifiable from this report. Do not guess, call it unimportant, or omit other differences. Missing query context means semantic importance is unknown, not low.

## Regions and possible causes

`difference_regions` localize the event outcome:

- `pixel_mask` is a connected region from canonical differing pixels;
- `computed_bounds` is a conservative semantic bound used when raster localization is unavailable;
- an empty region list is valid for source-only, computed-equivalent, unrendered, or zero-raster outcomes.

The engine computes ordinary-subject and supported-effect bounds separately for the before and after inputs, then serializes only their conservative union. Consequently a moved subject's region may cover both its vacated and occupied locations, while an insertion or deletion has only the location from the side where it exists. Do not split that union into invented side-specific pixels or treat it as an exact contribution mask.

A Cause Envelope is not a proven unique cause:

- `sound_overapproximation` means every actual changed cause is included within complete coverage, but unrelated candidates may also appear;
- `not_established` means the report does not guarantee causal completeness;
- `candidate_changed_fact_ids` should be described as possible causes, then resolved through `changed_facts` for property values and source spans.

Under complete source-input coverage, candidates include direct event facts and other Changed Facts whose analyzer-owned `affected_subject_ids` may reach the same before/after rendered subject, including a concrete use-instance identity. Resource and relationship events may conservatively span every affected consumer. Supported effect and compositing events additionally query their conservative operation participants and union concurrent event tokens sharing the exact Difference Region. This explains why a candidate can be present without being directly listed by one event's Atomic Differences; it still does not prove that the fact contributed to each pixel. Unsupported, partial, or empty-candidate paths may widen to the complete comparison fact set.

Do not rewrite "possible causes include A and B" as "A and B caused the pixels" unless a future report field explicitly proves that stronger relation.

## Worked example 1: equivalent paint spelling

Input change: `fill="red"` to `fill="#ff0000"`.

```json
{
  "analysis_status": "complete",
  "domain": "paint.fill",
  "source_before": "red",
  "source_after": "#ff0000",
  "evidence_layers": ["source_semantics"],
  "computed_relation": {
    "status": "equivalent",
    "reason_code": "same_resolved_color"
  },
  "rendered_outcome": {
    "status": "computed",
    "magnitude": {
      "changed_pixels": 0,
      "changed_pixel_fraction": 0.0
    }
  }
}
```

Correct interpretation:

> The rectangle's fill spelling changed from `red` to `#ff0000`. The values resolve to the same color and the canonical rendering has zero changed pixels, so this is an authored representation difference with no measured visual effect.

Do not say that there is no difference at all: Source Semantics intentionally preserves this distinction.

## Worked example 2: tiny numeric geometry change

Input change: rectangle `x="1.0"` to `x="0.99999"` in a `16 x 16` profile.

```json
{
  "analysis_status": "partial",
  "diagnostic": "renderer_fractional_geometry_unproven",
  "renderer_capability_gaps": [{
    "capability_id": "raster.fractional_geometry",
    "support_status": "guarded"
  }],
  "domain": "geometry.position",
  "computed_relation": { "status": "different" },
  "magnitude": {
    "parameter_signed_user_units": -0.00000999999999995449,
    "geometry_displacement_css_px": 0.00000999999999995449,
    "geometry_viewport_fraction": 4.419417382395809e-7,
    "raster_changed_pixel_fraction": 0.0625
  },
  "rendered_outcome": { "magnitude": { "changed_pixels": 16 } },
  "rendered_coverage": "limited"
}
```

Correct interpretation:

> The rectangle moved left by approximately `0.00001` CSS pixels. This is an extremely small and exact computed geometry change. The pinned renderer reports 16 edge pixels, but Rendered Evidence is limited because Chromium produces zero changed canonical pixels for this pair. Do not claim a visible outcome from the pinned count.

The pinned renderer's two edge regions remain numeric observations, but their Cause Envelopes are `not_established` and they are not browser-conformant visual regions. Retain the exact parameter magnitude, report the conformance Diagnostic, and do not use the quantized raster artifact to rank this edit as visually important.

An empty `renderer_capability_gaps` array never means that every SVG renderer feature is supported. It only means the current inputs did not encounter one of the versioned renderer-specific gaps; consult the coverage matrix for analyzer and feature limitations.

## Worked example 3: salient paint change

Input change: the `8 x 8` test rectangle changes from red to blue in a `16 x 16` viewport.

```json
{
  "analysis_status": "complete",
  "domain": "paint.fill",
  "evidence_layers": [
    "source_semantics",
    "computed_appearance",
    "rendered_evidence"
  ],
  "computed_relation": { "status": "different" },
  "magnitude": {
    "raster_changed_pixel_fraction": 0.25,
    "raster_linear_premultiplied_rgba_rmse": 0.3535533905932738
  },
  "difference_region": {
    "css_x": 2,
    "css_y": 2,
    "css_width": 8,
    "css_height": 8,
    "viewport_fraction": 0.25
  }
}
```

Correct interpretation:

> The rectangle changed fill from red to blue. The resolved paint and canonical pixels both changed. The affected region is the full `8 x 8` rectangle at `(2, 2)`, covering 25% of the comparison viewport.

This is stronger evidence of a visible outcome than example 1, but the numeric fields remain measurements rather than a built-in label such as "major".

## Worked example 4: inserted but visually non-contributing content

Input change: insert an `8 x 8` red rectangle with `opacity="0"`.

```json
{
  "analysis_status": "complete",
  "domain": "presence.insertion",
  "computed_relation": {
    "status": "not_applicable",
    "reason_code": "before_fact_absent",
    "missing_side": "before"
  },
  "presence_magnitude": {
    "affected_entity_count": 1,
    "bounds_area_css_px2": 64.0,
    "bounds_viewport_fraction": 0.25,
    "painted_area_css_px2": 0.0,
    "painted_viewport_fraction": 0.0
  },
  "rendered_outcome": { "magnitude": { "changed_pixels": 0 } }
}
```

Correct interpretation:

> One rectangle was inserted. Its geometric bounds cover 25% of the viewport, but it has zero painted coverage and produces zero changed pixels because its opacity is zero.

Do not discard the insertion and do not describe it as visible. Presence, geometric extent, painted contribution, and final raster effect are separate measurements.

## Worked example 5: text difference with partial coverage

Input change: text content `A` to `B` under an unresolved font environment.

```json
{
  "analysis_status": "partial",
  "domain": "text.content",
  "source_before": "A",
  "source_after": "B",
  "evidence_layers": ["source_semantics"],
  "computed_relation": {
    "status": "indeterminate",
    "reason_code": "font_analysis_deferred"
  },
  "rendered_outcome": {
    "status": "not_computed",
    "reason_code": "font_analysis_deferred"
  }
}
```

Correct interpretation:

> The authored text changed from `A` to `B`. Font-dependent shaping, layout, and raster impact were not computed, so the visual size, location, and perceptual importance of the text change are unknown.

Do not infer that the visual impact is zero merely because magnitude fields and Difference Regions are absent.

## Worked example 6: no reported difference under incomplete coverage

Both inputs contain the same unsupported `path`. The report contains no Atomic Differences but includes:

```json
{
  "analysis_status": "partial",
  "atomic_differences": [],
  "diagnostics": [
    { "code": "analysis_coverage_unproven" },
    { "code": "unsupported_visual_subject", "subject_id": "path" }
  ]
}
```

Correct interpretation:

> No difference was established by the guarded path comparison, but complete path semantics were not analyzed. The report cannot establish visual equality.

This is the critical counterexample to treating an empty difference list as equality.

When normalized path geometry does change, the same partial report may contain `geometry.path.parameter`, `geometry.path.command`, or `geometry.path.structure` Atomic Differences. Treat exact parameter deltas as reliable normalized source-geometry evidence. Treat `geometry_displacement_css_px`, when present, as the bounded isolated alpha-boundary maximum distance under the pinned renderer, not as continuous geometric Hausdorff distance or browser-conformant visibility. Continue to surface `unsupported_visual_subject`: the findings identify established differences but do not make the path analysis complete.

## Recommended agent response shape

Use a compact response with four sections:

```text
Coverage
- status, profile, and any limiting Diagnostics

Main outcomes
- event, affected subject, domain, before/after meaning, magnitude, and region

Other semantic differences
- computed-equivalent, zero-contribution, source-only, or lower-ranked same-domain items

Possible causes and uncertainty
- Cause Envelope candidates, guarantee, and unresolved evidence layers
```

Keep every claim traceable to report IDs. If summarization omits lower-priority items, state the number omitted and retain their IDs so the complete report remains navigable.

Cache hits, misses, lookup time, and storage provenance are not visual evidence or Impact signals. The current product has no persistent cache. If an embedding layer later returns a validated exact-result artifact, interpret the retained profile, status, coverage, evidence, and Diagnostics exactly as a cold report; cache provenance cannot upgrade or weaken them.

## Validation sources

Machine-readable, production-generated versions of the core worked-example categories live in the [Structured Report examples](../schema/examples/README.md). They are regenerated from curated SVG inputs and checked against the current Schema and semantic manifest; use them when testing a consumer instead of copying abbreviated snippets from this guide.

The numeric extracts above come from the current CLI and are asserted by [`structured_report_test.mbt`](../engine/structured_report_test.mbt), [`magnitude_test.mbt`](../engine/magnitude_test.mbt), and [`generic_shape_diff_test.mbt`](../engine/generic_shape_diff_test.mbt). The salient paint fixture is checked in as [`testdata/before.svg`](../testdata/before.svg) and [`testdata/after.svg`](../testdata/after.svg).
