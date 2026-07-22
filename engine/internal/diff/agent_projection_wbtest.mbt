///|
test "Agent projection partitions the concise report sections" {
  let report = compare(
    "<svg width='16' height='16'><rect width='8' height='8' fill='red'/></svg>",
    "<svg width='16' height='16'><rect width='8' height='8' fill='blue'/></svg>",
    ComparisonProfile::v1_default(),
  )
  let lines = report.to_agent_projection_json_lines().split("\n").collect()
  assert_eq(lines.length(), 3)
  match @json.parse(lines[0]) {
    {
      "projection_version": "svgdiff-agent-projection/1",
      "source_schema_version": "1.46",
      "record_type": "header",
      "sequence": 0,
      "section_counts": {
        "difference_groups": 1,
        "events": 1,
        "limitations": 0,
        ..
      },
      "value": { "schema_version": "1.46", "analysis_status": "complete", .. },
      ..
    } => ()
    _ => fail("expected concise projection header")
  }
  match @json.parse(lines[1]) {
    {
      "record_type": "item",
      "section": "difference_groups",
      "index": 0,
      "value": { "category": "paint", "items": [_], .. },
      ..
    } => ()
    _ => fail("expected categorized difference group item")
  }
}

///|
test "Agent projection header preserves explicit empty sections" {
  let report = compare(
    "<svg width='16' height='16'/>",
    "<svg width='16' height='16'/>",
    ComparisonProfile::v1_default(),
  )
  match
    @json.parse(
      report.to_agent_projection_json_lines().split("\n").collect()[0],
    ) {
    {
      "section_counts": {
        "difference_groups": 0,
        "events": 0,
        "limitations": 0,
        ..
      },
      ..
    } => ()
    _ => fail("expected explicit empty concise section counts")
  }
}
