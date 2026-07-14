# Text-Only Agent Report Guide

Status: current schema `1.0` interpretation guide

Last verified: 2026-07-14

This guide explains how an agent without image access should turn a Structured Report into a faithful description of the SVG changes. It is a reading procedure, not a replacement for the complete JSON evidence.

## Reading order

Read the report in this order:

1. `schema_version`: stop or use a compatible parser if the version is unknown.
2. `analysis_status`: decide whether equality is even a permitted conclusion.
3. `profile`: state the viewport and pinned rendering conditions that bound the result.
4. `diagnostics`: identify evidence layers that are unavailable or indeterminate.
5. `events`: use these as the primary navigation and localization units.
6. `atomic_differences`: explain exactly what changed and at which evidence layers.
7. `magnitude` and `domain_ordering`: quantify and order differences without inventing a universal score.
8. `difference_regions`: describe where the outcome occurs.
9. `cause_envelope`: list possible Changed Fact causes with the correct guarantee.
10. `changed_facts` and source spans: recover authored provenance when needed.

Never start by counting `atomic_differences`. A partial report with zero differences is not equality, while a complete report may contain a source distinction with zero visual effect.

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

## Magnitude and importance

Magnitude fields are evidence, not severity labels:

- parameter and geometry fields describe exact or device-space displacement;
- presence fields describe bounds and painted footprint on the side where the subject exists;
- raster fields describe the canonical rendered response;
- null or absent fields mean not computed, not zero.

Use `domain_ordering.components` only to order items from the same domain under the same `policy_id`. Schema `1.0` does not define a universal cross-domain importance score. When asked for the "main" difference across domains, describe the strongest directly supported evidence and state that the cross-domain choice is an interpretation rather than an intrinsic numeric comparison.

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
  "analysis_status": "complete",
  "domain": "geometry.position",
  "computed_relation": { "status": "different" },
  "magnitude": {
    "parameter_signed_user_units": -0.00000999999999995449,
    "geometry_displacement_css_px": 0.00000999999999995449,
    "geometry_viewport_fraction": 4.419417382395809e-7,
    "raster_changed_pixel_fraction": 0.0625
  },
  "rendered_outcome": { "magnitude": { "changed_pixels": 16 } }
}
```

Correct interpretation:

> The rectangle moved left by approximately `0.00001` CSS pixels. This is an extremely small computed geometry change. Under the pinned rasterizer it changed 16 edge pixels, but the raster count must not be used to exaggerate the underlying displacement.

The two reported pixel regions lie on the vacated and occupied vertical edges. Their Cause Envelopes contain the changed `x` fact. The exact parameter magnitude and the quantized raster response answer different questions and must both be retained.

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

> No difference was established in the supported analyzer, but path semantics were not analyzed. The report cannot establish visual equality.

This is the critical counterexample to treating an empty difference list as equality.

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

The numeric extracts above come from the current CLI and are asserted by [`structured_report_test.mbt`](../engine/structured_report_test.mbt), [`magnitude_test.mbt`](../engine/magnitude_test.mbt), and [`generic_shape_diff_test.mbt`](../engine/generic_shape_diff_test.mbt). The salient paint fixture is checked in as [`testdata/before.svg`](../testdata/before.svg) and [`testdata/after.svg`](../testdata/after.svg).
