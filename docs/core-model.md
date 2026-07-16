# Core Comparison Model

Status: current model for Structured Report schema `1.38`

Last verified: 2026-07-16

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
  -> private typed resource dependency graph
  -> supported computed facts and visual subjects
  -> before/after subject alignments
  -> changed facts and atomic differences
  -> canonical raster observation and difference regions
  -> conservative cause envelopes
  -> visual events
  -> Structured Report 1.38
```

Source, computed, and rendered evidence are related but never interchangeable. For example, `red` and `#ff0000` may be a source-level distinction with equivalent computed paint and zero rendered error. Conversely, unsupported semantics can make computed or rendered equality indeterminate even when no supported source difference was found.

## Comparison Profile

Schema `1.38` records:

- `viewport_width` and `viewport_height`;
- `comparison_dpr`, fixed to `1.0` by the root v1 seam;
- `color_interpretation`, fixed to `srgb`;
- `raster_representation`, fixed to `linear_srgb_premultiplied_rgba_f64`;
- `renderer_id`, currently fixed by the producer to `svgdiff/style-precedence-normalizer@3+ordinary-inheritance-normalizer@1+css-computed-value-normalizer@3+css-color3-opacity-normalizer@1+length-used-value-normalizer@1+stroke-used-geometry-normalizer@1+basic-shape-used-geometry-normalizer@1+isolated-group-compositor@1+static-mask-normalizer@1+static-mask-compositor@1+static-filter-graph-compositor@1+static-blend-compositor@1+mizchi/svg@0.2.1`.
- `renderer_conformance_profile_id`, currently fixed by the producer to `svgdiff-renderer-conformance-profile/25`.

The root `compare` function currently preserves only the caller-supplied viewport dimensions and canonicalizes the other fields to the v1 defaults. The CLI defaults the common viewport to `16 x 16` and accepts explicit positive dimensions through `--width` and `--height`.

`schema_version` identifies the serialized report shape, `renderer_id` identifies the complete production rendering implementation including project-owned adapters, and `renderer_conformance_profile_id` identifies the reviewed fixture, disposition, guard, and future tolerance policy that bounds Rendered Evidence claims. None can substitute for another. JSON Schema verifies that renderer identities are present and structurally valid; the versioned compatibility policy decides which concrete identities a consumer accepts.

The author cascade module is pure and renderer-independent. Presentation attributes, inline declarations, and already-applicable stylesheet candidates share one winner selection over importance, inline/ID/class/type specificity, declaration-source placement, and source order. Inline declaration lists support duplicate properties and terminal case-insensitive `!important` while retaining the winning exact authored value and Source Span. A separate static selector module indexes XML ancestry and element siblings, matches the admitted type, universal, ID, class, attribute-presence, exact-attribute-value, compound, list, descendant, child, adjacent-sibling, and general-sibling scope, and supplies matched candidates without learning cascade priority rules. Unsupported selector grammar remains guarded rather than approximated.

The style-precedence normalizer operates on private renderer-input copies only. It materializes complete cascade winners, including matched stylesheet declarations, on each element, mirrors those values into conflicting presentation attributes, and removes redundant stylesheet text before every production renderer parse. Source Semantics, Source Spans, Changed Facts, Diagnostics, resource admission, and HTML source display continue to use the original SVG strings.

The length used-value normalizer runs after style precedence on the same private copy. It resolves admitted CSS absolute units, SVG percentages, and static viewport-relative units from explicit SVG and Comparison Profile contexts. The basic-shape used-geometry normalizer then canonicalizes shape values and materializes paired `rx`/`ry` values needed by the pinned renderer. Authored values remain unchanged in Source Semantics. Rounded rectangles and polygons retain separate raster-conformance guards because canonical used geometry does not by itself prove browser-equivalent antialiasing.

The stroke used-geometry normalizer resolves length-aware width, dash arrays, and dash offsets plus caps, joins, miter limits, and `vector-effect` before the basic-shape adapter. Odd dash arrays duplicate, all-zero arrays become solid, and effective offsets normalize by the even pattern sum. Stroke-none, zero-width, and topology-specific inactive properties retain authored differences while comparing their computed effects as equivalent. Width differences retain both the full parameter delta and the transform-aware half-width boundary displacement; non-spatial scalar controls do not claim a Cartesian displacement. Active stroke outline, join, dash, and non-scaling-stroke pixels retain separate renderer-conformance guards.

Marker adaptation is renderer-independent. The engine retains authored `marker` shorthand and longhand facts, resolves supported local fragment references, and extracts canonical length-aware `markerUnits`, viewport size, reference point, orientation, `viewBox`, `preserveAspectRatio`, and hidden overflow facts. Each admitted shape is converted to its SVG equivalent path vertices; start, mid, and end roles preserve closed-subpath duplication and zero-length direction search. Automatic orientation uses segment tangents and mid-vertex bisectors, while `auto-start-reverse` reverses only start instances. Placement, orientation, stroke-width or user-space units, viewport mapping, reference offset, and subject transforms produce a conservative clipped marker viewport envelope. Resource changes use `resource.marker.*` domains and attribute every referenced instance through `affected_subject_ids`. Marker child paint, cascade/inheritance, context paint, environment-dependent lengths or visible overflow, external references, and pinned-renderer pixels remain explicitly guarded.

Intrinsic viewport derivation, fonts, perceptual backgrounds, alternate DPRs, wide-gamut profiles, and cross-renderer profiles are not part of the implemented v1 profile. Accepted target decisions for some of these capabilities remain recorded in ADRs and the roadmap.

Explicit resource bundles are inputs to comparison rather than ambient profile state. Before and after each receive an ordered set of opaque locator, MIME, and byte entries. Exact locator matching can resolve admitted PNG/JPEG `image` resources; no base URL, filesystem path, redirect, or network environment participates. The report retains authored locator Source Spans and compact content hashes but never serializes supplied bytes or CLI resource-file paths.

## Evidence layers

### Source Semantics

Source Semantics describes supported authored visual declarations after formatting normalization while retaining provenance. A `DeclaredVisualFact` records immutable source evidence selected by the author cascade:

- property name;
- exact authored value;
- normalized declared value;
- declaration origin;
- half-open source offsets.

Attribute order, quote style, tag-closing style, entity spelling, declaration whitespace, and source-offset movement alone do not create Atomic Differences. A change in normalized visual declaration or declaration origin may create a source-level difference even when computed and rendered results remain equal. Cascade, inheritance, computed-value resolution, shorthand expansion, and private renderer normalization never rewrite a fact's authored value, declared value, origin, or half-open UTF-16 Source Span; resolution mode, declaration owner, and inheritance depth carry computed state separately.

Pure nonvisual metadata is not a fourth visual evidence layer. Inner SVG `title`, `desc`, and `metadata` content is excluded from visual semantic input without moving outer Source Spans; unconsumed `aria-*` and `data-*` changes likewise create no Atomic Difference. A supported selector can still turn an outer element or metadata attribute into a real visual cause, in which case the computed property consequence uses its ordinary visual domain. The independent [Nonvisual Source Audit](source-audit.md) inventories the exact authored metadata facts and never appears inside Structured Report.

Path source adaptation is renderer-independent. The engine strictly consumes every path command and repeated parameter group, expands relative, horizontal/vertical, and smooth shorthand into absolute Move, Line, Cubic, Quadratic, Arc, and Close segments, and retains each segment's exact authored slice plus half-open UTF-16 span. One-to-one path comparison aligns those normalized segments and emits every differing command, parameter, insertion, or deletion. Exact numeric deltas remain independent of raster quantization; command-family or relative/absolute spelling changes that normalize to the same segment are computed-equivalent source differences. When the fixed observation budget permits, `geometry_displacement_css_px` records the symmetric maximum nearest alpha-boundary pixel-center distance from isolated rendering. Path reports remain partial because this observation does not establish continuous geometric Hausdorff distance, transformed-path boundary measurement, complete stroke and paint semantics, or accepted path renderer conformance.

SVG transform adaptation is likewise renderer-independent. A strict parser consumes `matrix`, `translate`, `scale`, `rotate`, `skewX`, and `skewY`, preserves normalized authored function structure, and post-multiplies matrices in authored order. Each leaf subject retains the root-to-leaf transform chain and exact cumulative affine matrix across entities, groups, resource containers, and nested `svg` elements. `geometry.transform.list` reports authored-list changes, including matrix-equivalent rewrites; `geometry.transform.cumulative_matrix` reports a changed leaf coordinate mapping. The engine independently decomposes the before and after cumulative matrices into canonical translation, rotation, signed scale, and skew components, then emits one typed effect difference for every changed component. This avoids treating raw affine coefficients as a visual magnitude. A singular linear transform has no unique finite decomposition, so its exact six coefficients and determinant are retained under `geometry.transform.residual_matrix` instead. Gradient and pattern resource transforms are resolved below as part of their static paint-server models.

SVG viewport adaptation interleaves with that transform chain. The root `svg` maps its `viewBox` into the profile's explicit common viewport; authored root `width` and `height` remain intrinsic declaration facts and do not independently resize before and after canvases. Each nested `svg` resolves unitless and CSS absolute lengths, nearest-viewport percentages, or initial-profile `vw`/`vh`/`vmin`/`vmax` values for `x`, `y`, `width`, and `height`, then establishes a child coordinate basis from its `viewBox` when present. `document.viewport` identifies a changed declaration, while the existing cumulative-matrix and typed transform-effect domains identify every affected aligned leaf mapping. Equivalent normalized declarations and ignored `preserveAspectRatio` without a `viewBox` remain source-visible but computed-equivalent.

Basic-shape adaptation resolves a separate canonical used-geometry record while retaining every authored fact. Omitted coordinates and dimensions use SVG defaults, and explicit rectangle `auto` dimensions resolve to zero; rectangle radii propagate and clamp to half-dimensions; one omitted or `auto` ellipse radius copies the other; zero dimensions remain valid non-rendering numeric geometry; line has no fillable interior; polyline retains open topology but an open subpath is implicitly closed for fill; polygon retains explicit closure semantics; and point lists normalize separators, compact signs, and exponent forms. An odd final point coordinate is dropped from used geometry but remains a source-located error. Invalid syntax, negative dimensions or radii, and unsupported units make the computed relation indeterminate through `basic_shape_geometry_unsupported` rather than silently substituting a valid shape.

### Computed Appearance

Computed Appearance records the supported resolved fact for a subject. `ResolvedVisualFact` includes the resolved value, resolution mode, optional declaration owner, winning declaration, and inheritance depth. Ordinary inheritance is applied after cascade for supported inherited properties; non-inherited properties remain local or initial. CSS-wide keywords then select inherited or initial behavior, author-origin `revert` follows ordinary defaulting in the author-only profile, bounded `var()` substitution resolves case-sensitive inherited custom properties, and supported paint consumers resolve `currentColor` from the same element's computed `color`. Missing variables, cycles, and invalid substituted property values follow CSS invalid-at-computed-value behavior and make the consuming declaration act as `unset`. Effective leaf inputs and dependency edges retain original declaration provenance and never create synthetic leaf-owned Changed Facts.

Deterministic solid paint resolves CSS Color 3 syntax into canonical straight-alpha sRGB. `opacity`, `fill-opacity`, `stroke-opacity`, and `stop-opacity` resolve number or percentage syntax to clamped continuous values. Effective fill and stroke alpha multiplies color alpha, the corresponding paint opacity, and leaf element opacity; effective gradient-stop alpha multiplies stop-color alpha and stop opacity. Group/root opacity is not folded into descendants because it remains an isolated compositing operation. Environment-dependent system colors and out-of-profile color functions stay indeterminate behind distinct Diagnostics.

Static same-document gradients are a resource graph plus consumer-specific computed paint. The graph resolves linear and radial geometry, `gradientUnits`, `spreadMethod`, `gradientTransform`, every child stop, and recursive `href`/`xlink:href` template inheritance, including cross-kind chains and the SVG child-set replacement rule. Stop offsets are parsed as numbers or percentages, clamped to `[0,1]`, and made monotonically nondecreasing in document order. Each resource retains authored/template provenance; each fill or stroke consumer then resolves object-bounding-box or user-space coordinates and an effective coordinate matrix. Resource differences and downstream `paint.fill` or `paint.stroke` outcomes remain separate, so one resource edit can fan out to every consumer while an unreferenced resource edit remains resource-only. Zero-stop, one-stop, degenerate linear, and degenerate radial cases have explicit computed paint modes. External references, dynamic content, malformed geometry, missing target bounds, and non-sRGB interpolation are guarded rather than approximated.

Static same-document patterns use the same resource-versus-consumer separation. The resource resolves tile coordinates, `patternUnits`, `patternContentUnits`, `patternTransform`, `viewBox`, `preserveAspectRatio`, recursive same-kind template attributes, and the nearest non-descriptive child set. Each consumer supplies current user space and any object bounds; supported child shapes are resolved through the referencing pattern host and a provider-relative transform chain. Resource and child differences remain distinct from mediated `paint.fill` or `paint.stroke` outcomes. Zero tile dimensions and empty content are explicit no-paint modes. Arbitrary child SVG, dynamic or external references, visible overflow, unavailable bounds, and malformed values remain guarded.

Paint URL fallback selection precedes gradient or pattern mediation. The engine parses one `<url> [none | <color>]?` value after cascade and custom-property substitution, resolves same-document target existence and kind, and selects either the valid resource, the optional fallback, or deterministic no paint. Active fallback colors use the ordinary sRGB, `currentColor`, paint-opacity, and leaf-opacity model. Inactive fallbacks retain authored facts but add no dependencies. External target validity, context paint, malformed syntax, unsupported profiles, and multi-layer paint remain guarded.

Paint order and winding rules are resolved after the same cascade and dependency stages. `paint-order` appends omitted operations in normal order and compares only the subject's active fill, stroke, and marker subsequence. `fill-rule` is inactive without fill and equivalent across admitted single simple contours; potentially self-intersecting point or path geometry retains `nonzero` or `evenodd`. `clip-rule` is inactive outside `clipPath`; inside the admitted one-rectangle clip it is equivalent across `nonzero` and `evenodd`, while more general contours retain the inherited owner, affected child, and a precise content guard. Pattern child signatures apply the same active-operation normalization.

Static rectangular clipping separates the non-inherited host attachment from the referenced resource. The host `clip-path` resolves presentation, inline, and static stylesheet declarations, CSS-wide values, custom-property dependencies, and one local fragment. The resource records presence, `clipPathUnits`, clip/child transforms, rectangle geometry, clip rule, and every active consumer. For `userSpaceOnUse` or unitless numeric `objectBoundingBox` coordinates under deterministic axis transforms, each rendered leaf retains a before-side or after-side conservative effect bound equal to its unclipped painted bound intersected with the transformed rectangle. An empty intersection is a proven zero contribution, not missing evidence. A shared resource event uses the union of all nonempty before/after consumer bounds; unsupported bounds fall back conservatively and revoke causal completeness through a Diagnostic. These rectangles localize where clipping can matter but are not contributor masks or exact curved clip coverage.

Static masking similarly separates the non-inherited host `mask` and `mask-mode` facts from the referenced resource. The resource records presence, `maskUnits`, `maskContentUnits`, region coordinates, `mask-type`, color interpolation, direct rectangle geometry and transform, solid color, independent alpha declarations, and every consumer. Effective mode is host `alpha` or `luminance`, or the resource type for `match-source`; alpha uses content alpha while luminance uses non-premultiplied sRGB coefficients multiplied by that alpha. Complete target and mask surfaces are isolated before multiplication and source-over composition. Each side's conservative effect bound intersects target paint, mask region, and transformed nonzero mask content; host localization unions affected descendants from both sides so newly vacated pixels are not lost. Missing, wrong-kind, empty, and non-positive-region single SVG mask layers are deterministic transparent black. These numeric values and rectangles describe transfer and localization, not a visibility boolean or exact contributor index.

Static filtering separates the non-inherited host `filter` attachment from one same-document resource graph. A missing or wrong-kind local target deterministically applies no filter; an admitted empty graph instead produces transparent output. A nonempty admitted graph contains only direct static `feOffset` primitives and resolves `filterUnits`, `primitiveUnits`, the `-10% -10% 120% 120%` default region, SourceGraphic, SourceAlpha, omitted previous input, and admitted ASCII identifier results from earlier primitives. Every primitive executes on a distinct transparent RGBA surface, and each input/output is hard-clipped to the filter region. Conservative bounds begin at host paint, translate with each offset, intersect the filter region, and remain attached to every intermediate and final result; a clipped-empty result is proven zero contribution. Resource insertion/deletion, units, region, primitive presence, graph edges, result names, and offsets remain separate typed differences with exact provenance, continuous deltas, and consumer fan-out. The execution budget admits at most 256 primitives per graph and 16,777,216 aggregate primitive-surface pixels per source.

An unsupported direct primitive is not executed or attribute-normalized. The engine retains its direct-child position, local name, resource-qualified subject ID, and full-subtree offsets, then aligns positions and slices exact source facts only when producing Diagnostics or `resource.filter.primitive.source` differences. If either aligned side is unsupported, one opaque comparison covers its complete element, attributes, namespace spelling, nested nodes, text, comments, insertion, deletion, or type replacement. A shifted sequence may over-report later positions; unknown semantics do not justify stronger matching. Opaque differences name every affected consumer but expose only source semantics, an indeterminate computed relation, no numeric magnitude, no rendered outcome, no region, and no causal-completeness guarantee. Both-side admitted `feOffset` pairs retain their finer facts. Malformed XML remains a failed input, and direct metadata children remain outside the visual inventory.

Static blending resolves non-inherited CSS `mix-blend-mode` and `isolation` without treating same-named XML attributes as presentation attributes. The admitted binary-alpha slice renders explicit-ID opaque integer rectangles in source order: ordinary groups share the current backdrop, `isolation:isolate` on the root SVG or an authored-ID `g` starts a transparent layer and composites it once, and each non-normal leaf uses the W3C separable or non-separable formula before source-over. `compositing.blend_mode` and `compositing.isolation` are categorical; their differences retain exact declarations, computed keywords, affected foreground and conservative nearest-boundary backdrop-prefix subjects, measured pixels, and no universal scalar between modes. Because a simultaneous backdrop or order change may be the real cause, their complete Cause Envelopes deliberately use comparison-wide Changed Fact candidates under `sound_overapproximation`. Structural stacking outcomes call the same product compositor. Continuous alpha, antialiasing, transforms, strokes, instances, container blend modes, anonymous or instance isolation hosts, and other effect interactions preserve source facts behind precise Diagnostics.

Structural relationships are reported only through admitted consequences. An aligned subject whose effective parent path or use-instance resolution changes receives a structural relationship fact when an existing computed property, cumulative transform, viewport, or resource-mediated outcome differs. Pairwise draw-order inversions receive `document.structure.stacking_order` when the subjects' conservative painted bounds may overlap and the final raster changes. Disjoint and zero-raster reorders remain absent. These facts are conservative cause candidates rather than exact contribution weights.

One private typed resource graph supplies source-level topology across gradients, patterns, markers, clips, masks, filters, symbols, images, use instances, inline URL attributes, and static stylesheet URL tokens. Nodes retain source identity and kind; edges retain relationship, locator class, local target, containing definition scopes, and Source Span. Deterministic forward and reverse traversal is conservative for duplicate IDs and nested definitions. Existing semantic passes project only difference-relevant resource facts and affected consumers into the report; unsupported effects and external resources remain partial, and the unchanged full graph is not serialized.

Embedded raster images add a distinct resource layer. Explicit 8-bit non-interlaced PNG and single-scan baseline JPEG data URLs are decoded under fixed byte, dimension, pixel, cumulative-pixel, and decompression limits, then normalized to RGBA8. Pixel-affecting PNG variants and JPEG scan or sampling modes outside the implemented slice remain partial rather than being approximated. Source encoding, intrinsic dimensions, decoded content, placement, fitting mode, opacity, transform, insertion, and deletion remain separate Atomic Differences. Exact locator provenance stays in the Source Span while report values use compact hashes instead of payloads. A decoded resource does not establish final SVG compositing; the pinned renderer gap keeps Rendered Evidence unavailable for any encountered embedded raster.

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

A `SubjectReference` identifies a report subject by source index, SVG kind, optional authored ID, and optional `SubjectInstanceContext`. A direct subject has null instance context. A subject rendered through `use` records a deterministic instance ID, its unchanged definition subject ID, and the outer-to-inner use-host path. Authored IDs and source order remain evidence rather than authoritative cross-document identity; instance paths establish placement identity without manufacturing cloned source declarations.

A `SubjectAlignment` relates sets of before and after subjects and declares whether they are Visual Entities or Visual Resources. Its relation may express correspondence, insertion, deletion, split, or merge. Rendered leaf subjects reached through `use` first align by exact instance path and kind; direct shapes use transform- and bounds-aware exact visual signatures, split/merge rules, and the bounded `rendered_geometry_feature_distance_v1`. That minimum-cost feature combines conservative device-space geometry, non-geometry appearance, hierarchy, and normalized path evidence under the actual Comparison Viewport. Paths participate through normalized device-space segment parameters rather than raw `d` spelling. The score selects correspondence only; it is not a Difference Magnitude, equality proof, or confidence.

Schema `1.32` adds a separate source-structural alignment inventory for `g`, `text`, `use`, and visual definitions. Schema `1.33` makes rendered-leaf correspondence transform- and bounds-aware. Schema `1.34` groups equal-cardinality duplicates with the same exact rendered and reportable source-semantic signatures into one set-to-set equivalence class and matches structural subjects by an ID- and sibling-order-independent recursive semantic signature before authored-ID, path, or stable-order fallback. The source-semantic guard retains visually equivalent authoring differences as reportable one-to-one changes. Array order preserves provenance only; it does not define pairwise identity inside a repeated class. The production corpus validates one-to-one, insertion, deletion, split, merge, and exact many-to-many cardinalities without adding identity claims.

Schema `1.38` gives every alignment a closed `entity` or `resource` role. Groups, text, use hosts, rendered shapes, and image placement remain entity alignments. Symbols, gradients, patterns, markers, clip paths, masks, filters, and intrinsic image content use independent resource alignments. Every resource Atomic Difference names a resource-role alignment; resource-mediated entity outcomes keep their entity alignments and Changed Fact fan-out. Matching resource definitions, including renamed definitions, is correspondence evidence only and does not prove computed consumer equality or rendered equality. An SVG `image` therefore legitimately has both alignments over the same source reference: one for acquired or decoded content and one for placement. Text correspondence still does not imply font, shaping, glyph, or rendered equality. Unequal-cardinality or mixed-change repeated clusters remain roadmap work.

Equally plausible current matches use the deterministic [v1 Subject Alignment tie-break policy](alignment-tie-breaking.md). Schema `1.1` adds optional selection `evidence`, and current producers always emit its score kind, nullable selected score, local candidate counts, and `unique`, `tied`, or `not_assessed` ambiguity. `confidence` remains null with `confidence_status: "not_calibrated"`. The selected pairing is repeatable, but local uniqueness does not imply authoritative identity or global assignment uniqueness.

### Changed Fact

A `ChangedFact` stores one supported authored change or evaluated structural relationship and the subject IDs it may affect. Atomic Differences refer to Changed Fact IDs so a shared inherited declaration, resource change, or structural cause does not need to be duplicated for each outcome. Relationship facts have no fabricated declaration or Source Span.

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

Current emitted domains include `presence.insertion`, `presence.deletion`, `geometry.*`, `paint.*`, `compositing.opacity`, `resource.gradient.*`, `resource.pattern.geometry.*`, `resource.pattern.units`, `resource.pattern.content_units`, `resource.pattern.transform.*`, `resource.pattern.viewport.*`, `resource.pattern.reference`, `resource.pattern.child.*`, `text.content`, `document.structure`, `document.structure.ancestry`, `document.structure.resource_resolution`, and `document.structure.stacking_order` where the supported analyzers apply. The exact emitted subdomain is part of the report contract; the broader future taxonomy remains roadmap work.

`compositing.opacity` describes non-inherited container opacity on an isolated completed child layer. Its source facts and continuous parameter delta are distinct from leaf paint alpha; its rendered magnitude is measured after recursive layer completion and source-over composition. A computed-equivalent source rewrite may therefore retain an Atomic Difference with zero rendered response, while a changed factor can depend on both the group content and its backdrop.

### Difference Magnitude

Magnitude is a vector, not a universal similarity scalar. The current vector can contain:

- absolute and signed canonical parameter delta in local user units;
- symmetric relative delta;
- exact absolute parameter displacement in CSS pixels, as a Comparison Viewport-diagonal fraction, and as an entity-characteristic-size fraction;
- geometry displacement in CSS pixels and viewport fraction;
- a versioned painted-boundary distribution with before/after sample counts and symmetric nearest-boundary mean, nearest-rank p95, and maximum CSS-pixel distances;
- a versioned alpha-only painted-coverage comparison with before/after coverage, absolute difference, and union in CSS square pixels plus a normalized fraction;
- a tagged transform effect containing translation in CSS pixels, rotation or skew in degrees, signed scale, or an exact residual affine matrix;
- presence painted viewport fraction;
- raster changed-pixel fraction;
- RGBA8 and linear-premultiplied-RGBA RMSE;
- an optional intrinsic decoded-raster object with before/after dimensions and, for equal-sized resources, compared pixels, changed pixels, changed-pixel fraction, RGBA8 RMSE, and linear-premultiplied-RGBA RMSE.

Unavailable components are `null`, not numeric zero. Intrinsic raster metrics never populate final-canvas raster fields. When intrinsic dimensions differ, the dimensions remain present and per-pixel metrics are null because schema `1.38` declares no implicit resampling policy. Insertion and deletion additionally use `PresenceMagnitude` to record subject count, geometric bounds, painted area, and viewport fractions from the side on which the content exists where that evidence is available.

For an admitted scalar spatial parameter, `parameter_abs_user_units` is the canonical local numeric delta; exact authored spelling and units remain in `source_fact_before` and `source_fact_after`. `parameter_abs_css_px` applies one complete cumulative directional mapping only when that mapping is equal on both sides; equality means the relevant horizontal or vertical basis vector is equal, or the complete linear part is equal for an undirected radial parameter. It never takes the maximum of conflicting before and after mappings. Non-scaling stroke scalars use an identity mapping, while ordinary stroke width and dash offset require the same isotropic linear scale because an anisotropic transform has no direction-independent scalar conversion. `parameter_viewport_fraction` divides the same CSS value by `hypot(profile.viewport_width, profile.viewport_height)`. `parameter_entity_fraction` divides it by the maximum nonzero diagonal of the before and after conservative painted bounds, measured separately so movement does not inflate its own denominator. Basic-shape coordinates and dimensions, image placement and size, scalar stroke lengths, normalized path coordinates or radii, and decomposed transform translation populate these fields where the mapping is complete and common. A zero-size or unavailable entity, incomplete or conflicting transform, non-spatial scalar, angle, scale, list, categorical value, residual matrix, or context-shared resource parameter leaves the inapplicable fields null.

These parameter fields are exact continuous evidence and do not depend on renderer pixels. `geometry_displacement_css_px` remains separate outcome-oriented geometry evidence. `painted_boundary_displacement` is a pinned-raster observation over isolated alpha support: boundary pixel centers on both sides are mapped to their nearest opposite-side boundary, the directional samples are concatenated, and `symmetric_nearest_boundary_pixels/v1` reports arithmetic mean, nearest-rank p95, and maximum after DPR normalization. Both-empty boundaries produce zero statistics with zero sample counts; one-empty, unsupported-isolation, dimension-mismatch, and budget-exhausted cases remain null. The observation is cached per Subject Alignment and may therefore be shared by several geometry Atomic Differences for one painted outcome. It is not continuous vector Hausdorff distance, soft coverage, color error, visibility, or severity, and it does not replace an independently available analytic geometry outcome.

`painted_coverage_difference` uses the same bounded isolated render pair but compares only normalized RGBA8 alpha. `symmetric_alpha_coverage_l1_over_union/v1` retains before and after alpha sums, their absolute L1 difference, and their per-pixel maximum union in CSS square pixels after division by DPR squared. The normalized fraction is absolute difference divided by union, or measured zero for an empty union. Equal alpha coverage is zero regardless of RGB color; disjoint or one-empty coverage is one. The measurement is symmetric apart from swapping the named side areas and remains separate from boundary motion, event changed pixels, color error, analytic vector area, visibility, and severity.

`DomainOrdering` contains a policy ID and a lexicographic component vector. It orders differences within an exact domain without pretending that geometry, paint, presence, text, and perceptual effects share one natural unit. The complete v2 component, missing-value, and tie-break contract is defined in the [Domain Ordering Policy](domain-ordering.md).

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

A `VisualEvent` is the primary agent-facing grouping unit. In schema `1.38` it records one primary subject ID, referenced Atomic Difference IDs, one rendered outcome, and zero or more Difference Regions.

Current v1 entity events are anchored to one Primary Subject Alignment, and every Atomic Difference has exactly one owning event. All differences that describe that aligned-subject outcome group in the same event even when they reference several Changed Facts or belong to different domains. A stacking relationship uses one document-level relationship event because it relates two alignments; its Changed Fact lists both affected subjects and its regions conservatively retain the complete changed-pixel mask. The event's Rendered Outcome is measured once over the union of its Difference Regions; child magnitudes are not added together.

Changed Facts express causal fan-out rather than event ownership. One Changed Fact may be referenced by distinct Atomic Differences in several events when an inherited declaration or shared resource affects several subjects. Conversely, several Changed Facts may feed the Atomic Differences in one event. This preserves one report identity for every independently reportable distinction without confusing an authored cause with its outcomes.

A resource difference may share one entity event when that entity is its sole mediated outcome. An unreferenced or shared clip-resource change uses its own resource event, while its Changed Facts enumerate every consumer. Other future resource changes with several independent entity outcomes must use a separate resource event and shared Changed Fact references until the project accepts a versioned contextual-event link; assigning the resource Atomic Difference to one arbitrary entity or duplicating it across events is forbidden.

Separate primary alignments remain separate outcome events even when they overlap or are adjacent, share hierarchy, Changed Facts, or resources, or appear visually coherent. A document-level stacking relationship records an evaluated pair; it does not merge either leaf's other outcomes. Cross-subject outcome grouping, separately aligned resource synthesis, and semantic theme detection remain future work. The governing ownership and fan-out decision is [ADR 0040](adr/0040-give-each-atomic-difference-one-event-owner.md); [ADR 0041](adr/0041-defer-cross-subject-event-aggregation.md) requires a measured report-only Agent failure plus a deterministic, traceable, versioned grouping and evaluation policy before that separate boundary can reopen. [ADR 0064](adr/0064-report-only-consequence-aware-structural-relationships.md) defines the relationship-event exception.

### Diagnostic

A `Diagnostic` identifies an unsupported, unresolved, or failed analysis condition, the affected subject, and the evidence layers whose claims are constrained. Its source locations pair a `before` or `after` input role with a half-open UTF-16 Source Span in that input. One Diagnostic may retain several locations when the same stable condition occurs on both sides or at several declarations; a comparison-global synthetic Diagnostic has an empty location array rather than fabricated provenance. `resource_limit_exceeded`, `reference_cycle_detected`, and `reference_expansion_limit_exceeded` use stable failure subjects and make the whole comparison failed instead of exposing a truncated inventory. Diagnostics are part of the result, not debug logging.

### Structured Report

The schema `1.38` top-level object contains exactly these conceptual sections:

```json
{
  "schema_version": "1.38",
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

Each `coverage_matrix` row names one encountered feature and subject, records `covered`, `limited`, `not_applicable`, or `failed` independently for Source Semantics, Computed Appearance, and Rendered Evidence, and references the Diagnostics that justify limitations. `analysis_status` is the summary of those rows, not a separate severity judgment. A `complete` report may contain no differences, small differences, or large differences. A `partial` report can still contain useful supported evidence, but consumers must respect its matrix and Diagnostics. A resource-rejected report contains only failed `resource.<dimension>` rows plus Diagnostics and deliberately empty semantic inventories. The exact caller obligations are defined in the [Analysis Status Contract](analysis-status.md).

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
13. Accepted local-reference graphs are cycle-free and remain within the conservative transitive expansion budget before renderer parsing.

## Not implemented in schema 1.38

The following concepts are intentional future work rather than hidden current fields:

- an agent summary or universal main-difference score;
- explicit Impact Assessment policy and confidence fields;
- exact per-pixel Contribution Index or minimal root-cause set;
- perceptual-background-dependent metrics such as FLIP;
- deterministic font loading, shaping, layout, and glyph evidence;
- resource bundles beyond admitted PNG/JPEG `image` consumers, implicit Comparison Viewport derivation, environment-dependent lengths, arithmetic length functions, and CSS sizing/cascade;
- complete CSS, complete path rendering, exact continuous transformed stroke outlines, marker child paint/cascade/context paint, external or environment-dependent marker semantics, `pathLength` calibration, font-relative stroke lengths, precise transformed localization, visual execution of filter primitives beyond the admitted static `feOffset` graph, CSS filter functions, general mask or clip content, continuous-alpha/container/effect-interacting blending, structural effects outside the admitted aligned-subject and conservative-overlap slice, symbol overflow clipping, and external or dynamic reuse;
- cross-subject Visual Event aggregation.

Their accepted design direction is preserved in the [ADR index](adr/README.md), while their implementation work is tracked only in the [roadmap](../roadmap.md).
