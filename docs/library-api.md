# MoonBit Library API

Status: current public interface for module version `0.1.0`

Last verified: 2026-07-14

Consumers should import the root package `Milky2018/svgdiff`. The `engine` package owns the concrete report types, while the root package deliberately re-exports them and pins the schema `1.0` comparison conditions.

## Public operations

```text
compare(String, String, ComparisonProfile) -> StructuredReport
render_html_report(String, String, StructuredReport) -> String
ComparisonProfile::v1_default() -> ComparisonProfile
StructuredReport::to_json_string() -> String
StructuredReport::to_compact_json_string() -> String
```

`compare` is the only semantic comparison operation. `render_html_report` is a presentation over an existing report and never recomputes differences.

Both JSON methods serialize schema `1.0`. `to_json_string` uses indentation for inspection; `to_compact_json_string` removes only formatting whitespace and preserves every canonical field and value.

## Public report types

| Area | Types |
| --- | --- |
| Profile and result | `ComparisonProfile`, `StructuredReport`, `Diagnostic` |
| Subjects and alignment | `SubjectReference`, `SubjectAlignment` |
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

The root API canonicalizes all profile fields other than viewport width and height. Setting a different DPR, color interpretation, raster representation, or renderer ID in the input record does not select another backend in schema `1.0`.

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
