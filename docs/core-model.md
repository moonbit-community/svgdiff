# Core Comparison Model

Status: proposed

This document defines the core abstraction for SVG difference analysis. Presentation formats, including HTML, are outside its scope.

## External seam

The comparison engine is one deep module with one conceptual operation:

```text
compare(before_svg, after_svg, comparison_profile) -> structured_report
```

Callers provide two SVG artifacts and a comparison profile. They do not orchestrate parsing, style resolution, visual correspondence, difference extraction, rendering, scoring, or aggregation.

## Core scope

The initial correctness claim covers Deterministic Static SVG under declared rendering conditions and pinned resources. Unsupported dynamic behavior or unresolved environmental state reduces Analysis Coverage through Diagnostics; it is never silently interpreted as equality. The detailed inclusion and deferral list lives in [`v1-scope.md`](v1-scope.md).

Font resolution, shaping, font-dependent layout, and glyph raster evidence are explicit core v1 TODOs. Text Source Semantics remain reportable, but font-dependent Computed Appearance and Rendered Evidence reduce Analysis Coverage through Diagnostics until that capability is implemented.

## Model overview

```text
SVG artifacts
    │
    ├── Source Semantics ───────────────────────────────┐
    │                                                   │
    └── Computed Appearance ── Visual Subjects          │
                              │                         │
                              └── Subject Alignments    │
                                      │                 │
                                      └── Atomic Differences
                                              │
Render Observations ── Rendered Evidence       │
        │                    │                 │
        └── Contribution Index                │
                             └── Visual Impact ┤
                                              │
                                              └── Visual Events
                                                      │
                                                      └── Structured Report
```

The engine maintains source, computed, and rendered facts separately. No single layer is allowed to stand in for the other two.

## Core records

### SVG Artifact

One comparison input. It carries the original content, a content hash, and input metadata required to identify the analyzed artifact.

### Comparison Profile

The explicit assumptions under which comparison occurs. It defines normalization policy, feature support, and one declared rendering environment including the Comparison Viewport, Comparison DPR, optional Perceptual Background, Comparison Color Space, fonts, resources, and renderer identity. Diagnostic rerendering at alternate scales is an internal validation technique and is not part of the canonical Comparison Profile or Structured Report.

The Comparison Viewport is resolved before Rendered Evidence is produced. An explicitly supplied viewport is used for both inputs. When it is omitted, the engine may derive it only when both SVGs declare the same valid intrinsic viewport; differing, missing, or invalid declarations require an explicit viewport. The engine never renders the two inputs under independent viewports and presents the resulting pixels as directly comparable. Changes to the SVGs' own viewport declarations remain reportable as `document.viewport` Atomic Differences even when rendering uses an explicit common viewport.

Raw raster evidence is always measured as linear premultiplied RGBA on a transparent canvas. A Perceptual Background, when explicitly declared, is used to composite both raw renderings before calculating display-dependent perceptual metrics such as FLIP. The core engine never silently assumes white or another background. When no Perceptual Background is declared, those metrics are marked `not_computed` with reason `perceptual_background_absent`; geometry, coverage, alpha, and raw premultiplied-RGBA measurements remain available and Analysis Coverage is not reduced merely because an optional interpretation was not requested.

The Comparison DPR is one positive finite value shared by both inputs and defaults to `1.0` when omitted. Its effective value is recorded in the Structured Report. It determines only the canonical raster dimensions and response under the Comparison Profile; exact Computed Appearance measurements preserve subpixel distinctions independently of DPR, and alternate-scale or supersampled rerendering remains renderer QA rather than canonical evidence.

The Comparison Color Space defaults SVG and CSS color interpretation to sRGB. Raster blending, comparison, RMSE, and related numeric measurements use linear-sRGB premultiplied RGBA, and the Structured Report records both the color interpretation and numeric representation. Core v1 does not silently map embedded ICC profiles, Display-P3, or other wide-gamut content into sRGB; affected computed or rendered conclusions are accompanied by unsupported-feature Diagnostics and reduced Analysis Coverage.

### Visual Subject

Any reportable subject with visual semantics. A Visual Subject has one of two roles:

- Visual Entity: placed, geometric, or instantiated scene content;
- Visual Resource: a definitional or supplied resource such as a gradient, filter, clip path, mask, symbol, image asset, or font.

Both roles have report-local identity, source provenance, Computed Appearance facts when available, and a Visual Contribution that may be zero. A resource may contribute indirectly through dependent entities; an unreferenced resource remains reportable at Source Semantics with zero contribution.

### Visual Entity

A Visual Subject with scene placement, geometry, or an instantiated visual role. It has resolved visual properties, spatial extent when available, and compositing relationships. Membership does not require non-zero pixels: opacity, display, clipping, masking, or compositing may reduce its Visual Contribution under the Comparison Profile to zero.

### Visual Resource

A Visual Subject that supplies or defines appearance without itself being a placed entity. Changes to referenced resources remain separate Atomic Differences from the resulting entity paint or compositing changes; unreferenced resource changes remain source-level resource Differences with zero Visual Contribution.

Pure Nonvisual Metadata such as accessibility descriptions and custom data attributes may remain available as input provenance but does not become a Visual Subject or Atomic Difference. The comparison contract is exhaustive over visual semantics, not every XML or metadata mutation.

### Visual Contribution

The continuous direct or mediated coverage, color, raster, and perceptual contribution of a Visual Subject under the Comparison Profile. A zero contribution is a measured result, not a reason to discard the subject or convert its differences into equality.

### Render Observation

A rendering-derived observation under the Comparison Profile. It contains final color, coverage, perceptual measurements, and a Contribution Index that relates sampled regions back to the Visual Subjects that contributed directly or through dependency paths; it is richer than a screenshot and does not replace Computed Appearance.

### Subject Alignment

A set-to-set relationship between Visual Subjects from the two inputs. Empty and non-empty sides represent insertion and deletion; non-empty sides represent one-to-one correspondence, splitting, merging, or many-to-many reorganization. Each accepted Subject Alignment records its subject role, supporting evidence, and confidence, while ambiguous alternatives remain candidates rather than accepted facts.

### Atomic Difference

The smallest independently reportable semantic change. It identifies what changed, the affected Subject Alignment, its before and after facts, the evidence layers at which it exists, its visual impact, and the confidence of the conclusion.

### Visual Event

A coherent, layered change explanation that groups related Atomic Differences around one visual outcome. Event boundaries follow outcome coherence rather than shared cause alone: one resource change may participate in multiple Events when it produces independent outcomes, while each Atomic Difference remains stored once and may be referenced by multiple Events. A Visual Event is the primary unit for an agent to read; its Atomic Differences remain the complete source and computed evidence, while the final rendered measurements are computed once over the union of the Event's Difference Regions. Group membership does not establish an exact causal edge: causal candidates remain expressed through conservative Influence Provenance and Cause Envelopes.

Core v1 uses a deliberately narrower construction rule: every Visual Event has exactly one Primary Subject Alignment, and it groups the Atomic Differences attached to that alignment. Related resource Differences may be referenced as context, but v1 does not merge Events whose primary alignments differ. An Event Rendered Outcome may contain multiple disconnected regions; no spatial-connectivity or cross-subject coherence inference is required.

### Event Rendered Outcome

The union of rendered Difference Regions associated with one Visual Event under the Comparison Profile. It is measured once as continuous coverage, raster, color, and perceptual evidence regardless of the number of related Atomic Differences. It may be empty or have zero-valued measurements when the Event exists only at Source Semantics or Computed Appearance.

### Diagnostic

A first-class statement that some part of the comparison is unsupported, ambiguous, missing an external resource, or otherwise indeterminate. Diagnostics constrain the claims that may safely be made from the report.

### Influence Provenance

A conservative may-depend graph that propagates Changed Fact tokens through computed and rendered operations. It exists to preserve Causal Completeness and deliberately does not claim exact contribution weights.

### Cause Envelope

The Changed Facts that may cause one Difference Region according to Influence Provenance from both inputs. A complete Cause Envelope contains every actual changed cause and may contain false positives; unknown operations widen the envelope rather than pruning candidates.

### Structured Report

The complete result returned by the comparison module. It contains inputs, the comparison profile, analysis status, summary, Visual Subjects, Subject Alignments, Visual Events, Atomic Differences, and diagnostics.

## Orthogonal difference dimensions

Every Atomic Difference is classified along independent dimensions. These dimensions must not be collapsed into one `type` or one score.

### Difference Domain: what changed

Every Atomic Difference has one Domain and may use a more specific subdomain. The top-level taxonomy is:

- presence: insertion or deletion;
- geometry: position, size, shape, or transform;
- paint: fill, stroke, opacity, or color;
- text: content, font properties, shaping, or layout;
- compositing: order, clipping, masking, filtering, or blending;
- resource: an image, font, paint server, symbol, or other referenced content;
- document: viewport or other whole-document visual semantics.

Representation and visibility are not Domains. Authored representation is expressed through Source Semantics plus Computed Relation; rendered contribution is expressed through continuous Rendered Evidence. The exact subdomain taxonomy remains provisional and must be tested against concrete SVG cases.

### Computed Relation: whether resolved facts agree

Every Atomic Difference records one relation between its before and after Computed Appearance facts:

- equivalent: the authored distinction resolves to the same computed visual fact;
- different: the resolved visual facts differ;
- indeterminate: coverage or ambiguity prevents a sound conclusion;
- not_applicable: one side has no computed fact to compare, as in insertion or deletion.

Computed Relation is a structured explanation rather than a bare enum. Every relation includes a stable `reason_code`; `not_applicable` also identifies the missing side, while `indeterminate` references the Diagnostics that prevented a conclusion. An Atomic Difference with relation `different` may legitimately have zero Rendered Evidence under the Comparison Profile.

For example, an insertion has a Subject Alignment with `before=[]` and a non-empty `after` side. The inserted subject may have a valid Computed Appearance after the change, but no before fact exists, so comparing two computed facts is undefined rather than failed:

```json
{
  "domain": "presence.insertion",
  "computed_relation": {
    "status": "not_applicable",
    "reason_code": "before_fact_absent",
    "missing_side": "before",
    "explanation": "The entity exists only after the change, so no before computed fact exists."
  },
  "magnitude": {
    "presence": {
      "basis_side": "after",
      "affected_entity_count": 1
    },
    "geometry": {
      "bounds_area_css_px2": 2400.0,
      "bounds_viewport_fraction": 0.005
    },
    "coverage": {
      "painted_area_css_px2": 0.0,
      "painted_viewport_fraction": 0.0
    },
    "raster": {
      "changed_pixel_fraction": 0.0,
      "linear_premultiplied_rgba_rmse": 0.0
    }
  }
}
```

A deletion uses `after_fact_absent` and `missing_side: "after"`. Unsupported features, missing resources, and ambiguous analysis use `indeterminate`, not `not_applicable`, because comparable facts should exist but could not be established soundly.

### Evidence layer: where the distinction exists

- Source Semantics;
- Computed Appearance;
- Rendered Evidence.

An authored paint distinction such as `red` versus `#ff0000` exists in Source Semantics while its Computed Relation is `equivalent`. A small geometry change may have Computed Relation `different` while producing zero-valued Rendered Evidence under the Comparison Profile.

### Difference Magnitude: what can be measured

Difference Magnitude is a vector of domain-appropriate evidence. It may include:

- exact parameter and device-space displacement;
- contour displacement and changed coverage;
- linear premultiplied-RGBA and perceptual color error;
- event-local FLIP statistics and error-map extent.

The vector is the reportable fact. It does not imply that unrelated measurements can be added meaningfully.

### Visual Event Magnitude: preserve layers without addition

A Visual Event presents magnitude as layered evidence rather than a sum of its Atomic Differences. Source Semantics and Computed Appearance measurements remain attached to their respective Atomic Differences. The Event Rendered Outcome records the union of the Event's Difference Regions and computes its coverage, raster, color, and perceptual measurements once over that union.

No value is obtained by adding source, computed, and rendered measurements, or by summing child Atomic Difference magnitudes. Relationships between an Event Rendered Outcome and possible Changed Facts are represented by Influence Provenance and Cause Envelopes; they do not become exact causal edges unless a future analysis can prove that stronger claim.

### Presence Magnitude: how much content was inserted or deleted

Presence is categorical as a Domain but numeric as a Magnitude. An insertion or deletion does not receive a boolean magnitude or a fixed score of `1`. It records measurements from the side on which the content exists:

- `basis_side`: `after` for insertion and `before` for deletion;
- affected entity count;
- geometric bounds area in CSS square pixels and as a viewport fraction;
- painted coverage area and its viewport fraction;
- the ordinary continuous raster, color, and perceptual measurements from Rendered Evidence.

Geometric extent and painted coverage remain separate. A large inserted entity with zero opacity may have a large bounds area while its painted coverage, premultiplied-RGBA error, and perceptual error are all zero. The Difference remains reportable without being assigned an invented visual score.

### Impact Assessment: how measurements may be interpreted

Impact Assessment is an optional, explainable, profile-dependent interpretation. When present, it needs at least:

- a normalized rank value or human-facing label used only for ordering or presentation;
- the measurements and thresholds that justify the interpretation;
- the policy identifier and metric versions;
- affected spatial extent when one exists.

It never replaces Difference Magnitude or converts Rendered Evidence into a visible/not-visible gate. The Render Observation returns continuous measurements, including legitimate zero values.

Differences within one Domain are ordered by a versioned lexicographic Domain Ordering composed from measurements meaningful to that Domain. Cross-Domain ordering, if later required for a summary, is a separate optional policy rather than an intrinsic comparison of magnitudes.

### Confidence: how certain the engine is

Confidence applies independently to Subject Alignment, difference extraction, and visual-impact assessment. A highly salient apparent change can still have low confidence when fonts are missing or subject matching is ambiguous.

## Report invariants

1. Formatting Variations never become Atomic Differences.
2. Every Visual Subject participates in exactly one accepted Subject Alignment, and each Subject Alignment has at least one subject across its two sides.
3. Every Atomic Difference references one Subject Alignment.
4. Every Visual Event references at least one Atomic Difference.
5. Every Atomic Difference remains recoverable even when grouped into a Visual Event.
6. Difference Domain, Computed Relation, Difference Magnitude, Impact Assessment, and confidence are independent fields.
7. A distinction with no visual impact remains reportable when Source Semantics changed.
8. An indeterminate result is never coerced to `equal`, `none`, or zero magnitude.
9. Unsupported features and incomplete resources reduce declared coverage through Diagnostics.
10. The report declares whether analysis is complete, partial, or failed.
11. Report-local identifiers are stable within one report and are never presented as intrinsic identities of SVG content.
12. Visible differences in Render Observations remain reportable even when semantic attribution fails.
13. No visibility boolean or impact label substitutes for continuous Difference Magnitude measurements.
14. Domain Ordering preserves the units of its measurements and never implies that unrelated Difference Domains share one magnitude scale.
15. Coverage gaps are explicit and never become evidence of equality.
16. A causally complete Cause Envelope contains every actual changed cause; ranking never removes its candidates.
17. Unknown influence widens the Cause Envelope up to all Changed Facts or revokes the guarantee.
18. The canonical Structured Report contains Rendered Evidence only for its Comparison Profile; alternate-scale diagnostic rerenders never become Atomic Differences, magnitude fields, or ranking inputs.
19. `equivalent` and `different` Computed Relations reference comparable before and after facts.
20. `not_applicable` is used only when a comparable fact is structurally absent and must identify the missing side and reason.
21. `indeterminate` must include a reason and reference at least one Diagnostic explaining why the relation could not be established.
22. Presence Magnitude uses measurements from the side on which the content exists and never substitutes a boolean or fixed insertion/deletion score for continuous evidence.
23. Geometric extent and painted coverage remain separate, including when one is non-zero and the other is zero.
24. Visual Subject membership does not depend on non-zero Visual Contribution under the Comparison Profile.
25. Visual Contribution is represented by continuous measurements and never by a membership or visibility boolean.
26. Nonvisual Metadata does not create Visual Subjects or Atomic Differences.
27. Visual Resources and Visual Entities remain distinct subject roles even when their Atomic Differences are grouped into one Visual Event.
28. A Visual Event preserves layer-specific evidence and never computes magnitude by adding across evidence layers or child Atomic Differences.
29. Each Event Rendered Outcome is measured once over the union of its Difference Regions.
30. Visual Event grouping never strengthens a conservative `may-depend` relationship into a proven causal edge.
31. Shared cause alone never requires independent visual outcomes to be grouped into one Visual Event.
32. An Atomic Difference is stored once in the Structured Report and may be referenced by multiple Visual Events.
33. Every core v1 Visual Event has exactly one Primary Subject Alignment.
34. Core v1 does not merge Visual Events across different Primary Subject Alignments.
35. Difference Regions in one Event Rendered Outcome are not required to be spatially connected.
36. Both inputs use exactly one resolved Comparison Viewport for directly comparable Rendered Evidence.
37. An omitted Comparison Viewport is derived only from identical valid intrinsic viewport declarations.
38. Using an explicit Comparison Viewport never suppresses a Difference between the inputs' own viewport declarations.
39. Raw raster evidence is measured in linear premultiplied RGBA on a transparent canvas independently of the Perceptual Background.
40. Display-dependent perceptual metrics are computed only after compositing both inputs over the same explicitly declared Perceptual Background.
41. An absent Perceptual Background never causes the core engine to assume a display color or to discard non-perceptual Rendered Evidence.
42. Both inputs use the same positive finite Comparison DPR, whose effective value is recorded in the Structured Report.
43. An omitted Comparison DPR resolves to `1.0`.
44. Comparison DPR never determines whether a Computed Appearance Difference exists.
45. Core v1 defaults SVG and CSS color interpretation to sRGB and records that interpretation in the Structured Report.
46. Raster arithmetic and numeric error measurements use linear-sRGB premultiplied RGBA rather than gamma-encoded channel arithmetic.
47. Unsupported color profiles and wide-gamut content produce Diagnostics and Coverage gaps rather than silent sRGB conversion.

## Proposed JSON shape

This is a structural sketch, not yet a field-complete schema:

```json
{
  "schema_version": "0.1",
  "analysis": {
    "status": "complete",
    "profile": {
      "id": "profile:1",
      "viewport": {
        "width_css_px": 800.0,
        "height_css_px": 600.0,
        "source": "shared_intrinsic"
      },
      "device_pixel_ratio": 1.0,
      "perceptual_background": null,
      "color_space": {
        "interpretation": "srgb",
        "raster_representation": "linear_srgb_premultiplied_rgba"
      },
      "fonts": {},
      "resources": {},
      "renderer": {}
    },
    "before": { "content_hash": "..." },
    "after": { "content_hash": "..." }
  },
  "summary": {
    "main_event_ids": ["event:1"],
    "counts_by_domain": {},
    "counts_by_impact": {}
  },
  "subjects": {
    "before": [],
    "after": []
  },
  "subject_alignments": [],
  "events": [
    {
      "id": "event:1",
      "primary_subject_alignment_id": "alignment:1",
      "domains": ["geometry"],
      "description": "A related group moved to the right.",
      "atomic_difference_ids": ["diff:1"],
      "rendered_outcome": {
        "status": "computed",
        "profile_id": "profile:1",
        "difference_region_ids": ["region:1"],
        "magnitude": {
          "coverage": {},
          "raster": {},
          "perceptual": {
            "status": "not_computed",
            "reason_code": "perceptual_background_absent"
          }
        }
      },
      "impact_assessment": {}
    }
  ],
  "atomic_differences": [
    {
      "id": "diff:1",
      "domain": "geometry.position",
      "computed_relation": {
        "status": "different",
        "reason_code": "resolved_facts_differ"
      },
      "subject": { "subject_alignment_id": "alignment:1" },
      "before": {},
      "after": {},
      "evidence": {
        "source_semantics": {},
        "computed_appearance": {}
      },
      "magnitude": {
        "parameter": {},
        "geometry": {}
      },
      "impact_assessment": {},
      "confidence": {}
    }
  ],
  "diagnostics": []
}
```

Rendered measurements occur only under `events[].rendered_outcome`; Atomic Differences retain source and computed facts and magnitudes without copying the Event's raster values. A rendered outcome whose analysis is unavailable uses `status: "not_computed"`, `magnitude: null`, and referenced Diagnostics rather than zero-valued measurements. The structured-report prototype validated this status shape and JSON round trip for the first acceptance scenarios.

## Deliberately hidden implementation

The external interface does not expose separate parser, resolver, matcher, renderer, scorer, or event-aggregation interfaces. These are implementation stages of the comparison module. Source Semantics is implemented by the workspace-owned `source_semantics` module behind an internal seam that returns strict authored structure and Source Spans without renderer types. Rendering has a separate internal seam because a community MoonBit renderer is being evaluated against a possible future project-owned workspace module and an external conformance oracle; dependency-specific source, scene, and image types do not cross the external comparison interface.

## Open decisions

1. The exact versioned fields and defaults of the Comparison Profile.
2. The stable subdomain taxonomy beneath the accepted top-level Difference Domains.
3. Coverage semantics for unsupported SVG features and missing resources.
4. The amount of subject and evidence detail required in the canonical JSON.
