# svgdiff for MoonBit

`Milky2018/svgdiff` compares two deterministic static SVG source strings and
returns a typed Structured Report for programs and agents that need
visual-semantic differences without inspecting images directly.

## Install

```sh
moon add Milky2018/svgdiff@0.10.1
```

## Compare SVG sources

```mbt check
///|
test "compare SVG source strings through the public package" {
  let before = "<svg width='16' height='16'><rect width='8' height='8' fill='red'/></svg>"
  let after = "<svg width='16' height='16'><rect width='8' height='8' fill='blue'/></svg>"
  let report = @svgdiff.compare(
    before,
    after,
    @svgdiff.ComparisonProfile::v1_default(),
  )
  assert_eq(report.schema_version, "5.0")
  assert_eq(report.analysis_status, "complete")
  assert_eq(report.visual_scene.summary.object_set, "preserved")
  assert_eq(report.visual_scene.summary.style, "changed")
  assert_true(report.atomic_differences.length() > 0)
  assert_true(report.events.length() > 0)
}
```

The root package is the stable library interface. Native, WASIp1, and browser
entrypoints live in sibling packages under `cmd`.
