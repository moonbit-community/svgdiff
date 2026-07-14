# Core Comparison Model

Status: current model for Structured Report schema `1.1`

Last verified: 2026-07-14

This document defines the concepts and invariants implemented by the current comparison engine. The checked-in [JSON Schema](../schema/svgdiff-report.schema.json) and public MoonBit report types are authoritative for serialized field names. The [current v1 scope](v1-scope.md) defines which SVG features may receive complete analysis; the [roadmap](../roadmap.md) contains future extensions.

## External seam

The root package exposes one conceptual operation:

```text
compare(before_svg, after_svg, comparison_profile) -> structured_report
```

Callers provide two SVG source strings and a Comparison Profile. Parsing, supported source normalization, subject alignment, difference extraction, rendering, magnitude calculation, region extraction, conservative causal attribution, and report assembly remain internal.

## Current pipeline

```text
SVG source
  -> authored visual facts and source spans
  -> supported computed facts and visual subjects
  -> before/after subject alignments
  -> changed facts and atomic differences
  -> canonical raster observation and difference regions
  -> conservative cause envelopes
  -> visual events
  -> Structured Report 1.1
```

Source, computed, and rendered evidence are related but never interchangeable. For example, `red` and `#ff0000` may be a source-level distinction with equivalent computed paint and zero rendered error. Conversely, unsupported semantics can make computed or rendered equality indeterminate even when no supported source difference was found.

## Comparison Profile

Schema `1.1` records:

- `viewport_width` and `viewport_height`;
- `comparison_dpr`, fixed to `1.0` by the root v1 seam;
- `color_interpretation`, fixed to `srgb`;
- `raster_representation`, fixed to `linear_srgb_premultiplied_rgba_f64`;
- `renderer_id`, currently fixed to `mizchi/svg@0.2.1`.
- `renderer_conformance_profile_id`, currently fixed to `svgdiff-renderer-conformance-profile/1`.

The root `compare` function currently preserves only the caller-supplied viewport dimensions and canonicalizes the other fields to the v1 defaults. The CLI defaults the common viewport to `16 x 16` and accepts explicit positive dimensions through `--width` and `--height`.

`schema_version` identifies the serialized report shape, `renderer_id` identifies the concrete rendering implementation, and `renderer_conformance_profile_id` identifies the reviewed fixture, disposition, guard, and future tolerance policy that bounds Rendered Evidence claims. None can substitute for another.

Intrinsic viewport derivation, resource bundles, fonts, perceptual backgrounds, alternate DPRs, wide-gamut profiles, and cross-renderer profiles are not part of the implemented v1 profile. Accepted target decisions for some of these capabilities remain recorded in ADRs and the roadmap.

## Evidence layers

### Source Semantics

Source Semantics describes supported authored visual declarations after formatting normalization while retaining provenance. A `DeclaredVisualFact` records:

- property name;
- exact authored value;
- normalized declared value;
- declaration origin;
- half-open source offsets.

Attribute order, quote style, tag-closing style, entity spelling, and declaration whitespace alone do not create Atomic Differences. A change in normalized visual declaration or declaration origin may create a source-level difference even when computed and rendered results remain equal.

### Computed Appearance

Computed Appearance records the supported resolved fact for a subject. `ResolvedVisualFact` includes the resolved value, resolution mode, optional declaration owner, winning declaration, and inheritance depth.

`ComputedRelation` describes the relationship between the before and after facts:

- `equivalent`: supported facts resolve to the same visual value;
- `different`: supported resolved facts differ;
- `indeterminate`: Diagnostics prevent a sound conclusion;
- `not_applicable`: one side has no comparable fact, as with insertion or deletion.

The relation includes a stable reason code and may reference Diagnostics. It is not a visibility test: a computed difference may have zero rendered magnitude under the current profile.

### Rendered Evidence

Rendered Evidence describes the canonical raster response under the recorded profile. `RenderedMagnitude` currently records:

- changed pixel count and viewport fraction;
- renderer-native RGBA8 RMSE;
- canonical linear-sRGB premultiplied-RGBA RMSE.

`RenderedEvidence.status` distinguishes an available observation from an unavailable or indeterminate one. A measured zero is valid evidence and must not be replaced by `not_computed` or used to erase a source or computed difference.

## Report records

### Renderer Capability Gap

`renderer_capability_gaps` is an encountered-input projection of renderer-specific Diagnostics. Each `RendererCapabilityGap` records a stable capability ID, a `guarded` or `unavailable` support status, and every Diagnostic ID that establishes the gap for this comparison. `guarded` means a renderer observation may remain numeric but cannot support a complete conformance claim; `unavailable` means the required renderer behavior cannot currently supply accepted evidence.

The array does not enumerate capabilities unused by the inputs. An empty array therefore means only that no known renderer gap was encountered; it is not a global renderer support claim. Analysis status, per-feature coverage, and Diagnostics remain authoritative, and non-renderer analyzer gaps do not appear in this projection.

### Subject Reference and Subject Alignment

A `SubjectReference` identifies a report subject by source index, SVG kind, and optional authored ID. Authored IDs and source order are evidence, not authoritative cross-document identity.

A `SubjectAlignment` relates sets of before and after subjects. Its relation may express correspondence, insertion, deletion, split, or merge. The current analyzer implements basic set-to-set alignment for its supported shape subset; broader many-to-many matching remains roadmap work.

Equally plausible current matches use the deterministic [v1 Subject Alignment tie-break policy](alignment-tie-breaking.md). Schema `1.1` adds optional selection `evidence`, and current producers always emit its score kind, nullable selected score, local candidate counts, and `unique`, `tied`, or `not_assessed` ambiguity. `confidence` remains null with `confidence_status: "not_calibrated"`. The selected pairing is repeatable, but local uniqueness does not imply authoritative identity or global assignment uniqueness.

### Changed Fact

A `ChangedFact` stores one supported authored change and the subject IDs it may affect. Atomic Differences refer to Changed Fact IDs so a shared inherited declaration or resource change does not need to be duplicated for each outcome.

### Atomic Difference

An `AtomicDifference` is the smallest independently reportable supported change. It records:

- subject role and optional Subject Alignment;
- Difference Domain;
- before and after source values and optional declared facts;
- referenced Changed Facts;
- evidence layers;
- Computed Relation;
- domain-appropriate Difference Magnitude;
- a versioned Domain Ordering tuple.

Current emitted domains include `presence.insertion`, `presence.deletion`, `geometry.*`, `paint.*`, `compositing.opacity`, `resource.gradient.stop_color`, `text.content`, and `document.structure` where the supported analyzers apply. The exact emitted subdomain is part of the report contract; the broader future taxonomy remains roadmap work.

### Difference Magnitude

Magnitude is a vector, not a universal similarity scalar. The current vector can contain:

- absolute and signed parameter delta in user units;
- symmetric relative delta;
- geometry displacement in CSS pixels and viewport fraction;
- presence painted viewport fraction;
- raster changed-pixel fraction;
- RGBA8 and linear-premultiplied-RGBA RMSE.

Unavailable components are `null`, not numeric zero. Insertion and deletion additionally use `PresenceMagnitude` to record subject count, geometric bounds, painted area, and viewport fractions from the side on which the content exists.

`DomainOrdering` contains a policy ID and a lexicographic component vector. It orders differences within an exact domain without pretending that geometry, paint, presence, text, and perceptual effects share one natural unit. The complete v1 component, missing-value, and tie-break contract is defined in the [Domain Ordering Policy](domain-ordering.md).

The raw magnitude fields remain authoritative when no Impact Assessment exists or when a future policy-derived assessment is unavailable. The current absence and the constraints on future severity or cross-domain policy are defined in [Raw Magnitudes and Impact Assessment](impact-assessment.md).

### Difference Region

A `DifferenceRegion` localizes an event using either a connected pixel-mask component or conservative computed bounds. It records pixel-space and CSS-space bounds, changed-pixel count, viewport fraction, and a Cause Envelope.

Pixel-mask regions describe observed final differences. Computed-bounds regions are conservative localization when rendered evidence is unavailable. Neither form alone proves an exact causal contribution.

### Cause Envelope

A `CauseEnvelope` is a conservative set of Changed Fact IDs that may have caused one Difference Region. Its guarantee is either:

- `sound_overapproximation`: within complete analysis coverage, every actual changed cause is included, although false positives may remain;
- `not_established`: unsupported or unresolved semantics prevent the completeness guarantee.

The engine may safely widen an envelope to all Changed Facts when it lacks a sound independence rule. It must not prune candidates speculatively. The detailed contract and proof discipline live in [Influence Provenance and Causal Completeness](influence-provenance.md).

### Visual Event

A `VisualEvent` is the primary agent-facing grouping unit. In schema `1.1` it records one primary subject ID, referenced Atomic Difference IDs, one rendered outcome, and zero or more Difference Regions.

Current v1 events are anchored to one Primary Subject Alignment, and every Atomic Difference has exactly one owning event. All differences that describe that aligned-subject outcome group in the same event even when they reference several Changed Facts or belong to different domains. The event's Rendered Outcome is measured once over the union of its Difference Regions; child magnitudes are not added together.

Changed Facts express causal fan-out rather than event ownership. One Changed Fact may be referenced by distinct Atomic Differences in several events when an inherited declaration or shared resource affects several subjects. Conversely, several Changed Facts may feed the Atomic Differences in one event. This preserves one report identity for every independently reportable distinction without confusing an authored cause with its outcomes.

A resource difference may share one entity event when that entity is its sole mediated outcome. An unreferenced resource change uses its own resource event. Future resource changes with several independent entity outcomes must use a separate resource event and shared Changed Fact references until the project accepts a versioned contextual-event link; assigning the resource Atomic Difference to one arbitrary entity or duplicating it across events is forbidden.

Separate primary alignments remain separate events even when they overlap or are adjacent, share hierarchy, Changed Facts, or resources, or appear visually coherent. These relationships may support Agent explanation, but none is current event identity. Cross-subject outcome grouping, separately aligned resource synthesis, and semantic theme detection remain future work. The governing ownership and fan-out decision is [ADR 0040](adr/0040-give-each-atomic-difference-one-event-owner.md); [ADR 0041](adr/0041-defer-cross-subject-event-aggregation.md) requires a measured report-only Agent failure plus a deterministic, traceable, versioned grouping and evaluation policy before this boundary can reopen.

### Diagnostic

A `Diagnostic` identifies an unsupported, unresolved, or failed analysis condition, the affected subject, and the evidence layers whose claims are constrained. Diagnostics are part of the result, not debug logging.

### Structured Report

The schema `1.1` top-level object contains exactly these conceptual sections:

```json
{
  "schema_version": "1.1",
  "analysis_status": "complete | partial | failed",
  "coverage_matrix": [],
  "renderer_capability_gaps": [],
  "profile": {},
  "subject_alignments": [],
  "changed_facts": [],
  "source_resolutions": [],
  "atomic_differences": [],
  "events": [],
  "diagnostics": []
}
```

Each `coverage_matrix` row names one encountered feature and subject, records `covered`, `limited`, `not_applicable`, or `failed` independently for Source Semantics, Computed Appearance, and Rendered Evidence, and references the Diagnostics that justify limitations. `analysis_status` is the summary of those rows, not a separate severity judgment. A `complete` report may contain no differences, small differences, or large differences. A `partial` report can still contain useful supported evidence, but consumers must respect its matrix and Diagnostics. The exact caller obligations are defined in the [Analysis Status Contract](analysis-status.md).

## Current invariants

1. Formatting-only XML and declaration changes do not become Atomic Differences.
2. Supported authored distinctions remain reportable even when computed values are equivalent or rendered magnitude is zero.
3. Unsupported semantics cannot produce a false claim of complete equality.
4. `equivalent`, `different`, `indeterminate`, and `not_applicable` remain distinct computed states.
5. Measured zero and unavailable measurement remain distinct serialized states.
6. Atomic Differences retain references to their Changed Facts and evidence layers.
7. Event grouping does not delete or merge away Atomic Differences.
8. Every reported Difference Region carries a Cause Envelope.
9. A Cause Envelope claiming `sound_overapproximation` may contain false positives but must contain every actual changed cause within the supported coverage boundary.
10. Dependency-specific XML, SVG scene, image, and renderer types do not cross the public report seam.
11. HTML is a presentation of the Structured Report and must not recompute semantic differences.
12. Identical inputs and Comparison Profiles produce deterministic array order and report-local IDs; every declared report-local reference resolves within the report.

## Not implemented in schema 1.1

The following concepts are intentional future work rather than hidden current fields:

- an agent summary or universal main-difference score;
- explicit Impact Assessment policy and confidence fields;
- exact per-pixel Contribution Index or minimal root-cause set;
- perceptual-background-dependent metrics such as FLIP;
- deterministic font loading, shaping, layout, and glyph evidence;
- caller-supplied resource bundles and implicit viewport derivation;
- complete CSS, paths, transforms, filters, masks, clipping, blending, reuse, and nested viewport semantics;
- cross-subject Visual Event aggregation.

Their accepted design direction is preserved in the [ADR index](adr/README.md), while their implementation work is tracked only in the [roadmap](../roadmap.md).
