# MoonBit Library API

Status: current public interface for module version `0.6.0`

Last verified: 2026-07-20

Consumers should import the root package `Milky2018/svgdiff`. The `engine` package owns the concrete report types, while the root package deliberately re-exports them and pins the schema `1.45` comparison conditions.

Install the published module with:

```sh
moon add Milky2018/svgdiff@0.6.0
```

The root registry archive contains only the root, `engine`, and internal `css_color` production packages, generated interfaces, [`PACKAGE.mbt.md`](../PACKAGE.mbt.md), manifest, and license. These library packages support wasm, wasm-gc, JavaScript, and native. The separately versioned `Milky2018/svgdiff-raster-codec` archive contains the project-owned bounded decoder required by the root module. Publish codec `0.1.1` before root `0.6.0`; consumers still import only the root package. `sh scripts/test-module-package.sh` validates both inventories, runs MoonBit's packaged-source checks, and compiles a separate workspace consumer against both generated zips. The published [Mooncakes root module](https://mooncakes.io/docs/Milky2018/svgdiff) uses the same module version as the CLI engine identity.

Public source and behavior compatibility follows the [module SemVer rules](versioning.md#moonbit-module-semver). Before `1.0.0`, breaking changes increment the minor component and patch releases remain backward-compatible.

## Public operations

```text
compare(String, String, ComparisonProfile) -> StructuredReport
compare_with_resources(String, String, ComparisonProfile, ResourceBundle, ResourceBundle) -> StructuredReport
compare_with_control(String, String, ComparisonProfile, ComparisonControl) -> StructuredReport raises ComparisonInterrupted
compare_with_control_and_resources(String, String, ComparisonProfile, ResourceBundle, ResourceBundle, ComparisonControl) -> StructuredReport raises ComparisonInterrupted
audit_nonvisual_metadata(String, String) -> SourceAuditReport
render_html_report(String, String, StructuredReport) -> String
render_markdown_summary(StructuredReport) -> String
ComparisonProfile::v1_default() -> ComparisonProfile
PerceptualBackground::parse_srgb(String) -> PerceptualBackground?
PerceptualBackground::red() -> Int
PerceptualBackground::green() -> Int
PerceptualBackground::blue() -> Int
FlipViewingConditions::from_pixels_per_degree(Double) -> FlipViewingConditions?
FlipViewingConditions::pixels_per_degree() -> Double
FlipErrorThreshold::from_value(Double) -> FlipErrorThreshold?
FlipErrorThreshold::value() -> Double
StructuredReport::to_json_string() -> String
StructuredReport::to_compact_json_string() -> String
StructuredReport::to_agent_projection_json_lines() -> String
SourceAuditReport::to_json_string() -> String
SourceAuditReport::to_compact_json_string() -> String
```

`compare` is the unlimited semantic comparison operation. `compare_with_resources` additionally receives separate before and after `ResourceBundle` values, each containing ordered `ResourceBundleEntry { locator, media_type, bytes }` records. Locators are trimmed exact-match opaque keys; the engine does not resolve paths, normalize URLs, or fetch the network. Global bundle configuration and byte budgets apply to every entry, but payload content is decoded only when an SVG `image` selects it; unused bundle bytes are not compared as SVG differences. The complete matrix is the [Resource Outcome Policy](resource-outcome-policy.md). `compare_with_control` and `compare_with_control_and_resources` add cooperative cancellation and an optional deterministic checkpoint budget. `render_html_report` and `render_markdown_summary` are presentations over an existing report and never recompute differences. The HTML inspector exposes the exact Impact frontier, every Atomic Difference, non-null magnitudes, linked events, Difference Regions, conservative possible causes, and Diagnostics beside sandboxed source previews. The Markdown renderer is explicitly non-authoritative; see [Derived Markdown Summary](markdown-summary.md).

`audit_nonvisual_metadata` is deliberately separate from comparison. It inventories exact authored inner content for outermost SVG `title`, `desc`, and `metadata` elements plus unprefixed `aria-*` and `data-*` attributes. It returns `SourceAuditReport` under independent audit schema `1.0`; its records never appear in Structured Report, Agent JSON, Visual Events, magnitudes, or regions. See the [Nonvisual Source Audit](source-audit.md) and its separate [JSON Schema](../schema/svgdiff-source-audit.schema.json).

The two canonical JSON methods serialize schema `1.45`. `to_json_string` uses indentation for inspection; `to_compact_json_string` removes only formatting whitespace and preserves every canonical field and value. `to_agent_projection_json_lines` emits the independent `svgdiff-agent-projection/1` JSONL transport: one header plus exact canonical section items that reconstruct the same report without loss.

Every call uses the fixed [comparison resource limits](resource-limits.md) and [local-reference admission guard](reference-safety.md). Crossing a source, structure, raster, region, or report budget returns a bounded `failed` report with `resource_limit_exceeded`; cyclic or explosively expanding accepted local references use their own stable Diagnostics. No failure returns a silently truncated difference inventory. The limits are intentionally not caller-configurable in module `0.6.0`.

`ComparisonControl` contains `should_cancel: () -> Bool` and `max_checkpoints: Int?`; `ComparisonControl::unlimited()` disables both controls. A true predicate raises `Cancelled`. A nonpositive checkpoint budget expires at the first checkpoint. A positive budget permits exactly that many checkpoints and raises `CheckpointBudgetExceeded(max_checkpoints=...)` at the next one. Cancellation is checked first when both conditions hold. This is a deterministic work bound for one engine version, not a wall-clock deadline.

Executable IO is outside the library seam. [`cmd/svgdiff`](../cmd/svgdiff) is the native filesystem/stdin/stdout CLI. [`cmd/svgdiff_wasm`](../cmd/svgdiff_wasm/README.md) is the wasm-only, in-memory UTF-8 JSON transaction used by the static browser product. Its ABI 1 request explicitly supplies both SVG strings, viewport dimensions, nullable Perceptual Background, nullable FLIP pixels-per-degree, nullable FLIP threshold, and a positive deterministic checkpoint budget; missing and unknown fields are rejected.

An interruption returns no Structured Report: callers must handle `ComparisonInterrupted` as request control flow rather than infer evidence from missing arrays. Checks occur before and after admission, alignment work, per-event region work, report-finishing stages, and built-in serialization enforcement. Third-party XML parsing and SVG rendering are synchronous and cannot be preempted; each call may finish before the engine reaches its next counted checkpoint. The ordinary `compare` and CLI behavior remain unchanged; current reports use Schema `1.45` and its Diagnostic catalog.

## Public report types

| Area | Types |
| --- | --- |
| Profile, control, resources, and result | `ComparisonProfile`, `PerceptualBackground`, `FlipViewingConditions`, `FlipErrorThreshold`, `ComparisonControl`, `ComparisonInterrupted`, `ResourceBundle`, `ResourceBundleEntry`, `StructuredReport`, `FeatureCoverage`, `RendererCapabilityGap`, `Diagnostic`, `DiagnosticSourceLocation` |
| Optional nonvisual source audit | `SourceAuditReport`, `SourceAuditDifference`, `SourceAuditFact`, `SourceAuditDiagnostic` |
| Subjects and alignment | `SubjectReference`, `SubjectInstanceContext`, `AlignmentEvidence`, `SubjectAlignment` |
| Source and computed facts | `ReportSourceSpan`, `DeclaredVisualFact`, `ResolvedVisualFact`, `SourceResolutionPair`, `ChangedFact`, `ComputedRelation` |
| Differences, grouping, and main-event assessment | `AtomicDifference`, `VisualEvent`, `ImpactAssessment`, `ImpactFrontierGroup`, `ImpactMeasurement`, `ImpactDominationWitness` |
| Magnitude and ordering | `DifferenceMagnitude`, `PaintedBoundaryDisplacementMagnitude`, `PaintedCoverageDifferenceMagnitude`, `PresenceMagnitude`, `IntrinsicRasterMagnitude`, `TransformEffectMagnitude` and its five component records, `RenderedEvidence`, `RenderedMagnitude`, `PerceptualColorEvidence`, `PerceptualColorMagnitude`, `PerceptualFlipEvidence`, `PerceptualFlipMap`, `PerceptualFlipStatistics`, `PerceptualFlipAreaAboveThreshold`, `DomainOrdering` |
| Localization and causality | `DifferenceRegion`, `CauseEnvelope` |

All are project-owned serializable records. Parser, SVG scene, image, pixelmatch, and filesystem dependency types do not cross the public seam.

`DifferenceMagnitude` keeps unavailable observations as JSON `null`. Admitted scalar spatial parameters retain canonical local-user-unit deltas, exact CSS-pixel displacement under one complete mapping shared by both sides, viewport-diagonal fraction, and an entity-relative fraction when nonzero conservative bounds exist. Conflicting mappings and direction-dependent anisotropic stroke scalars keep the contextual fields null. Exact authored spelling and units remain in source facts. `painted_boundary_displacement`, when measured, records the fixed method ID, before/after boundary sample counts, and symmetric nearest-boundary mean, nearest-rank p95, and maximum CSS-pixel distances from isolated pinned-renderer alpha support. `painted_coverage_difference` reuses that isolated render pair and records per-side alpha area, absolute alpha difference, alpha union, and their bounded ratio. Equal alpha coverage is zero regardless of RGB color. Both objects remain separate from exact parameters, analytic geometry outcomes, event changed pixels, color error, visibility, and severity. The optional `intrinsic_raster` describes decoded resource-local RGBA8 content and is not final-canvas Rendered Evidence. The optional tagged `transform_effect` is emitted only for canonical transform-component differences: translation uses CSS pixels, rotation and skew use degrees, scale retains signed axis factors, and singular linear changes retain exact affine coefficients without a coefficient-distance score. Consumers must dispatch on the exact difference domain rather than compare unlike units.

Every report contains a comparison-wide `canvas_outcome` computed directly from the final rendered before/after canvases. It records changed-pixel fraction and linear-premultiplied-RGBA RMSE, and records `perceptual_flip.canvas_mean` when the caller supplies both a Perceptual Background and FLIP Viewing Conditions. These values remain independent measurements; the library does not combine them into severity.

Every report also contains `impact_assessment`. Policy `event_rendered_pareto/v1` exposes all Visual Events not dominated on both whole-canvas changed-pixel fraction and linear-premultiplied RGBA RMSE. Equal vectors are tied, tradeoffs remain incomparable, missing rendered magnitudes remain null and make the assessment partial, and every dominated event receives one deterministic witness. The result links back to complete event and Atomic Difference IDs and declares `not_calibrated`; it is not a severity label, scalar, visibility decision, or total order.

## Basic use

Use the checked `mbt check` examples in [`README.mbt.md`](../README.mbt.md) as the executable source of library usage. The essential sequence is:

1. start from `ComparisonProfile::v1_default`;
2. set the common viewport dimensions if the `16 x 16` default is not appropriate, optionally set a parsed opaque sRGB Perceptual Background for event-local DeltaEOK, optionally add invariant-checked FLIP Viewing Conditions for an event-local LDR-FLIP map and pooled statistics, and optionally set an invariant-checked FLIP error threshold for strict-above area;
3. call `compare` with the two complete SVG source strings, or `compare_with_resources` with explicitly acquired before/after PNG/JPEG bytes;
4. inspect `analysis_status` and Diagnostics;
5. read `canvas_outcome` for comparison-wide rendered measurements;
6. read every Impact Assessment frontier group for main events, then interpret the linked Visual Events and Atomic Differences;
7. serialize JSON, build HTML, or derive a non-authoritative Markdown orientation if needed;
8. independently call `audit_nonvisual_metadata` only when source governance also needs nonvisual metadata changes.

`DiagnosticSourceLocation.source_role` is `before` or `after`; its `source_span` uses half-open UTF-16 offsets into that exact input. Current producers always emit `Diagnostic.source_locations`. The field is optional in JSON for legacy compatibility, where absence means “not reported”; an emitted empty array means the Diagnostic is comparison-global or derived and has no non-fabricated source anchor.

The root API preserves viewport width, viewport height, `perceptual_background`, `flip_viewing_conditions`, and `flip_error_threshold`, and canonicalizes every other profile field. Construct Viewing Conditions with `FlipViewingConditions::from_pixels_per_degree`; only finite values in `[1, 4096]` are accepted. Construct the optional reporting threshold with `FlipErrorThreshold::from_value`; only finite values in `[0, 1]` are accepted. Setting a different DPR, color interpretation, raster representation, renderer ID, or renderer conformance profile ID in the input record does not select another backend in schema `1.45`. The optional background enables event-local DeltaEOK, background plus Viewing Conditions enable event-local LDR-FLIP and its unquantized pooled statistics, and the threshold enables only strict-above area, without affecting transparent-canvas raw rendering.

The current profile emits `renderer_conformance_profile_id = "svgdiff-renderer-conformance-profile/26"`. This ID versions accepted renderer claims and guards independently from both report schema `1.45` and the production `svgdiff/style-precedence-normalizer@3+ordinary-inheritance-normalizer@1+css-computed-value-normalizer@3+css-color3-opacity-normalizer@1+length-used-value-normalizer@1+stroke-used-geometry-normalizer@1+basic-shape-used-geometry-normalizer@1+isolated-group-compositor@1+static-mask-normalizer@1+static-mask-compositor@1+static-filter-graph-compositor@1+static-blend-compositor@1+Milky2018/svg@0.3.0` renderer identity.

## Generated documentation

Generate and inspect the current public documentation from the repository root:

```sh
moon info
moon ide doc '@Milky2018/svgdiff'
moon ide doc '@Milky2018/svgdiff.compare'
moon ide doc '@Milky2018/svgdiff.StructuredReport'
```

`moon info` regenerates `pkg.generated.mbti`, which is the reviewable public signature. `moon ide doc` includes the owning-package docstrings.

The current toolchain's optional local `moon doc` site generation is blocked while checking transitive dependency tests: `mizchi/image`'s `ColorType` and `moonbitlang/x`'s `Rational[Int64]` are used by `assert_eq` without implementing `Debug`. This does not affect `moon info`, `moon ide doc`, module publication, consumer checks, or project tests. Do not patch dependency caches to generate the site; retry `moon doc --serve` after released upstream packages remove those test-only constraints. Live blocker status is recorded in [`dependency-security.md`](dependency-security.md).

Do not edit `.mbti` files by hand. Public API changes must originate in MoonBit declarations and be reviewed through the regenerated interface diff.

## Contract references

- [Core comparison model](core-model.md)
- [Current v1 support](v1-scope.md)
- [Feature coverage matrix](feature-coverage.md)
- [Analysis status contract](analysis-status.md)
- [Text-only agent report guide](agent-report-guide.md)
- [JSON Schema](../schema/svgdiff-report.schema.json)
- [Nonvisual source audit and independent JSON Schema](source-audit.md)
- [Compatibility and versioning contract](versioning.md)
