# Text-Only Agent Report Guide

Status: current schema `1.12` interpretation guide

Last verified: 2026-07-14

This guide explains how an agent without image access should turn a Structured Report into a faithful description of the SVG changes. It is a reading procedure, not a replacement for the complete JSON evidence.

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

Treat `coverage_matrix` itself as the complete coverage summary. Group or filter its rows by `subject_id`, `feature_id`, or evidence-layer state when answering a question; do not infer a second summary from events, differences, or Diagnostic code names.

For every limiting or failed Diagnostic, read `source_locations` before searching the raw SVG. Each entry names the `before` or `after` input and a half-open UTF-16 offset span in that exact source. Several entries under one Diagnostic mean the same stable condition is established at several declarations or on both sides; they are not duplicate Diagnostics. An empty array means the condition is comparison-global or derived and has no honest source anchor. Legacy Schema `1.0` and `1.1` reports, and tolerated `1.2`, `1.3`, or `1.4` reports, may omit the optional field; absence means locations were not reported, not that no relevant source exists.

## Alignment evidence and uncertainty

For each referenced Subject Alignment, read `evidence` before describing the aligned subjects as corresponding. `score_kind` and `selected_score` state how the selected endpoint was evaluated; `candidate_count` and `equal_score_candidate_count` expose the local alternative set. Interpret `ambiguity` as follows:

- `unique` means only that one candidate has the selected local score;
- `tied` means the deterministic policy selected among equal local scores;
- `not_assessed` means the applicable structural or unmatched rule did not assess comparable alternatives.

Local uniqueness is not proof of authored identity or global assignment uniqueness. A deterministic tie-break is not confidence. Current reports therefore use `confidence: null` with `confidence_status: "not_calibrated"`; never derive a probability from candidate counts. Because `evidence` is additive and optional in Schema `1.1`, absence means uncertainty evidence was not reported and must not be rewritten as `unique`.

## Events and shared causes

Treat a Visual Event as one aligned-subject outcome, not as one source edit. Every Atomic Difference appears in exactly one owning event, and several differences for that outcome may share its one rendered measurement and region set. Do not add child raster magnitudes to reconstruct the event magnitude.

One Changed Fact may appear through different Atomic Differences in several events when a shared or inherited declaration affects several subjects. Describe this as one possible authored cause with multiple outcomes; do not collapse those events or report the Changed Fact several times as though it were several edits. The reverse also holds: one event may contain differences that reference several Changed Facts.

Resource and entity differences may share an event only when the resource has that sole mediated entity outcome in the current report. An unreferenced resource difference can have its own zero-rendered event. Do not infer an arbitrary entity owner for future resource fan-out or duplicate one Atomic Difference across events.

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

For transforms, keep `geometry.transform.list`, `geometry.transform.cumulative_matrix`, and the five effect domains distinct. The first identifies the authored transform declaration and may be computed-equivalent to another list; the second identifies the resulting root-to-subject affine mapping. `geometry.transform.translation`, `.rotation`, `.scale`, and `.skew` carry a tagged `magnitude.transform_effect` with before, after, and domain-specific delta fields. Translation uses CSS pixels, rotation and skew use shortest signed degree deltas, and signed X/Y scales preserve reflections. `geometry.transform.residual_matrix` retains exact coefficients when a singular linear transform has no unique finite decomposition; do not turn those coefficients into a scalar distance. These domains are separate evidence and must not be added or compared across units. Transform events currently use the complete scene pixel mask because ordinary subject bounds are not transform-aware; this is a conservative localization, not a claim that every returned region belongs only to that subject.

Read `document.viewport` the same way as an authored coordinate-system cause, not as a second raster canvas. Resolve its Changed Fact to see whether `x`, `y`, `width`, `height`, `viewBox`, or `preserveAspectRatio` changed, then follow linked cumulative-matrix and typed effect differences to describe the consequence for each affected leaf. A root intrinsic `width` or `height` change can be computed-equivalent because the recorded profile still supplies one common viewport. A `preserveAspectRatio` change without a `viewBox` is likewise ignored by computed mapping. Do not hide either source distinction, and do not claim that the two inputs were rendered at different sizes.

## Magnitude and importance

Magnitude fields are evidence, not severity labels:

- parameter and geometry fields describe exact or device-space displacement;
- tagged transform-effect fields describe canonical affine component changes in their declared CSS-pixel, degree, scale, or exact-matrix units;
- presence fields describe bounds and painted footprint on the side where the subject exists;
- raster fields describe the canonical rendered response;
- null or absent fields mean not computed, not zero.

Use `domain_ordering.components` only to order items from the exact same domain under the same `policy_id`; the [v2 policy](domain-ordering.md) defines component meanings and tie-breaking. Schema `1.12` does not define a universal cross-domain importance score. When asked for the "main" difference across domains, describe the strongest directly supported evidence and state that the cross-domain choice is an interpretation rather than an intrinsic numeric comparison.

The named raw magnitude fields remain authoritative; `domain_ordering.components` is only a derived projection of those fields. Corpus categories and human annotation tiers are hidden evaluation data, not engine severity labels. The complete current and future-policy boundary is defined in [Raw Magnitudes and Impact Assessment](impact-assessment.md).

## Regions and possible causes

`difference_regions` localize the event outcome:

- `pixel_mask` is a connected region from canonical differing pixels;
- `computed_bounds` is a conservative semantic bound used when raster localization is unavailable;
- an empty region list is valid for source-only, computed-equivalent, unrendered, or zero-raster outcomes.

A Cause Envelope is not a proven unique cause:

- `sound_overapproximation` means every actual changed cause is included within complete coverage, but unrelated candidates may also appear;
- `not_established` means the report does not guarantee causal completeness;
- `candidate_changed_fact_ids` should be described as possible causes, then resolved through `changed_facts` for property values and source spans.

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

## Validation sources

Machine-readable, production-generated versions of the core worked-example categories live in the [Structured Report examples](../schema/examples/README.md). They are regenerated from curated SVG inputs and checked against the current Schema and semantic manifest; use them when testing a consumer instead of copying abbreviated snippets from this guide.

The numeric extracts above come from the current CLI and are asserted by [`structured_report_test.mbt`](../engine/structured_report_test.mbt), [`magnitude_test.mbt`](../engine/magnitude_test.mbt), and [`generic_shape_diff_test.mbt`](../engine/generic_shape_diff_test.mbt). The salient paint fixture is checked in as [`testdata/before.svg`](../testdata/before.svg) and [`testdata/after.svg`](../testdata/after.svg).
