# Core Comparison Model

Status: current model for Structured Report schema `5.0`

Last verified: 2026-08-18

This document defines the concepts and invariants implemented by the current comparison engine. The checked-in [JSON Schema](../schema/svgdiff-report.schema.json) and public MoonBit report types are authoritative for serialized field names. The [current v1 scope](v1-scope.md) defines which SVG features may receive complete analysis; the [roadmap](../roadmap.md) contains future extensions.

## External seam

The root package exposes one conceptual operation:

```text
compare(before_svg, after_svg, comparison_profile) -> structured_report
```

Callers provide two SVG source strings and a Comparison Profile. Parsing, supported source normalization, subject alignment, difference extraction, rendering, magnitude calculation, region extraction, conservative causal attribution, and report assembly remain internal.

The canonical seam always uses script-free secure-static processing. An encountered `<script>`, event handler, or other dynamic construct reduces coverage; the engine never executes it through the parser, renderer, browser oracle, or HTML preview. The accepted [Script Observation boundary](script-execution-boundary.md) permits only a future external target artifact and does not add a fourth evidence layer or extend current equality.

The current seam likewise has no pointer, focus, URL-target, activation, or action-replay input. Unsupported pseudo-classes reduce coverage rather than matching false. A future [Interaction State Profile](interaction-state-profiles.md) would derive one checkpoint through project-owned state and hit-test rules; a browser action transcript and its achieved-state observation remain external and cannot define canonical applicability.

The current seam has no animation timeline and disabled animation is not an animated sample at `t = 0`. The accepted [Animation Timeline Model](animation-timeline-model.md) reserves future exact logical checkpoints for closed declarative subsets, keeps same-document-time, logical-event, effect-phase, and external-frame questions distinct, and does not permit finite samples to establish interval equality.

The current seam also has no host-language layout engine for `foreignObject`. Its outer SVG geometry cannot establish descendant XHTML or other namespace semantics. The accepted [Foreign Content boundary](foreign-object-layout-boundary.md) requires a separately versioned deterministic host-language engine for general canonical support, permits a smaller closed evaluator only for its named subset, and keeps browser output observational.

## Current pipeline

```text
SVG source
  -> authored visual facts and source spans
  -> private typed resource dependency graph
  -> supported computed facts and visual subjects
  -> paint primitives and visual objects on each side
  -> before/after visual object graph alignments with explicit abstention
  -> object-owned primitive subject alignments
  -> changed facts and atomic evidence differences
  -> canonical raster observation and difference regions
  -> conservative cause envelopes
  -> coherent visual change events
  -> private typed analysis graph
  -> concise Structured Report JSON 4.0
```

The typed MoonBit value retains detailed engine evidence for library callers and tests. Its JSON serializer is an intentional product boundary: it emits comparison inputs, whole-canvas measurements, compact Changed Facts, the Visual Object Graph conclusion, grouped Atomic Differences, primitive evidence Events, localization/possible-cause links, and actual limitations. It does not serialize renderer adapters, primitive alignment scoring, source spans, ordering vectors, or Impact bookkeeping. See the [concise JSON contract](agent-json.md).

Source, computed, and rendered evidence are related but never interchangeable. For example, `red` and `#ff0000` may be a source-level distinction with equivalent computed paint and zero rendered error. Conversely, unsupported semantics can make computed or rendered equality indeterminate even when no supported source difference was found.

## Comparison Profile

The internal `ComparisonProfile` records:

- `viewport_width` and `viewport_height`;
- `comparison_dpr`, fixed to `1.0` by the root v1 seam;
- `color_interpretation`, fixed to `srgb`;
- `raster_representation`, fixed to `linear_srgb_premultiplied_rgba_f64`;
- `renderer_id`, currently fixed by the producer to `svgdiff/residual-paint-normalizer@1+opacity-used-value-normalizer@1+length-unit-normalizer@1+shape-css-points-normalizer@1+stroke-length-normalizer@1+mask-edge-semantics-normalizer@1+isolated-group-compositor@1+static-mask-compositor@1+empty-filter-outcome-adapter@1+static-blend-compositor@1+Milky2018/svg@0.3.1`.
- `renderer_conformance_profile_id`, currently fixed by the producer to `svgdiff-renderer-conformance-profile/27`.
- `perceptual_background`, either null or one explicit normalized opaque sRGB8 color for display-dependent measurements.
- `flip_viewing_conditions`, either null or one explicit finite `pixels_per_degree` value in the supported `[1, 4096]` range.
- `flip_error_threshold`, either null or one explicit finite FLIP reporting threshold in `[0, 1]`.

The root `compare` function preserves the caller-supplied viewport dimensions, optional Perceptual Background, optional FLIP Viewing Conditions, and optional FLIP error threshold while canonicalizing the other fields to the v1 defaults. The CLI defaults the common viewport to `16 x 16`, accepts explicit positive dimensions through `--width` and `--height`, records an opaque deterministic sRGB color through `--perceptual-background COLOR`, opts into LDR-FLIP through `--flip-pixels-per-degree PPD`, and records thresholded area only through `--flip-error-threshold VALUE`. It never guesses display geometry or a perceptual threshold.

The Perceptual Background is profile evidence, not SVG paint and not a renderer clear color. Schema `5.0` continues to compute all raw pixels, magnitudes, regions, equality, and coverage on the transparent canvas. Event-local DeltaEOK and LDR-FLIP independently composite both raw event pixels over exactly this normalized color in linear sRGB. When the background is null, display-dependent measurements are unrequested rather than guessed; the concise JSON omits unrequested measurements.

`schema_version` identifies the serialized report shape, `renderer_id` identifies the complete production rendering implementation including project-owned adapters, and `renderer_conformance_profile_id` identifies the reviewed fixture, disposition, guard, and future tolerance policy that bounds Rendered Evidence claims. None can substitute for another. JSON Schema verifies that renderer identities are present and structurally valid; the versioned compatibility policy decides which concrete identities a consumer accepts.

One Structured Report always represents one before/after execution under one Comparison Profile and renderer identity. The accepted [multi-renderer boundary](multi-renderer-profiles.md) keeps future same-engine profile sensitivity and cross-engine/browser observations in a separate typed experiment container; it does not turn a report into a renderer aggregate.

The author cascade module is pure and renderer-independent. Presentation attributes, inline declarations, and already-applicable stylesheet candidates share one winner selection over importance, inline/ID/class/type specificity, declaration-source placement, and source order. Inline declaration lists support duplicate properties and terminal case-insensitive `!important` while retaining the winning exact authored value and Source Span. A separate static selector module indexes XML ancestry and element siblings, matches the admitted type, universal, ID, class, attribute-presence, exact-attribute-value, compound, list, descendant, child, adjacent-sibling, and general-sibling scope, and supplies matched candidates without learning cascade priority rules. Unsupported selector grammar remains guarded rather than approximated.

`Milky2018/svg@0.3.1` directly owns the tested renderer-side cascade, ordinary inheritance, CSS-wide and computed values, numeric shape geometry, numeric dash semantics, mask-content paint, and valid admitted filter graphs. svgdiff no longer materializes those values into private renderer copies. Source Semantics, Source Spans, Changed Facts, Diagnostics, resource admission, and HTML source display continue to use the original SVG strings and the project-owned analyzer independently from renderer ownership.

The remaining renderer-input normalization is residual and evidence-backed. It resolves authored length units that 0.3.1 does not yet consume, inline CSS shape geometry, compact point syntax, unsupported native named colors, fractional color-alpha multiplication, inherited paint opacity, and paint state needed by detached project compositor branches. Numeric presentation geometry, ordinary paint and stroke inheritance, and native numeric dash behavior pass through unchanged. Authored values remain unchanged in Source Semantics. Rounded rectangles and polygons retain separate raster-conformance guards because canonical used geometry does not by itself prove browser-equivalent antialiasing.

Stroke analysis remains project-owned even though native numeric stroke rendering is delegated. The analyzer resolves length-aware width, dash arrays, and dash offsets plus caps, joins, miter limits, and `vector-effect`. Odd dash arrays duplicate, all-zero arrays become solid, and effective offsets normalize by the even pattern sum. Only unsupported authored stroke length units are materialized for rendering. Stroke-none, zero-width, and topology-specific inactive properties retain authored differences while comparing their computed effects as equivalent. Width differences retain both the full parameter delta and the transform-aware half-width boundary displacement; non-spatial scalar controls do not claim a Cartesian displacement. Active stroke outline, join, dash, and non-scaling-stroke pixels retain separate renderer-conformance guards.

Marker adaptation is renderer-independent. The engine retains authored `marker` shorthand and longhand facts, resolves supported local fragment references, and extracts canonical length-aware `markerUnits`, viewport size, reference point, orientation, `viewBox`, `preserveAspectRatio`, and hidden overflow facts. Each admitted shape is converted to its SVG equivalent path vertices; start, mid, and end roles preserve closed-subpath duplication and zero-length direction search. Automatic orientation uses segment tangents and mid-vertex bisectors, while `auto-start-reverse` reverses only start instances. Placement, orientation, stroke-width or user-space units, viewport mapping, reference offset, and subject transforms produce a conservative clipped marker viewport envelope. Resource changes use `resource.marker.*` domains and attribute every referenced instance through `affected_subject_ids`. Marker child paint, cascade/inheritance, context paint, environment-dependent lengths or visible overflow, external references, and pinned-renderer pixels remain explicitly guarded.

Intrinsic viewport derivation, fonts, alternate perceptual backgrounds or color spaces, alternate DPRs, wide-gamut profiles, and cross-renderer profiles are not part of the implemented v1 profile. The accepted [color-management boundary](color-management-profiles.md) defines the separately identified executable layers and staged candidates required before any beyond-sRGB profile can be added; it does not change current behavior. Other accepted target decisions remain recorded in ADRs and the roadmap.

Explicit resource bundles are inputs to comparison rather than ambient profile state. Before and after each receive an ordered set of opaque locator, MIME, and byte entries. Exact locator matching can resolve admitted PNG/JPEG `image` resources; no base URL, filesystem path, redirect, or network environment participates. The report retains authored locator Source Spans and compact content hashes but never serializes supplied bytes or CLI resource-file paths.

The accepted future [Resource Snapshot Bundle](general-resource-snapshot-bundles.md) is a parallel contract, not a reinterpretation of those opaque keys. It binds each side to an explicit root URL, complete logical request identities, response or failure snapshots, exact representation bytes, recursive closure, and independent acquisition provenance while permanently retaining zero comparison-time I/O. No generalized bundle, URL resolver, or prefetcher is implemented.

## Evidence layers

### Source Semantics

Source Semantics describes supported authored visual declarations after formatting normalization while retaining provenance. A `DeclaredVisualFact` records immutable source evidence selected by the author cascade:

- property name;
- exact authored value;
- normalized declared value;
- declaration origin;
- half-open source offsets.

Attribute order, quote style, tag-closing style, entity spelling, declaration whitespace, and source-offset movement alone do not create Atomic Differences. A change in normalized visual declaration or declaration origin may create a source-level difference even when computed and rendered results remain equal. Cascade, inheritance, computed-value resolution, shorthand expansion, and private renderer normalization never rewrite a fact's authored value, declared value, origin, or half-open UTF-16 Source Span; resolution mode, declaration owner, and inheritance depth carry computed state separately.

Consequently, a complete report with no Atomic Differences cannot distinguish byte-identical SVG inputs from inputs that differ only by excluded formatting variation. It establishes profile-scoped visual equality, not source-byte equality. Supported representation changes such as different color spellings remain distinct because their normalized declared facts differ even when Computed Appearance is equivalent and Rendered Evidence is zero.

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

An unsupported direct primitive is not executed or attribute-normalized. The engine retains its direct-child position, local name, resource-qualified subject ID, and full-subtree offsets, then aligns positions and slices exact source facts only when producing Diagnostics or `resource.filter.primitive.source` differences. If either aligned side is unsupported, one opaque comparison covers its complete element, attributes, namespace spelling, nested nodes, text, comments, insertion, deletion, or type replacement. A shifted sequence may over-report later positions; unknown semantics do not justify stronger matching. Opaque differences name every affected consumer but expose only source semantics, an indeterminate computed relation, no numeric magnitude, no rendered outcome, and no causal-completeness guarantee. When the incomplete graph belongs to a resolved same-document filter, its normative filter region remains a conservative computed-bounds Difference Region because every possible primitive output is clipped there; this includes opaque SVG shadow primitives without pretending their shadow pixels were computed. Invalid or external filter functions without a resolved resource region remain unlocalized. Both-side admitted `feOffset` pairs retain their finer facts. Malformed XML remains a failed input, and direct metadata children remain outside the visual inventory.

Static blending resolves non-inherited CSS `mix-blend-mode` and `isolation` without treating same-named XML attributes as presentation attributes. The admitted binary-alpha slice renders explicit-ID opaque integer rectangles in source order: ordinary groups share the current backdrop, `isolation:isolate` on the root SVG or an authored-ID `g` starts a transparent layer and composites it once, and each non-normal leaf uses the W3C separable or non-separable formula before source-over. `compositing.blend_mode` and `compositing.isolation` are categorical; their differences retain exact declarations, computed keywords, affected foreground and conservative nearest-boundary backdrop-prefix subjects, measured pixels, and no universal scalar between modes. Their complete Cause Envelopes query those operation participants and union tokens from every event sharing the exact Difference Region, so simultaneous backdrop or order changes remain candidates without forcing a disjoint later subject into the region. Structural stacking outcomes call the same product compositor. Continuous alpha, antialiasing, transforms, strokes, instances, container blend modes, anonymous or instance isolation hosts, and other effect interactions preserve source facts behind precise Diagnostics.

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

`RenderedEvidence.perceptual_color` is a separate availability channel. With a declared background and available raw images, `delta_e_ok_changed_pixels_after_linear_srgb_background/v1` selects the exact raw-different pixels attributed to the event, composites each side over the same background in linear sRGB, converts the opaque results to OKLab, and reports sample count plus arithmetic mean DeltaEOK. Zero selected samples and composited equality are measured zero. Missing background and unavailable raw images have distinct not-computed reason codes. This is not a visibility test, JND threshold, severity label, FLIP value, or Impact Assessment.

`RenderedEvidence.perceptual_flip` is an independent optional spatial channel. With declared FLIP Viewing Conditions, the same explicit background, and available raw images, `nvlabs_ldr_flip/v1.7-b475eb4b` uses the before rendering as reference and context, then forms an event-specific candidate by replacing only exact raw-different pixels inside that event's Difference Regions with their after values. The serialized row-major uint16 big-endian base64 map covers the selected-pixel bounds expanded by the complete spatial and feature response radius; additional convolution context is not serialized. The underlying fixed-pair metric is symmetric, but event isolation is directional when other events change the surrounding context, so reversing the comparison creates a new before-context map. The report records bounds, encoding, quantization step, and method identity. A zero-selected-pixel event has an explicit empty computed map, while unrequested computation, absent background, unavailable rendering, and map-budget exhaustion have distinct not-computed reasons. The map is not equality, a visibility boolean, a pooled statistic, severity, or Impact Assessment.

Every computed map also carries `event_local_ldr_flip_pooling/v1` statistics calculated before uint16 transport quantization. `canvas_mean` divides the response sum by the complete canvas pixel count, `event_region_mean` samples only raw-different event-selected pixels, and `response_p95` plus `response_maximum` sample the complete serialized response bounds. The report retains all three counts. `area_above_threshold` is null unless the profile records an explicit threshold; when present, it records strict-above response pixels and their whole-canvas fraction. These are separate observations with explicit denominators, not equality, visibility, severity, or Impact Assessment.

## Report records

### Renderer Capability Gap

`renderer_capability_gaps` is an encountered-input projection of renderer-specific Diagnostics. Each `RendererCapabilityGap` records a stable capability ID, a `guarded` or `unavailable` support status, and every Diagnostic ID that establishes the gap for this comparison. `guarded` means a renderer observation may remain numeric but cannot support a complete conformance claim; `unavailable` means the required renderer behavior cannot currently supply accepted evidence.

The array does not enumerate capabilities unused by the inputs. An empty array therefore means only that no known renderer gap was encountered; it is not a global renderer support claim. Analysis status, per-feature coverage, and Diagnostics remain authoritative, and non-renderer analyzer gaps do not appear in this projection.

### Subject Reference and Subject Alignment

A `SubjectReference` identifies a report subject by source index, SVG kind, optional authored ID, and optional `SubjectInstanceContext`. A direct subject has null instance context. A subject rendered through `use` records a deterministic instance ID, its unchanged definition subject ID, and the outer-to-inner use-host path. Authored IDs and source order remain evidence rather than authoritative cross-document identity; instance paths establish placement identity without manufacturing cloned source declarations.

A `SubjectAlignment` relates sets of before and after subjects and declares whether they are Visual Entities or Visual Resources. Its relation may express correspondence, insertion, deletion, split, or merge. Rendered leaf subjects reached through `use` first align by exact instance path and kind; direct shapes use transform- and bounds-aware exact visual signatures, split/merge rules, and the bounded `rendered_geometry_feature_distance_v1`. That minimum-cost feature combines conservative device-space geometry, non-geometry appearance, hierarchy, and normalized path evidence under the actual Comparison Viewport. Paths participate through normalized device-space segment parameters rather than raw `d` spelling. The score selects correspondence only; it is not a Difference Magnitude, equality proof, or confidence.

Schema `1.32` adds a separate source-structural alignment inventory for `g`, `text`, `use`, and visual definitions. Schema `1.33` makes rendered-leaf correspondence transform- and bounds-aware. Schema `1.34` groups equal-cardinality duplicates with the same exact rendered and reportable source-semantic signatures into one set-to-set equivalence class and matches structural subjects by an ID- and sibling-order-independent recursive semantic signature before authored-ID, path, or stable-order fallback. The source-semantic guard retains visually equivalent authoring differences as reportable one-to-one changes. Array order preserves provenance only; it does not define pairwise identity inside a repeated class. The production corpus validates one-to-one, insertion, deletion, split, merge, and exact many-to-many cardinalities without adding identity claims.

The typed model gives every alignment a closed `entity` or `resource` role. Groups, text, use hosts, rendered shapes, and image placement remain entity alignments. Symbols, gradients, patterns, markers, clip paths, masks, filters, and intrinsic image content use independent resource alignments. Every resource Atomic Difference names a resource-role alignment; resource-mediated entity outcomes keep their entity alignments and Changed Fact fan-out. Matching resource definitions, including renamed definitions, is correspondence evidence only and does not prove computed consumer equality or rendered equality. An SVG `image` therefore legitimately has both alignments over the same source reference: one for acquired or decoded content and one for placement. Text correspondence still does not imply font, shaping, glyph, or rendered equality. Unequal-cardinality or mixed-change repeated clusters remain roadmap work.

Rendered subjects owned by an extracted entity object are paired only inside
the accepted Visual Object Alignment. Graphic subjects with the same authored
identity use the same constraint; anonymous graphics retain the primitive
split/merge and exact-equivalence rules. An unresolved object correspondence
therefore cannot leak into a confident cross-object primitive pairing.

Equally plausible minimum-cost matches abstain instead of using deterministic
order as identity. A locally ambiguous edge is rejected even when it appears
in one globally minimal assignment. The [v1 Subject Alignment policy](alignment-tie-breaking.md)
still fixes deterministic report order and records score kind, selected score,
candidate counts, and ambiguity for accepted pairs. `confidence` remains null
with `confidence_status: "not_calibrated"`; neither a global optimum nor local
uniqueness is an identity proof.

This alignment uncertainty is independent from computed interpretation uncertainty. The latter is represented by `ComputedRelation.status: indeterminate`, resolving Diagnostic IDs, and limited Computed Appearance coverage. It is not assigned an invented probability or merged with alignment confidence.

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

Unavailable components are not numeric zero. Intrinsic raster metrics never populate final-canvas raster fields. When intrinsic dimensions differ, the dimensions remain present and per-pixel metrics are omitted from JSON because schema `5.0` declares no implicit resampling policy. Insertion and deletion additionally use `PresenceMagnitude` to record subject count, geometric bounds, painted area, and viewport fractions from the side on which the content exists where that evidence is available.

For an admitted scalar spatial parameter, `parameter_abs_user_units` is the canonical local numeric delta; exact authored spelling and units remain in `source_fact_before` and `source_fact_after`. `parameter_abs_css_px` applies one complete cumulative directional mapping only when that mapping is equal on both sides; equality means the relevant horizontal or vertical basis vector is equal, or the complete linear part is equal for an undirected radial parameter. It never takes the maximum of conflicting before and after mappings. Non-scaling stroke scalars use an identity mapping, while ordinary stroke width and dash offset require the same isotropic linear scale because an anisotropic transform has no direction-independent scalar conversion. `parameter_viewport_fraction` divides the same CSS value by `hypot(profile.viewport_width, profile.viewport_height)`. `parameter_entity_fraction` divides it by the maximum nonzero diagonal of the before and after conservative painted bounds, measured separately so movement does not inflate its own denominator. Basic-shape coordinates and dimensions, image placement and size, scalar stroke lengths, normalized path coordinates or radii, and decomposed transform translation populate these fields where the mapping is complete and common. A zero-size or unavailable entity, incomplete or conflicting transform, non-spatial scalar, angle, scale, list, categorical value, residual matrix, or context-shared resource parameter leaves the inapplicable fields null.

These parameter fields are exact continuous evidence and do not depend on renderer pixels. `geometry_displacement_css_px` remains separate outcome-oriented geometry evidence. `painted_boundary_displacement` is a pinned-raster observation over isolated alpha support: boundary pixel centers on both sides are mapped to their nearest opposite-side boundary, the directional samples are concatenated, and `symmetric_nearest_boundary_pixels/v1` reports arithmetic mean, nearest-rank p95, and maximum after DPR normalization. Both-empty boundaries produce zero statistics with zero sample counts; one-empty, unsupported-isolation, dimension-mismatch, and budget-exhausted cases remain null. The observation is cached per Subject Alignment and may therefore be shared by several geometry Atomic Differences for one painted outcome. It is not continuous vector Hausdorff distance, soft coverage, color error, visibility, or severity, and it does not replace an independently available analytic geometry outcome.

`painted_coverage_difference` uses the same bounded isolated render pair but compares only normalized RGBA8 alpha. `symmetric_alpha_coverage_l1_over_union/v1` retains before and after alpha sums, their absolute L1 difference, and their per-pixel maximum union in CSS square pixels after division by DPR squared. The normalized fraction is absolute difference divided by union, or measured zero for an empty union. Equal alpha coverage is zero regardless of RGB color; disjoint or one-empty coverage is one. The measurement is symmetric apart from swapping the named side areas and remains separate from boundary motion, event changed pixels, color error, analytic vector area, visibility, and severity.

`DomainOrdering` contains a policy ID and a lexicographic component vector. It orders differences within an exact domain without pretending that geometry, paint, presence, text, and perceptual effects share one natural unit. The complete v2 component, missing-value, and tie-break contract is defined in the [Domain Ordering Policy](domain-ordering.md).

The raw magnitude fields remain authoritative beneath the required Impact Assessment. The current policy uses only named Visual Event rendered fields, retains missing evidence instead of inventing zero, and cannot create, erase, or redefine an Atomic Difference. The complete boundary is defined in [Raw Magnitudes and Impact Assessment](impact-assessment.md).

The [terminal multidimensional magnitude gate](../evaluation/terminal-magnitude-gate/README.md) validates this preservation boundary across exact parameter scales, tagged transforms, painted boundary, alpha coverage, presence, scene and intrinsic raster, DeltaEOK, and LDR-FLIP evidence. Its production `1.0` to `0.99999` probe retains the approximate `0.00001` CSS-pixel parameter displacement beside a separately measured 1-pixel pinned-raster boundary maximum; neither value replaces the other.

### Difference Region

A `DifferenceRegion` localizes an event using an event-isolated pixel-mask candidate, a bounds-filtered canvas candidate, or conservative computed bounds. It records pixel-space and CSS-space bounds, changed-pixel count, viewport fraction, and a Cause Envelope.

All current Event regions are `conservative`. The isolated candidate intersects final changed pixels with a supported isolated before/after rendering of the aligned entity and its spatial envelope. The bounds-only candidate contains final changed pixels that merely overlap the Event's envelope; a computed-bounds candidate is used when rendered pixels are unavailable. Isolation can safely remove pixels and prove an empty Event, but it cannot prove contribution through occlusion or compositing. `observed` is reserved for a future scene-level counterfactual or renderer contribution method.

Isolation currently admits entity Events containing only geometry, paint, or presence differences whose aligned subjects have complete geometry, stroke, transform, clip, mask, filter, marker, resource, and paint-server behavior. It uses fixed per-channel comparison and raster-work limits. An ineligible or over-budget Event keeps the wider conservative localization. Equal isolated renderings receive no region and a measured zero outcome even when another Event changes overlapping canvas pixels. [ADR 0109](adr/0109-keep-event-localization-conservative-without-contribution-evidence.md) defines this evidence boundary.

Localization retains private `before` and `after` bounds until the event is attached to regions. Movement therefore preserves both occupied extents, insertion preserves only the `after` extent, and deletion preserves only the `before` extent. Ordinary subjects, embedded images, markers, group opacity, clips, masks, and filters compute those sides independently; only their conservative union is exposed through the event's regions. The report does not serialize side-specific bounds, side-specific pixels, an exact mask, or a contribution map.

### Cause Envelope

A `CauseEnvelope` is a conservative set of Changed Fact IDs that may have caused one Difference Region. Its guarantee is either:

- `sound_overapproximation`: within complete analysis coverage, every actual changed cause is included, although false positives may remain;
- `not_established`: unsupported or unresolved semantics prevent the completeness guarantee.

The engine may safely widen an envelope to all Changed Facts when it lacks a sound independence rule. It must not prune candidates speculatively. The detailed contract and proof discipline live in [Influence Provenance and Causal Completeness](influence-provenance.md).

For complete source-input propagation, the engine retains every fact directly linked to an event and queries a private token index built from `ChangedFact.affected_subject_ids`. Entity events use the before/after rendered identities of their Subject Alignment, including use-instance identity and one-sided presence; resource and relationship events use their direct facts' conservative affected-subject fan-out. Supported group, clip, mask, filter, blend, isolation, and stacking events additionally union their analyzer-owned operation participants, while exact shared-region identity carries concurrent event tokens. Unsupported, partial, or empty-candidate paths retain the broader comparison fallback. Neither path is an exact contribution claim.

### Visual Object Graph and causal change hierarchy

A `VisualObject` groups one or more paint primitives around evidence of a
user-perceived object. Text inventories, authored identities, spatial bounds,
primitive composition, and effective style are independent evidence channels;
an exact unique authored identity may establish correspondence, while weaker
channels require compatible independent evidence. `ObjectAlignment` supports
1:1 and set-to-set correspondences and explicitly emits `unresolved` when no
candidate clears its acceptance rule. Unresolved correspondence makes affected
scene axes `indeterminate`; it is not rewritten as insertion plus deletion.
Relations retain resolved object endpoints, so graph preservation is
established from topology rather than equal edge counts.

A Visual Part is currently represented by the rendered subject IDs listed in a
Visual Object's `subjects` field. These subjects remain the measurement and
localization units, but their candidate correspondence is constrained by the
owning Visual Object before primitive alignment runs. This is an internal
ownership relation, not a claim that SVG element boundaries always coincide
with human object boundaries.

A `VisualObjectChange` is the only bridge from subject-level evidence to a
user-perceived object. It owns exactly one accepted Visual Object Alignment and
records all supporting Atomic Difference IDs, primitive Event IDs, and canonical
Changed Fact IDs without copying their payloads. One Changed Fact may fan out
through many Atomic Differences and Object Changes. An entity alignment with
ambiguous object ownership remains unresolved; a shared container or resource
cause may fan out only through its explicit affected-subject provenance.

A `VisualSceneChange` is the primary agent-facing conclusion. Its orthogonal
axes are content, object presence, relation graph, layout, effective style, and
representation. It is derived exclusively from Object Change IDs and never
scans Atomic Differences. `scope` is `object`, `systemic`, or `comparison`;
a systemic change is one same-kind connected component spanning several Object
Changes through shared Changed Fact IDs. Same-kind Object Changes without a
shared causal path remain separate, and Object Changes without cause IDs are
never merged by resemblance alone.
It reports separate cardinalities for unique Changed Facts (`causes`), unique
Atomic Differences (`effects`), affected primitive subjects, and Visual Objects.
These numbers must not be substituted for one another.

`scene.evidence_coverage` audits both aggregation transitions. At
`difference_to_object`, every non-`equivalent` Atomic Difference is either in
the unique union of Object Change evidence or counted as unresolved with a
domain cardinality. `indeterminate` evidence remains unresolved unless a future
typed Object Change explicitly models it. At `object_to_scene`, every Object
Change is either referenced by a Scene Change or retained as a residual kind.
Aggregation can therefore shorten the primary conclusion without deleting
unassigned evidence.

### Primitive evidence Event

A `VisualEvent` is the primitive evidence grouping unit. In schema `5.0` it records one subject, referenced Atomic Difference IDs, one rendered outcome, and zero or more Difference Regions. It supports measurement and localization; it is not the primary semantic conclusion.

Current v1 entity events are anchored to one Primary Subject Alignment, and every Atomic Difference has exactly one owning event. All differences that describe that aligned-subject outcome group in the same event even when they reference several Changed Facts or belong to different domains. A stacking relationship uses one document-level relationship event because it relates two alignments; its Changed Fact lists both affected subjects and its regions conservatively retain the complete changed-pixel mask. The event's Rendered Outcome is measured once over the union of its Difference Regions; child magnitudes are not added together. When isolated painted-boundary or coverage observations agree across an event's children, concise JSON serializes them once as the event's shared isolated-subject evidence. It does not claim that every child independently produced that result. For conservative regions this is a bounded canvas response, not an exact contribution measurement.

Changed Facts express causal fan-out rather than event ownership. One Changed Fact may be referenced by distinct Atomic Differences in several events when an inherited declaration or shared resource affects several subjects. Conversely, several Changed Facts may feed the Atomic Differences in one event. This preserves one report identity for every independently reportable distinction without confusing an authored cause with its outcomes.

A resource difference may share one entity event when that entity is its sole mediated outcome. An unreferenced or shared clip-resource change uses its own resource event, while its Changed Facts enumerate every consumer. Other future resource changes with several independent entity outcomes must use a separate resource event and shared Changed Fact references until the project accepts a versioned contextual-event link; assigning the resource Atomic Difference to one arbitrary entity or duplicating it across events is forbidden.

Separate primary alignments remain separate primitive outcome events and every
Atomic Difference still has exactly one primitive Event owner. Object Changes
reference those effects; Scene Changes reference only Object Changes. This
typed DAG preserves ADR 0040 while superseding the direct Atomic-to-Scene
projection after the banking cross-generator case exposed its fragmentation and
cause-counting failure. ADR 0110 still defines ownership-constrained alignment;
ADR 0111 defines the causal aggregation policy.

### Impact Assessment

`ImpactAssessment` is a derived top-level view over the complete Visual Event inventory. Policy `event_rendered_pareto/v1` compares only each event's whole-canvas `changed_pixel_fraction` and `linear_premultiplied_rgba_rmse`. An event belongs to the main frontier when no other event is greater than or equal in both dimensions and strictly greater in at least one.

Equal measured vectors form one tie group; different non-dominated vectors remain incomparable groups. Missing rendered magnitudes form a separate null-measurement group, make the assessment partial, and are never treated as zero. Every group links back to all contributing event and Atomic Difference IDs. Every dominated event receives one deterministic witness naming the lexically first event that dominates it. The policy is explicitly not calibrated and supplies no severity label, visibility claim, scalar score, or total order.

Impact is a context-free derived view, not the complete event inventory. Caller-supplied semantic concern is external query context: when it resolves to report evidence, every matching dominated event remains reportable through the full event, Atomic Difference, region, and cause chain. The engine does not infer concern from authored identifiers, text, spatial extent, or magnitude. Without resolvable context, semantic importance is unknown. [ADR 0091](adr/0091-separate-query-concern-from-context-free-impact.md) defines this boundary.

### Diagnostic

A `Diagnostic` identifies an unsupported, unresolved, or failed analysis condition, the affected subject, and the evidence layers whose claims are constrained. Its source locations pair a `before` or `after` input role with a half-open UTF-16 Source Span in that input. One Diagnostic may retain several locations when the same stable condition occurs on both sides or at several declarations; a comparison-global synthetic Diagnostic has an empty location array rather than fabricated provenance. `resource_limit_exceeded`, `reference_cycle_detected`, and `reference_expansion_limit_exceeded` use stable failure subjects and make the whole comparison failed instead of exposing a truncated inventory. Diagnostics are part of the result, not debug logging.

### Structured Report

The schema `5.0` JSON object contains exactly these product-facing sections:

```json
{
  "schema_version": "5.0",
  "analysis_status": "complete | partial | failed",
  "comparison": {},
  "canvas": {},
  "changed_facts": [],
  "scene": {},
  "difference_groups": [],
  "events": [],
  "limitations": []
}
```

`canvas` compares the two final rendered canvases exactly once and retains
changed pixels, changed fraction, and linear-premultiplied-RGBA RMSE. Optional
perceptual response appears only when requested and computed. A measured zero
is explicit; inapplicable and unrequested values are omitted; blocked expected
measurements are explained through `limitations`.

`changed_facts` contains each canonical cause once in compact form. `scene`
contains the Visual Objects and relations on both sides, explicit object
alignments, Object Changes, the six-axis conclusion, and coherent Scene Changes.
An `indeterminate` axis is never rewritten as preserved merely because counts
match or the primitive matcher found no supported difference. Its evidence
coverage counts establish both Atomic-to-Object and Object-to-Scene accounting.

`difference_groups` contains every Atomic Difference under one stable visual
category. Each item retains local authored before/after values, its effective
relation, and only the magnitudes direct to that independent difference.
`events` link those IDs to rendered outcomes, optional shared isolated-subject
measurements, CSS-space regions, and conservative possible causes.
`limitations` is the compact product projection of internal Diagnostics.

The typed engine result may retain richer coverage, alignment, provenance,
resolution, ordering, and attribution state for testing and composition. None
of that implementation state is part of schema `5.0` JSON. The exact caller
obligations are defined in the [Analysis Status Contract](analysis-status.md).

## Current invariants

1. Formatting-only XML and declaration changes do not become Atomic Differences.
2. Supported authored distinctions remain reportable even when computed values are equivalent or rendered magnitude is zero.
3. Unsupported semantics cannot produce a false claim of complete equality.
4. `equivalent`, `different`, `indeterminate`, and `not_applicable` remain distinct computed states.
5. Measured zero is serialized; inapplicable or unrequested measurements are omitted; blocked expected measurements link to limitations.
6. Every serialized Atomic Difference retains its local authored values, effective relation, subject, category, and all direct computed magnitudes; every Scene Change cause reference resolves to one compact Changed Fact.
7. Object and Scene aggregation do not delete or merge away Atomic Differences.
8. Final raster response and agreeing isolated-subject observations are serialized once on the owning event, never copied onto every child as if each independently contributed them.
9. Every reported Difference Region carries a Cause Envelope.
10. A Cause Envelope claiming `sound_overapproximation` may contain false positives but must contain every actual changed cause within the supported coverage boundary.
11. Dependency-specific XML, SVG scene, image, and renderer types do not cross the public report seam.
12. Object alignment may abstain; a rejected many-to-many candidate is explicit `unresolved` evidence rather than a forced match or fabricated insertion/deletion conclusion.
13. A preserved relation graph requires resolved endpoints and equal aligned topology, not merely equal relation counts.
14. Entity subjects cannot pair across accepted Visual Object Alignment ownership, and ambiguous minimum-cost subject pairs abstain.
15. Scene evidence coverage satisfies `assigned_difference_count + unresolved_difference_count == effective_difference_count` and `assigned_object_change_count + residual_object_change_count == object_change_count`.
16. Scene Changes reference Object Changes only; no Scene Change directly references an Atomic Difference or primitive Event.
17. HTML is a presentation of the Structured Report and must not recompute semantic differences.
18. Identical inputs and Comparison Profiles produce deterministic array order and report-local IDs; every serialized report-local reference resolves within the report.
19. Accepted local-reference graphs are cycle-free and remain within the conservative transitive expansion budget before renderer parsing.

## Not implemented in schema 5.0

The following concepts are intentional future work rather than hidden current fields:

- a universal main-difference scalar or generated natural-language summary;
- calibrated Impact Assessment thresholds, labels, confidence, or total ordering;
- a caller Concern Profile, source-derived semantic priority, or concern-aware event ranking;
- exact per-pixel Contribution Index or minimal root-cause set;
- calibrated perceptual importance derived from DeltaEOK, FLIP, or other measurements, and canonical SSIM/MS-SSIM report fields or equality meaning;
- deterministic font loading, shaping, layout, and glyph evidence;
- resource bundles beyond admitted PNG/JPEG `image` consumers, implicit Comparison Viewport derivation, environment-dependent lengths, arithmetic length functions, and CSS sizing/cascade;
- complete CSS, complete path rendering, exact continuous transformed stroke outlines, marker child paint/cascade/context paint, external or environment-dependent marker semantics, `pathLength` calibration, font-relative stroke lengths, precise transformed localization, visual execution of filter primitives beyond the admitted static `feOffset` graph, CSS filter functions, general mask or clip content, continuous-alpha/container/effect-interacting blending, structural effects outside the admitted aligned-subject and conservative-overlap slice, symbol overflow clipping, and external or dynamic reuse;
- calibrated semantic theme recognition beyond the implemented systemic scene patterns.

Their accepted design direction is preserved in the [ADR index](adr/README.md), while their implementation work is tracked only in the [roadmap](../roadmap.md).
