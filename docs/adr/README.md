# Architecture Decision Index

ADRs record why a decision was made at a point in time. They are historical records, not a complete description of the current implementation. Unless an ADR says otherwise, its status is accepted. For current behavior, start with the [documentation guide](../README.md).

## Report and evidence model

| ADR | Status | Decision |
| --- | --- | --- |
| [0001](0001-group-atomic-differences-into-visual-events.md) | Accepted | Group Atomic Differences into Visual Events. |
| [0002](0002-deliver-a-self-contained-html-report.md) | Accepted, implemented | Deliver a self-contained HTML report. |
| [0003](0003-base-diff-identity-on-visual-correspondence.md) | Superseded by 0005 | Base identity on visual correspondence. |
| [0004](0004-record-differences-at-three-evidence-layers.md) | Accepted | Preserve source, computed, and rendered evidence layers. |
| [0005](0005-use-set-to-set-entity-alignments.md) | Superseded by 0017 | Use set-to-set entity alignments. |
| [0006](0006-use-render-observations-as-visible-change-evidence.md) | Render-observation decision accepted; exact Contribution Index clause superseded by 0038 | Use render observations as visible-change evidence. |
| [0007](0007-separate-magnitude-evidence-from-impact-policy.md) | Accepted | Separate magnitude evidence from impact policy. |
| [0008](0008-use-domain-specific-ordering-tuples.md) | Accepted | Use domain-specific ordering tuples. |
| [0013](0013-keep-diagnostic-rerendering-outside-the-report.md) | Accepted, implemented | Keep diagnostic rerendering outside the report. |
| [0014](0014-separate-difference-domain-from-computed-relation.md) | Accepted | Separate Difference Domain from Computed Relation. |
| [0015](0015-measure-presence-by-footprint-not-a-boolean.md) | Accepted | Measure presence by footprint rather than a boolean. |
| [0016](0016-visual-entities-may-have-zero-contribution.md) | Accepted | Permit visual subjects with zero rendered contribution. |
| [0017](0017-align-visual-subjects-set-to-set.md) | Accepted | Align Visual Subjects set-to-set. |
| [0018](0018-preserve-evidence-layers-in-visual-event-magnitude.md) | Accepted | Preserve evidence layers in event magnitude. |
| [0019](0019-form-visual-events-around-outcomes.md) | Superseded in part by 0040 | Form Visual Events around outcomes. |
| [0020](0020-anchor-v1-visual-events-to-one-subject-alignment.md) | Refined by 0041 | Anchor each v1 event to one Subject Alignment. |
| [0040](0040-give-each-atomic-difference-one-event-owner.md) | Accepted | Give every Atomic Difference one event owner and express causal fan-out through Changed Facts. |
| [0041](0041-defer-cross-subject-event-aggregation.md) | Accepted | Keep cross-subject aggregation deferred until a measured Agent failure and complete deterministic policy exist. |
| [0042](0042-qualify-diagnostic-spans-by-input-role.md) | Accepted | Qualify Diagnostic Source Spans by before/after input role and preserve multiple locations under one stable Diagnostic. |
| [0043](0043-treat-comparison-interruption-as-control-flow.md) | Accepted | Treat cooperative cancellation and elapsed-time expiry as typed control flow rather than incomplete report evidence. |
| [0044](0044-compare-canonical-report-bundles-across-a-fixed-platform-matrix.md) | Accepted, implemented | Compare canonical report bundles across an explicit three-platform, two-architecture CI matrix. |
| [0045](0045-publish-only-version-matched-cross-platform-release-assets.md) | Accepted, implemented | Publish native archives only from a version-matched tag after cross-platform candidate gates pass. |
| [0047](0047-decompose-paired-cumulative-transforms.md) | Accepted | Decompose paired cumulative transforms into typed domain-specific effects without a raw matrix score. |
| [0048](0048-resolve-svg-viewports-under-one-comparison-viewport.md) | Accepted, implemented for the explicit-profile integer-axis slice | Resolve root and nested SVG viewport mappings without giving the inputs independent raster canvases. |

## Correctness boundary and provenance

| ADR | Status | Decision |
| --- | --- | --- |
| [0009](0009-scope-initial-correctness-to-deterministic-static-svg.md) | Accepted | Scope the initial correctness claim to deterministic static SVG. |
| [0010](0010-guarantee-causal-completeness-with-conservative-provenance.md) | Accepted, implemented for the supported slice | Guarantee causal completeness through conservative provenance. |
| [0021](0021-use-one-resolved-comparison-viewport.md) | Refined by 0048; explicit viewport dimensions and SVG-internal mappings are implemented | Compare both inputs under one resolved viewport. |
| [0022](0022-separate-raw-raster-evidence-from-perceptual-background.md) | Accepted; profile input implemented, compositing pending | Separate raw raster evidence from a perceptual background. |
| [0023](0023-default-the-comparison-dpr-to-one.md) | Accepted, implemented as a fixed v1 value | Default Comparison DPR to one. |
| [0024](0024-use-srgb-semantics-and-linear-srgb-raster-math.md) | Accepted, implemented for the v1 raster metrics | Use sRGB semantics and linear-sRGB premultiplied raster math. |
| [0027](0027-represent-authored-visual-declarations-as-facts.md) | Accepted, implemented for supported properties | Represent authored visual declarations as facts. |

## Dependency and ownership decisions

| ADR | Status | Decision |
| --- | --- | --- |
| [0011](0011-prefer-moonbit-rendering-dependencies-before-owning-a-renderer.md) | Accepted | Prefer MoonBit rendering dependencies before owning a renderer. |
| [0012](0012-own-only-the-smallest-failing-renderer-layer.md) | Accepted | Own only the smallest failing renderer layer. |
| [0025](0025-own-source-semantics-as-a-workspace-module.md) | Superseded by 0026 | Originally own Source Semantics as a workspace module. |
| [0026](0026-adopt-milky-xml-for-authored-parsing.md) | Accepted, implemented | Adopt `Milky2018/xml` for authored parsing. |
| [0046](0046-normalize-style-precedence-at-the-renderer-boundary.md) | Accepted, implemented | Normalize complete supported style conflicts only in private renderer-input copies. |
| [0049](0049-separate-authored-and-used-basic-shape-geometry.md) | Accepted, implemented | Preserve authored geometry while resolving canonical used basic-shape geometry. |
| [0050](0050-resolve-stroke-used-geometry-before-raster-conformance.md) | Accepted, implemented for the unitless static slice | Resolve canonical stroke used geometry independently from renderer conformance. |
| [0051](0051-model-marker-placement-before-child-paint.md) | Accepted, implemented for placement and viewport semantics | Resolve marker placement independently from marker child paint and renderer conformance. |
| [0052](0052-resolve-svg-lengths-with-explicit-context.md) | Accepted, implemented for deterministic absolute and viewport-relative units | Preserve authored length spelling while resolving one explicit used-value context. |
| [0053](0053-separate-cascade-selection-from-selector-matching.md) | Accepted, implemented for author declaration ordering | Select cascade winners independently from stylesheet selector applicability. |
| [0054](0054-bound-static-selector-matching-to-xml-state.md) | Accepted, implemented for the deterministic static profile | Match a bounded selector grammar only from indexed XML ancestry and siblings. |
| [0055](0055-resolve-inheritance-after-cascade-without-reowning-declarations.md) | Accepted, implemented for supported visual properties | Resolve ordinary inheritance after cascade while retaining ancestor ownership and leaf consequences. |
| [0056](0056-resolve-css-computed-values-as-dependencies.md) | Accepted, implemented for supported SVG values | Resolve CSS-wide keywords, custom-property substitution, and currentColor as computed dependencies without rewriting source facts. |
| [0057](0057-keep-declaration-provenance-immutable.md) | Accepted, implemented for supported author declarations | Keep cascade-winner origin and Source Span immutable through inheritance and computed-value resolution. |
| [0058](0058-own-deterministic-solid-color-resolution.md) | Accepted, implemented for deterministic sRGB solid paint | Own strict solid-color and paint-opacity computed values while preserving authored facts and future profile boundaries. |
| [0059](0059-resolve-static-gradients-before-raster-conformance.md) | Accepted, implemented for static same-document sRGB gradients | Resolve complete gradient resources and every consumer independently from guarded raster conformance. |
| [0060](0060-resolve-static-patterns-as-resource-and-consumer-semantics.md) | Accepted, implemented for the admitted static same-document child slice | Resolve pattern tile, viewport, template, and child semantics separately from every consumer and guarded raster evidence. |
| [0061](0061-select-svg-paint-fallbacks-before-resource-mediation.md) | Accepted, implemented for static same-document paint URLs | Select valid resources, local fallback paint, or no paint before resource fan-out while retaining authored declarations. |
| [0062](0062-resolve-inherited-paint-order-and-winding-rules.md) | Accepted, implemented for the admitted static shape slice | Resolve inherited paint order and winding rules by active operation; ADR 0071 later admits the rectangular clip subset. |
| [0063](0063-separate-use-instances-from-authored-definitions.md) | Accepted, implemented for the admitted static same-document slice | Keep authored definition identity separate from deterministic rendered use-instance paths. |
| [0064](0064-report-only-consequence-aware-structural-relationships.md) | Accepted, implemented for the admitted aligned-subject slice | Report structural relationships only when they have an admitted computed, resolution, or stacking consequence. |
| [0065](0065-use-one-private-typed-resource-dependency-graph.md) | Accepted, implemented for the bounded static source grammar | Use one private typed graph for resource topology, reachability, cycle safety, and use-expansion accounting. |
| [0066](0066-decode-embedded-rasters-under-a-bounded-no-io-policy.md) | Accepted, implemented for an explicit PNG/baseline-JPEG subset | Decode bounded embedded rasters into intrinsic evidence without claiming final-canvas rendering. |
| [0067](0067-resolve-only-explicit-caller-supplied-raster-bundles.md) | Accepted, implemented for PNG/JPEG `image` consumers | Resolve only exact caller-supplied resource bytes and retain a zero-implicit-I/O engine boundary. |
| [0068](0068-classify-resource-outcomes-on-independent-axes.md) | Accepted, implemented across the current resource families | Classify locator, target-kind, semantic-validity, graph-safety, and activity outcomes without erasing family-specific evidence. |
| [0069](0069-separate-nonvisual-source-audit-from-visual-diff.md) | Accepted, implemented for descriptive content and metadata attributes | Keep nonvisual source facts out of visual differences and expose an independent audit. |
| [0070](0070-own-isolated-container-opacity-compositing.md) | Accepted, implemented for static `svg`/`g`/`symbol`/`use` opacity | Complete ordered child layers before applying container opacity once, while retaining conservative source-over causes. |
| [0071](0071-resolve-static-rectangular-clips-and-effect-bounds.md) | Accepted, implemented for the admitted static rectangle slice | Separate host attachments from clip resources, preserve consumer fan-out, and localize complete outcomes with conservative effect bounds. |
| [0072](0072-own-static-alpha-and-luminance-mask-semantics.md) | Accepted, implemented for the admitted static rectangle slice | Resolve alpha/luminance mask transfer, deterministic transparent-black outcomes, isolated container application, and conservative effect bounds. |
| [0073](0073-own-bounded-static-filter-offset-graphs.md) | Accepted, implemented for bounded direct static `feOffset` graphs | Resolve ordered graph inputs and results, execute distinct clipped intermediates, report continuous offsets and fan-out, and propagate conservative effect bounds. |
| [0074](0074-own-bounded-static-blending-and-isolation.md) | Accepted, implemented for bounded binary-alpha blending | Resolve categorical blend and isolation properties, composite ordered backdrops, preserve conservative causes, and guard continuous-alpha or effect interactions. |
| [0075](0075-preserve-unsupported-filter-primitives-as-opaque-source-subtrees.md) | Accepted, implemented for unsupported direct filter primitives | Preserve complete position-aligned source subtrees without claiming computed or rendered semantics. |
| [0076](0076-separate-structural-and-rendered-subject-alignment.md) | Accepted, implemented for source-structural subjects | Keep shape geometry alignment separate while aligning groups, text, use hosts, and visual resource definitions with explicit uncertainty. |
| [0077](0077-use-device-space-feature-distance-for-rendered-subject-alignment.md) | Accepted, implemented for rendered leaf subjects | Use transform- and conservative-painted-bounds-aware exact signatures plus a bounded device-space correspondence feature without treating its score as visual magnitude or confidence. |
| [0078](0078-represent-exact-repeated-subjects-as-equivalence-classes.md) | Accepted, implemented for equal-cardinality exact classes | Preserve indistinguishable rendered and structural repeats as set-to-set classes without manufacturing pairwise source-order identity. |
| [0079](0079-validate-safe-alignment-cardinalities-in-the-production-corpus.md) | Accepted, implemented in the curated benchmark | Validate every admitted alignment cardinality through production reports without expanding safe many-to-many membership into mixed-change aggregation. |
| [0080](0080-align-visual-resources-separately-from-entities.md) | Accepted, implemented | Give Visual Resources independent role-typed alignments and attach every resource Atomic Difference without collapsing mediated entity outcomes. |
| [0081](0081-separate-exact-parameter-scales-from-rendered-outcomes.md) | Accepted, implemented | Preserve exact local, CSS-pixel, viewport-relative, and entity-relative parameter scales without substituting boundary, raster, or severity evidence. |
| [0082](0082-report-symmetric-painted-boundary-distributions.md) | Accepted, implemented | Report symmetric nearest-boundary mean, nearest-rank p95, maximum, and sampling support without conflating coverage, color, or importance. |
| [0083](0083-report-symmetric-alpha-coverage-difference.md) | Accepted, implemented | Report alpha-only absolute and union coverage areas plus a symmetric normalized fraction without conflating color or importance. |
| [0084](0084-record-an-explicit-opaque-srgb-perceptual-background.md) | Accepted | Record one optional normalized opaque sRGB background without changing transparent-canvas raw evidence. |
| [0085](0085-measure-event-local-deltaeok-after-explicit-background-compositing.md) | Accepted, implemented | Measure event-local DeltaEOK only after exact shared-background compositing. |

## CLI and distribution decisions

| ADR | Status | Decision |
| --- | --- | --- |
| [0028](0028-use-one-explicit-stdin-stream.md) | Accepted, implemented | Use `-` for exactly one explicit stdin SVG and keep errors off stdout. |
| [0029](0029-use-three-cli-exit-status-classes.md) | Accepted, implemented | Use three stable exit-status classes for reports, failed analysis, and invocation or I/O failures. |
| [0030](0030-compact-canonical-json-for-agent-mode.md) | Accepted, implemented | Compact the canonical report for agent transport without creating a lossy projection. |
| [0031](0031-report-feature-layer-coverage.md) | Accepted, implemented | Report coverage independently per encountered feature and evidence layer. |
| [0032](0032-gate-complete-on-coverage-proof.md) | Accepted, implemented | Require centralized coverage proof obligations before a report may remain complete. |
| [0033](0033-keep-browser-oracle-outside-engine.md) | Accepted, implemented | Keep deterministic Chromium captures as external conformance evidence, not a production engine dependency. |
| [0034](0034-version-renderer-conformance-separately.md) | Accepted, implemented | Version renderer conformance claims independently from schema and renderer identities. |
| [0035](0035-gate-renderer-ownership-with-conformance-evidence.md) | Accepted | Gate renderer ownership with conformance evidence and upstream viability. |
| [0036](0036-report-encountered-renderer-capability-gaps.md) | Accepted, implemented | Report encountered renderer capability gaps without claiming a global support manifest. |
| [0037](0037-version-product-contracts-independently.md) | Accepted, implemented | Version module, report, Diagnostic, ordering, and conformance contracts independently. |
| [0038](0038-defer-exact-contribution-index-until-task-failure.md) | Accepted | Defer exact Contribution Index until a concrete Agent task or precision threshold fails. |
| [0039](0039-do-not-adopt-a-universal-cross-domain-scalar.md) | Accepted | Keep cross-domain Impact Assessment structured rather than adopting a universal scalar. |

Some accepted ADRs intentionally describe a target that is not yet fully implemented. The implementation status above is a navigation aid; [`v1-scope.md`](../v1-scope.md) remains authoritative for current support.
