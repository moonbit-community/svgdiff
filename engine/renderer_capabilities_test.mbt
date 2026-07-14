///|
test "current renderer diagnostics expose stable capability gaps" {
  let cases = [
    (
      "<svg width='16' height='16'><rect id='box' width='8' height='8' fill='red' style='fill:blue;unknown:value'/></svg>",
      "css.inline_style_precedence", "guarded",
    ),
    (
      "<svg width='16' height='16'><rect id='box' x='0.99999' width='8' height='8' fill='red'/></svg>",
      "raster.fractional_geometry", "guarded",
    ),
    (
      "<svg width='16' height='16'><rect id='box' width='8' height='8' fill='red' opacity='0.5'/></svg>",
      "raster.fractional_opacity", "guarded",
    ),
    (
      "<svg width='16' height='16'><defs><linearGradient id='gradient'><stop offset='0' stop-color='red'/><stop offset='1' stop-color='blue'/></linearGradient></defs><rect id='box' width='8' height='8' fill='url(#gradient)'/></svg>",
      "raster.referenced_gradient", "guarded",
    ),
    (
      "<svg width='16' height='16'><g id='layer' opacity='0.5'><rect id='box' width='8' height='8' fill='red'/></g></svg>",
      "compositing.group_opacity", "unavailable",
    ),
  ]
  for case in cases {
    let (source, capability_id, support_status) = case
    let report = @engine.compare(
      source,
      source,
      @engine.ComparisonProfile::v1_default(),
    )
    assert_true(
      report.renderer_capability_gaps.any(gap => {
        gap.capability_id == capability_id &&
        gap.support_status == support_status &&
        !gap.diagnostic_ids.is_empty()
      }),
    )
  }
}

///|
test "one capability merges all establishing diagnostics" {
  let source = "<svg width='16' height='16'><rect id='box' width='8' height='8' fill='red' stroke='red' style='fill:blue;stroke:blue;unknown:value'/></svg>"
  let report = @engine.compare(
    source,
    source,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.renderer_capability_gaps.length(), 1)
  let gap = report.renderer_capability_gaps[0]
  assert_eq(gap.capability_id, "css.inline_style_precedence")
  assert_eq(gap.support_status, "guarded")
  assert_eq(gap.diagnostic_ids, [
    "diagnostic:renderer-style-precedence-unresolved:box:fill", "diagnostic:renderer-style-precedence-unresolved:box:stroke",
  ])
}

///|
test "capability metadata is encountered-only" {
  let complete_source = "<svg width='16' height='16'><rect id='box' width='8' height='8' fill='red'/></svg>"
  let complete = @engine.compare(
    complete_source,
    complete_source,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_true(complete.renderer_capability_gaps.is_empty())
  let analyzer_limited = @engine.compare(
    "<svg width='16' height='16'><path d='M0 0 L8 8'/></svg>",
    "<svg width='16' height='16'><path d='M0 0 L9 9'/></svg>",
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(analyzer_limited.analysis_status, "partial")
  assert_true(analyzer_limited.renderer_capability_gaps.is_empty())
  let failed = @engine.compare(
    "<svg><rect></svg>",
    "<svg/>",
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(failed.analysis_status, "failed")
  assert_true(failed.renderer_capability_gaps.is_empty())
}
