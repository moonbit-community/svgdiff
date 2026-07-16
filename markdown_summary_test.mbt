///|
test "Markdown summary repeats report evidence without new judgments" {
  let report = @svgdiff.compare(
    "<svg width='16' height='16'><rect id='box' width='8' height='8' fill='red'/></svg>",
    "<svg width='16' height='16'><rect id='box' width='8' height='8' fill='blue'/></svg>",
    @svgdiff.ComparisonProfile::v1_default(),
  )
  let summary = @svgdiff.render_markdown_summary(report)
  assert_true(summary.has_prefix("# SVG Diff Summary\n"))
  assert_true(summary.contains("Derived presentation only"))
  assert_true(summary.contains("Structured Report JSON is authoritative"))
  assert_true(summary.contains("Analysis status: complete"))
  assert_true(
    summary.contains(
      report.impact_assessment.policy_id.replace_all(old="_", new="\\_"),
    ),
  )
  assert_true(summary.contains(report.impact_assessment.frontier_relation))
  for difference in report.atomic_differences {
    assert_true(summary.contains(difference.id))
    assert_true(summary.contains(difference.domain))
    assert_true(summary.contains(difference.computed_relation.status))
    assert_true(
      summary.contains(
        difference.computed_relation.reason_code.replace_all(old="_", new="\\_"),
      ),
    )
  }
  assert_false(summary.contains("subtle"))
  assert_false(summary.contains("major"))
  assert_false(summary.contains("visible"))
  assert_false(summary.contains("invisible"))
}

///|
test "Markdown summary preserves equivalent spelling and empty inventories" {
  let equivalent = @svgdiff.compare(
    "<svg width='16' height='16'><rect width='8' height='8' fill='red'/></svg>",
    "<svg width='16' height='16'><rect width='8' height='8' fill='#ff0000'/></svg>",
    @svgdiff.ComparisonProfile::v1_default(),
  )
  let equivalent_summary = @svgdiff.render_markdown_summary(equivalent)
  assert_true(equivalent_summary.contains("Computed relation: equivalent"))
  assert_true(equivalent_summary.contains("\"red\""))
  assert_true(equivalent_summary.contains("\"#ff0000\""))
  let empty = @svgdiff.compare(
    "<svg width='16' height='16'><rect width='8' height='8'/></svg>",
    "<svg width='16' height='16'><rect width='8' height='8'/></svg>",
    @svgdiff.ComparisonProfile::v1_default(),
  )
  let empty_summary = @svgdiff.render_markdown_summary(empty)
  assert_true(
    empty_summary.contains("The report contains no Atomic Difference records."),
  )
  assert_true(
    empty_summary.contains("The report contains no Diagnostic records."),
  )
  assert_true(empty_summary.contains("No frontier group is present"))
}

///|
test "Markdown summary qualifies partial and failed reports with Diagnostics" {
  let partial = @svgdiff.compare(
    "<svg width='16' height='16'><path d='M0 0 L8 8'/></svg>",
    "<svg width='16' height='16'><path d='M0 0 L8 8'/></svg>",
    @svgdiff.ComparisonProfile::v1_default(),
  )
  let partial_summary = @svgdiff.render_markdown_summary(partial)
  assert_true(partial_summary.contains("Analysis status: partial"))
  assert_true(partial_summary.contains("not complete"))
  for diagnostic in partial.diagnostics {
    assert_true(partial_summary.contains(diagnostic.id))
    assert_true(partial_summary.contains(diagnostic.code))
  }
  let failed = @svgdiff.compare(
    "<svg><rect></svg>",
    "<svg/>",
    @svgdiff.ComparisonProfile::v1_default(),
  )
  let failed_summary = @svgdiff.render_markdown_summary(failed)
  assert_true(failed_summary.contains("Analysis status: failed"))
  for diagnostic in failed.diagnostics {
    assert_true(failed_summary.contains(diagnostic.id))
    assert_true(failed_summary.contains(diagnostic.code))
  }
}

///|
test "Markdown summary states tie incomparability and missing measurements" {
  let base = @svgdiff.compare(
    "<svg width='16' height='16'><rect width='8' height='8' fill='red'/></svg>",
    "<svg width='16' height='16'><rect width='8' height='8' fill='blue'/></svg>",
    @svgdiff.ComparisonProfile::v1_default(),
  )
  let tied = {
    ..base,
    impact_assessment: {
      ..base.impact_assessment,
      frontier_relation: "tied",
      frontier_groups: [
        {
          event_ids: ["event-a", "event-b"],
          atomic_difference_ids: [base.atomic_differences[0].id],
          measurements: Some({
            changed_pixel_fraction: 0.25,
            linear_premultiplied_rgba_rmse: 0.5,
          }),
        },
      ],
    },
  }
  assert_true(
    @svgdiff.render_markdown_summary(tied).contains("exact measured tie"),
  )
  let incomparable = {
    ..base,
    impact_assessment: {
      ..base.impact_assessment,
      status: "partial",
      frontier_relation: "incomparable",
      frontier_groups: [
        {
          event_ids: ["event-a"],
          atomic_difference_ids: [base.atomic_differences[0].id],
          measurements: Some({
            changed_pixel_fraction: 0.25,
            linear_premultiplied_rgba_rmse: 0.5,
          }),
        },
        {
          event_ids: ["event-b"],
          atomic_difference_ids: [],
          measurements: None,
        },
      ],
    },
  }
  let summary = @svgdiff.render_markdown_summary(incomparable)
  assert_true(summary.contains("incomparable under this policy"))
  assert_true(summary.contains("serialized order is not an impact ranking"))
  assert_true(summary.contains("measurements unavailable"))
  assert_true(summary.contains("unavailable values are not zero"))
}

///|
test "Markdown summary escapes report-controlled text" {
  let report = @svgdiff.compare(
    "<svg width='16' height='16'><rect id='box' width='8' height='8' fill='red'/></svg>",
    "<svg width='16' height='16'><rect id='box' width='8' height='8' fill='blue'/></svg>",
    @svgdiff.ComparisonProfile::v1_default(),
  )
  let hostile = {
    ..report,
    atomic_differences: [
      {
        ..report.atomic_differences[0],
        id: "<script>[diff]_`x`</script>\n# injected",
        source_before: "</textarea>\n# heading",
      },
    ],
  }
  let summary = @svgdiff.render_markdown_summary(hostile)
  assert_false(summary.contains("<script>"))
  assert_false(summary.contains("</textarea>"))
  assert_true(summary.contains("&lt;script&gt;"))
  assert_true(summary.contains("\\[diff\\]\\_&#96;x&#96;"))
  assert_true(summary.contains("&lt;/script&gt;\\n# injected"))
  assert_true(summary.contains("&lt;/textarea&gt;"))
  assert_false(summary.contains("\n# injected"))
  assert_false(summary.contains("\n# heading"))
}
