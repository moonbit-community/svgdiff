///|
test "Agent projection partitions every canonical report section" {
  let report = compare(
    "<svg width='16' height='16'><rect width='8' height='8' fill='red'/></svg>",
    "<svg width='16' height='16'><rect width='8' height='8' fill='blue'/></svg>",
    ComparisonProfile::v1_default(),
  )
  let projection = report.to_agent_projection_json_lines()
  let lines = projection.split("\n").collect()
  let expected_records = 1 +
    report.coverage_matrix.length() +
    report.renderer_capability_gaps.length() +
    report.subject_alignments.length() +
    report.changed_facts.length() +
    report.source_resolutions.length() +
    report.atomic_differences.length() +
    report.events.length() +
    report.diagnostics.length()
  assert_eq(lines.length(), expected_records)
  match @json.parse(lines[0]) {
    {
      "projection_version": "svgdiff-agent-projection/1",
      "source_schema_version": "1.45",
      "record_type": "header",
      "sequence": 0,
      "section_counts": { "atomic_differences": 1, "events": 1, .. },
      "value": {
        "schema_version": "1.45",
        "analysis_status": "complete",
        "canvas_outcome": _,
        "impact_assessment": _,
        "profile": _,
        ..
      },
      ..
    } => ()
    _ => fail("expected versioned Agent projection header")
  }
  match @json.parse(lines[lines.length() - 1]) {
    {
      "projection_version": "svgdiff-agent-projection/1",
      "record_type": "item",
      "sequence": _,
      "section": "events",
      "index": 0,
      "value": { "id": _, "atomic_difference_ids": [_], .. },
      ..
    } => ()
    _ => fail("expected final event item when no Diagnostics are present")
  }
}

///|
test "Agent projection header preserves explicit empty sections" {
  let report = compare(
    "<svg width='16' height='16'><rect width='8' height='8' fill='red'/><rect width='8' height='8' fill='red'/></svg>",
    "<svg width='16' height='16'><rect width='8' height='8' fill='red'/><rect width='8' height='8' fill='red'/></svg>",
    ComparisonProfile::v1_default(),
  )
  let header = report.to_agent_projection_json_lines().split("\n").collect()[0]
  match @json.parse(header) {
    {
      "section_counts": {
        "changed_facts": 0,
        "atomic_differences": 0,
        "events": 0,
        "diagnostics": 0,
        ..
      },
      ..
    } => ()
    _ => fail("expected explicit empty section counts")
  }
}
