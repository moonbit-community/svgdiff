# MoonBit Library API

Status: current public interface for module version `0.5.17`

Last verified: 2026-07-15

Consumers should import the root package `Milky2018/svgdiff`. The `engine` package owns the concrete report types, while the root package deliberately re-exports them and pins the schema `1.37` comparison conditions.

Install the published native module with:

```sh
moon add Milky2018/svgdiff@0.5.17
```

The root registry archive contains only the root, `engine`, and internal `css_color` production packages, generated interfaces, [`PACKAGE.mbt.md`](../PACKAGE.mbt.md), manifest, and license. The separately versioned `Milky2018/svgdiff-raster-codec` archive contains the project-owned bounded decoder required by the root module. Publish codec `0.1.0` before root `0.5.17`; consumers still import only the root package. `sh scripts/test-module-package.sh` validates both inventories, runs MoonBit's packaged-source checks, and compiles a separate workspace consumer against both generated zips. The published [Mooncakes root module](https://mooncakes.io/docs/Milky2018/svgdiff) uses the same module version as the CLI engine identity.

Public source and behavior compatibility follows the [module SemVer rules](versioning.md#moonbit-module-semver). Before `1.0.0`, breaking changes increment the minor component and patch releases remain backward-compatible.

## Public operations

```text
compare(String, String, ComparisonProfile) -> StructuredReport
compare_with_resources(String, String, ComparisonProfile, ResourceBundle, ResourceBundle) -> StructuredReport
compare_with_control(String, String, ComparisonProfile, ComparisonControl) -> StructuredReport raises ComparisonInterrupted
compare_with_control_and_resources(String, String, ComparisonProfile, ResourceBundle, ResourceBundle, ComparisonControl) -> StructuredReport raises ComparisonInterrupted
audit_nonvisual_metadata(String, String) -> SourceAuditReport
render_html_report(String, String, StructuredReport) -> String
ComparisonProfile::v1_default() -> ComparisonProfile
StructuredReport::to_json_string() -> String
StructuredReport::to_compact_json_string() -> String
SourceAuditReport::to_json_string() -> String
SourceAuditReport::to_compact_json_string() -> String
```

`compare` is the unlimited semantic comparison operation. `compare_with_resources` additionally receives separate before and after `ResourceBundle` values, each containing ordered `ResourceBundleEntry { locator, media_type, bytes }` records. Locators are trimmed exact-match opaque keys; the engine does not resolve paths, normalize URLs, or fetch the network. Global bundle configuration and byte budgets apply to every entry, but payload content is decoded only when an SVG `image` selects it; unused bundle bytes are not compared as SVG differences. The complete matrix is the [Resource Outcome Policy](resource-outcome-policy.md). `compare_with_control` and `compare_with_control_and_resources` add cooperative cancellation and an optional elapsed-time budget. `render_html_report` is a presentation over an existing report and never recomputes differences.

`audit_nonvisual_metadata` is deliberately separate from comparison. It inventories exact authored inner content for outermost SVG `title`, `desc`, and `metadata` elements plus unprefixed `aria-*` and `data-*` attributes. It returns `SourceAuditReport` under independent audit schema `1.0`; its records never appear in Structured Report, Agent JSON, Visual Events, magnitudes, or regions. See the [Nonvisual Source Audit](source-audit.md) and its separate [JSON Schema](../schema/svgdiff-source-audit.schema.json).

Both JSON methods serialize schema `1.37`. `to_json_string` uses indentation for inspection; `to_compact_json_string` removes only formatting whitespace and preserves every canonical field and value.

Every call uses the fixed [comparison resource limits](resource-limits.md) and [local-reference admission guard](reference-safety.md). Crossing a source, structure, raster, region, or report budget returns a bounded `failed` report with `resource_limit_exceeded`; cyclic or explosively expanding accepted local references use their own stable Diagnostics. No failure returns a silently truncated difference inventory. The limits are intentionally not caller-configurable in module `0.5.17`.

`ComparisonControl` contains `should_cancel: () -> Bool` and `max_elapsed_milliseconds: Int?`; `ComparisonControl::unlimited()` disables both controls. A true predicate raises `Cancelled`. A nonpositive time budget expires at the first checkpoint, and a positive budget raises `TimeBudgetExceeded(max_elapsed_milliseconds=...)` once elapsed time reaches it. Cancellation is checked first when both conditions hold.

An interruption returns no Structured Report: callers must handle `ComparisonInterrupted` as request control flow rather than infer evidence from missing arrays. Checks occur before and after admission, alignment work, per-event region work, report-finishing stages, and built-in serialization enforcement. Third-party XML parsing and SVG rendering are synchronous and cannot be preempted, so elapsed-time expiry is observed at the next checkpoint and is not a hard real-time deadline. The ordinary `compare` and CLI behavior remain unchanged; current reports use Schema `1.37` and its Diagnostic catalog.

## Public report types

| Area | Types |
| --- | --- |
| Profile, control, resources, and result | `ComparisonProfile`, `ComparisonControl`, `ComparisonInterrupted`, `ResourceBundle`, `ResourceBundleEntry`, `StructuredReport`, `FeatureCoverage`, `RendererCapabilityGap`, `Diagnostic`, `DiagnosticSourceLocation` |
| Optional nonvisual source audit | `SourceAuditReport`, `SourceAuditDifference`, `SourceAuditFact`, `SourceAuditDiagnostic` |
| Subjects and alignment | `SubjectReference`, `SubjectInstanceContext`, `AlignmentEvidence`, `SubjectAlignment` |
| Source and computed facts | `ReportSourceSpan`, `DeclaredVisualFact`, `ResolvedVisualFact`, `SourceResolutionPair`, `ChangedFact`, `ComputedRelation` |
| Differences and grouping | `AtomicDifference`, `VisualEvent` |
| Magnitude and ordering | `DifferenceMagnitude`, `PaintedBoundaryDisplacementMagnitude`, `PresenceMagnitude`, `IntrinsicRasterMagnitude`, `TransformEffectMagnitude` and its five component records, `RenderedEvidence`, `RenderedMagnitude`, `DomainOrdering` |
| Localization and causality | `DifferenceRegion`, `CauseEnvelope` |

All are project-owned serializable records. Parser, SVG scene, image, pixelmatch, and filesystem dependency types do not cross the public seam.

`DifferenceMagnitude` keeps unavailable observations as JSON `null`. Admitted scalar spatial parameters retain canonical local-user-unit deltas, exact CSS-pixel displacement under one complete mapping shared by both sides, viewport-diagonal fraction, and an entity-relative fraction when nonzero conservative bounds exist. Conflicting mappings and direction-dependent anisotropic stroke scalars keep the contextual fields null. Exact authored spelling and units remain in source facts. `painted_boundary_displacement`, when measured, records the fixed method ID, before/after boundary sample counts, and symmetric nearest-boundary mean, nearest-rank p95, and maximum CSS-pixel distances from isolated pinned-renderer alpha support. It remains separate from exact parameters, analytic geometry outcomes, soft coverage, color, and severity. Its optional `intrinsic_raster` describes decoded resource-local RGBA8 content and is not final-canvas Rendered Evidence. Its optional tagged `transform_effect` is emitted only for canonical transform-component differences: translation uses CSS pixels, rotation and skew use degrees, scale retains signed axis factors, and singular linear changes retain exact affine coefficients without a coefficient-distance score. Consumers must dispatch on the exact difference domain rather than compare unlike units.

## Basic use

Use the checked `mbt check` examples in [`README.mbt.md`](../README.mbt.md) as the executable source of library usage. The essential sequence is:

1. start from `ComparisonProfile::v1_default`;
2. set the common viewport dimensions if the `16 x 16` default is not appropriate;
3. call `compare` with the two complete SVG source strings, or `compare_with_resources` with explicitly acquired before/after PNG/JPEG bytes;
4. inspect `analysis_status` and Diagnostics;
5. interpret events and Atomic Differences;
6. serialize JSON or build HTML if needed;
7. independently call `audit_nonvisual_metadata` only when source governance also needs nonvisual metadata changes.

`DiagnosticSourceLocation.source_role` is `before` or `after`; its `source_span` uses half-open UTF-16 offsets into that exact input. Current producers always emit `Diagnostic.source_locations`. The field is optional in JSON for legacy compatibility, where absence means “not reported”; an emitted empty array means the Diagnostic is comparison-global or derived and has no non-fabricated source anchor.

The root API canonicalizes all profile fields other than viewport width and height. Setting a different DPR, color interpretation, raster representation, renderer ID, or renderer conformance profile ID in the input record does not select another backend in schema `1.37`.

The current profile emits `renderer_conformance_profile_id = "svgdiff-renderer-conformance-profile/25"`. This ID versions accepted renderer claims and guards independently from both report schema `1.37` and the production `svgdiff/style-precedence-normalizer@3+ordinary-inheritance-normalizer@1+css-computed-value-normalizer@3+css-color3-opacity-normalizer@1+length-used-value-normalizer@1+stroke-used-geometry-normalizer@1+basic-shape-used-geometry-normalizer@1+isolated-group-compositor@1+static-mask-normalizer@1+static-mask-compositor@1+mizchi/svg@0.2.1` renderer identity.

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
