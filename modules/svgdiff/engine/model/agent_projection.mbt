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
const AGENT_PROJECTION_VERSION : String = "svgdiff-agent-projection/2"

///|
fn projection_header(report : StructuredReport) -> Json {
  {
    "projection_version": AGENT_PROJECTION_VERSION,
    "source_schema_version": report.schema_version,
    "record_type": "header",
    "sequence": 0,
    "section_counts": {
      "difference_groups": compact_difference_groups(report).length(),
      "events": report.events.length(),
      "limitations": report.diagnostics.length(),
    },
    "value": {
      "schema_version": report.schema_version,
      "analysis_status": report.analysis_status,
      "comparison": compact_comparison(report.profile),
      "canvas": compact_canvas_outcome(report.canvas_outcome),
      "scene": compact_visual_scene(report.visual_scene),
    },
  }
}

///|
fn projection_item(
  schema_version : String,
  sequence : Int,
  section : String,
  index : Int,
  value : Json,
) -> Json {
  {
    "projection_version": AGENT_PROJECTION_VERSION,
    "source_schema_version": schema_version,
    "record_type": "item",
    "sequence": sequence,
    "section": section,
    "index": index,
    "value": value,
  }
}

///|
fn append_projection_section(
  lines : Array[String],
  schema_version : String,
  section : String,
  values : Array[Json],
  sequence : Int,
) -> Int {
  let mut next = sequence
  for index, value in values {
    lines.push(
      projection_item(schema_version, next, section, index, value).stringify(),
    )
    next += 1
  }
  next
}

///|
/// Serialize the concise report as line-addressable JSONL records.
pub fn StructuredReport::to_agent_projection_json_lines(
  self : StructuredReport,
) -> String {
  let lines = [projection_header(self).stringify()]
  let groups = compact_difference_groups(self)
  let mut sequence = append_projection_section(
    lines,
    self.schema_version,
    "difference_groups",
    groups,
    1,
  )
  sequence = append_projection_section(
    lines,
    self.schema_version,
    "events",
    [
      for event in self.events => compact_event(self, event)
    ],
    sequence,
  )
  let _ = append_projection_section(
    lines,
    self.schema_version,
    "limitations",
    [
      for diagnostic in self.diagnostics => compact_limitation(diagnostic)
    ],
    sequence,
  )
  lines.join("\n")
}
