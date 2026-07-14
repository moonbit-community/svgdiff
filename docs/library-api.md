# MoonBit Library API

Status: current public interface for module version `0.3.1`

Last verified: 2026-07-14

Consumers should import the root package `Milky2018/svgdiff`. The `engine` package owns the concrete report types, while the root package deliberately re-exports them and pins the schema `1.3` comparison conditions.

Public source and behavior compatibility follows the [module SemVer rules](versioning.md#moonbit-module-semver). Before `1.0.0`, breaking changes increment the minor component and patch releases remain backward-compatible.

## Public operations

```text
compare(String, String, ComparisonProfile) -> StructuredReport
render_html_report(String, String, StructuredReport) -> String
ComparisonProfile::v1_default() -> ComparisonProfile
StructuredReport::to_json_string() -> String
StructuredReport::to_compact_json_string() -> String
```

`compare` is the only semantic comparison operation. `render_html_report` is a presentation over an existing report and never recomputes differences.

Both JSON methods serialize schema `1.3`. `to_json_string` uses indentation for inspection; `to_compact_json_string` removes only formatting whitespace and preserves every canonical field and value.

Every call uses the fixed [comparison resource limits](resource-limits.md). Crossing a source, structure, raster, region, or report budget returns a bounded `failed` report with `resource_limit_exceeded`; it never returns a silently truncated difference inventory. The limits are intentionally not caller-configurable in module `0.3.1`.

## Public report types

| Area | Types |
| --- | --- |
| Profile and result | `ComparisonProfile`, `StructuredReport`, `FeatureCoverage`, `RendererCapabilityGap`, `Diagnostic`, `DiagnosticSourceLocation` |
| Subjects and alignment | `SubjectReference`, `AlignmentEvidence`, `SubjectAlignment` |
| Source and computed facts | `ReportSourceSpan`, `DeclaredVisualFact`, `ResolvedVisualFact`, `SourceResolutionPair`, `ChangedFact`, `ComputedRelation` |
| Differences and grouping | `AtomicDifference`, `VisualEvent` |
| Magnitude and ordering | `DifferenceMagnitude`, `PresenceMagnitude`, `RenderedEvidence`, `RenderedMagnitude`, `DomainOrdering` |
| Localization and causality | `DifferenceRegion`, `CauseEnvelope` |

All are project-owned serializable records. Parser, SVG scene, image, pixelmatch, and filesystem dependency types do not cross the public seam.

## Basic use

Use the checked `mbt check` examples in [`README.mbt.md`](../README.mbt.md) as the executable source of library usage. The essential sequence is:

1. start from `ComparisonProfile::v1_default`;
2. set the common viewport dimensions if the `16 x 16` default is not appropriate;
3. call `compare` with the two complete SVG source strings;
4. inspect `analysis_status` and Diagnostics;
5. interpret events and Atomic Differences;
6. serialize JSON or build HTML if needed.

`DiagnosticSourceLocation.source_role` is `before` or `after`; its `source_span` uses half-open UTF-16 offsets into that exact input. Current producers always emit `Diagnostic.source_locations`. The field is optional in JSON for legacy compatibility, where absence means “not reported”; an emitted empty array means the Diagnostic is comparison-global or derived and has no non-fabricated source anchor.

The root API canonicalizes all profile fields other than viewport width and height. Setting a different DPR, color interpretation, raster representation, renderer ID, or renderer conformance profile ID in the input record does not select another backend in schema `1.3`.

The current profile emits `renderer_conformance_profile_id = "svgdiff-renderer-conformance-profile/1"`. This ID versions accepted renderer claims and guards independently from both report schema `1.3` and `mizchi/svg@0.2.1`.

## Generated documentation

Generate and inspect the current public documentation from the repository root:

```sh
moon info
moon ide doc '@Milky2018/svgdiff'
moon ide doc '@Milky2018/svgdiff.compare'
moon ide doc '@Milky2018/svgdiff.StructuredReport'
```

`moon info` regenerates `pkg.generated.mbti`, which is the reviewable public signature. `moon ide doc` includes the owning-package docstrings.

The current toolchain's optional `moon doc` site generation is blocked while checking transitive dependency tests: `mizchi/image`'s `ColorType` and `moonbitlang/x`'s `Rational[Int64]` are used by `assert_eq` without implementing `Debug`. This does not affect `moon info`, `moon ide doc`, `moon check`, or project tests. Do not patch dependency caches to generate the site; retry `moon doc --serve` after released upstream packages remove those test-only constraints. Live blocker status is recorded in [`dependency-security.md`](dependency-security.md).

Do not edit `.mbti` files by hand. Public API changes must originate in MoonBit declarations and be reviewed through the regenerated interface diff.

## Contract references

- [Core comparison model](core-model.md)
- [Current v1 support](v1-scope.md)
- [Feature coverage matrix](feature-coverage.md)
- [Analysis status contract](analysis-status.md)
- [Text-only agent report guide](agent-report-guide.md)
- [JSON Schema](../schema/svgdiff-report.schema.json)
- [Compatibility and versioning contract](versioning.md)
