// Copyright 2026 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

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
      "source_schema_version": "2.0",
      "record_type": "header",
      "sequence": 0,
      "section_counts": {
        "difference_groups": 1,
        "events": 1,
        "limitations": 0,
        ..
      },
      "value": { "schema_version": "2.0", "analysis_status": "complete", .. },
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
