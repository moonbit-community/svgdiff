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
fn escape_markdown_text(value : String) -> String {
  value
  .replace_all(old="\\", new="\\\\")
  .replace_all(old="\r", new="\\r")
  .replace_all(old="\n", new="\\n")
  .replace_all(old="\t", new="\\t")
  .replace_all(old="&", new="&amp;")
  .replace_all(old="<", new="&lt;")
  .replace_all(old=">", new="&gt;")
  .replace_all(old="`", new="&#96;")
  .replace_all(old="*", new="\\*")
  .replace_all(old="_", new="\\_")
  .replace_all(old="[", new="\\[")
  .replace_all(old="]", new="\\]")
}

///|
fn markdown_json_string(value : String) -> String {
  escape_markdown_text(ToJson::to_json(value).stringify())
}

///|
fn markdown_values(values : Array[String]) -> String {
  if values.is_empty() {
    "none"
  } else {
    values.map(escape_markdown_text).join(", ")
  }
}

///|
fn append_impact_summary(
  lines : Array[String],
  assessment : ImpactAssessment,
) -> Unit {
  lines.push("## Main-event frontier")
  lines.push("")
  lines.push(
    "The frontier is derived with policy " +
    escape_markdown_text(assessment.policy_id) +
    ". Its calibration status is " +
    escape_markdown_text(assessment.calibration_status) +
    "; it does not provide a severity label or total order.",
  )
  lines.push("")
  lines.push("- Assessment status: " + escape_markdown_text(assessment.status))
  lines.push(
    "- Frontier relation: " + escape_markdown_text(assessment.frontier_relation),
  )
  lines.push(
    "- Candidate Visual Events: " + assessment.candidate_event_count.to_string(),
  )
  lines.push("")
  if assessment.frontier_groups.is_empty() {
    lines.push("No frontier group is present in the report.")
  } else {
    for index, group in assessment.frontier_groups {
      let measurement_text = match group.measurements {
        Some(measurements) =>
          "changed_pixel_fraction=" +
          measurements.changed_pixel_fraction.to_string() +
          ", linear_premultiplied_rgba_rmse=" +
          measurements.linear_premultiplied_rgba_rmse.to_string()
        None => "unavailable"
      }
      lines.push(
        "- Group " +
        (index + 1).to_string() +
        ": events " +
        markdown_values(group.event_ids) +
        "; Atomic Differences " +
        markdown_values(group.atomic_difference_ids) +
        "; measurements " +
        measurement_text +
        ".",
      )
    }
  }
  lines.push("")
  match assessment.frontier_relation {
    "tied" =>
      lines.push(
        "The listed events form an exact measured tie under this policy.",
      )
    "incomparable" | "mixed" =>
      lines.push(
        "Distinct frontier groups are incomparable under this policy; their serialized order is not an impact ranking.",
      )
    _ => ()
  }
  if assessment.status == "partial" {
    lines.push(
      "At least one candidate lacks a required Impact measurement; unavailable values are not zero.",
    )
  }
  if !assessment.domination_witnesses.is_empty() {
    lines.push("")
    lines.push("Dominated-event witnesses:")
    for witness in assessment.domination_witnesses {
      lines.push(
        "- " +
        escape_markdown_text(witness.dominated_event_id) +
        " is excluded by witness " +
        escape_markdown_text(witness.dominant_event_id) +
        " under rule " +
        escape_markdown_text(witness.rule_id) +
        ".",
      )
    }
  }
}

///|
fn append_atomic_difference_summary(
  lines : Array[String],
  difference : AtomicDifference,
) -> Unit {
  let alignment = match difference.subject_alignment_id {
    Some(value) => escape_markdown_text(value)
    None => "none"
  }
  lines.push("### " + escape_markdown_text(difference.id))
  lines.push("")
  lines.push("- Domain: " + escape_markdown_text(difference.domain))
  lines.push("- Subject role: " + escape_markdown_text(difference.subject_role))
  lines.push("- Subject Alignment: " + alignment)
  lines.push(
    "- Source values: before " +
    markdown_json_string(difference.source_before) +
    "; after " +
    markdown_json_string(difference.source_after),
  )
  lines.push(
    "- Computed relation: " +
    escape_markdown_text(difference.computed_relation.status) +
    " (reason " +
    escape_markdown_text(difference.computed_relation.reason_code) +
    ")",
  )
  lines.push(
    "- Evidence layers: " + markdown_values(difference.evidence_layers),
  )
  lines.push("- Changed Facts: " + markdown_values(difference.changed_fact_ids))
  lines.push(
    "- Relation Diagnostics: " +
    markdown_values(difference.computed_relation.diagnostic_ids),
  )
  lines.push("- Exact magnitude object from the report:")
  lines.push("")
  lines.push("    " + ToJson::to_json(difference.magnitude).stringify())
  lines.push("")
}

///|
fn append_diagnostic_summary(
  lines : Array[String],
  diagnostic : Diagnostic,
) -> Unit {
  lines.push("### " + escape_markdown_text(diagnostic.id))
  lines.push("")
  lines.push("- Code: " + escape_markdown_text(diagnostic.code))
  lines.push("- Subject: " + escape_markdown_text(diagnostic.subject_id))
  lines.push(
    "- Affected evidence layers: " +
    markdown_values(diagnostic.affected_evidence_layers),
  )
  lines.push("- Exact Diagnostic object from the report:")
  lines.push("")
  lines.push("    " + ToJson::to_json(diagnostic).stringify())
  lines.push("")
}

///|
/// Render a deterministic Markdown orientation summary from a report.
///
/// This is derived presentation only. The supplied Structured Report remains
/// authoritative for every field, reference, magnitude, region, cause
/// candidate, coverage result, and Diagnostic.
pub fn render_markdown_summary(report : StructuredReport) -> String {
  let lines : Array[String] = [
    "# SVG Diff Summary",
    "",
    "> Derived presentation only. This Markdown may omit evidence. The canonical Structured Report JSON is authoritative.",
    "",
    "## Report orientation",
    "",
    "- Structured Report Schema: " + escape_markdown_text(report.schema_version),
    "- Analysis status: " + escape_markdown_text(report.analysis_status),
    "- Atomic Differences: " + report.atomic_differences.length().to_string(),
    "- Visual Events: " + report.events.length().to_string(),
    "- Diagnostics: " + report.diagnostics.length().to_string(),
    "",
  ]
  if report.analysis_status != "complete" {
    lines.push(
      "The analysis status is not complete. Inspect coverage and Diagnostics before drawing conclusions from omitted evidence.",
    )
    lines.push("")
  }
  append_impact_summary(lines, report.impact_assessment)
  lines.push("")
  lines.push("## All Atomic Differences")
  lines.push("")
  if report.atomic_differences.is_empty() {
    lines.push("The report contains no Atomic Difference records.")
    lines.push("")
  } else {
    for difference in report.atomic_differences {
      append_atomic_difference_summary(lines, difference)
    }
  }
  lines.push("## Diagnostics")
  lines.push("")
  if report.diagnostics.is_empty() {
    lines.push("The report contains no Diagnostic records.")
    lines.push("")
  } else {
    for diagnostic in report.diagnostics {
      append_diagnostic_summary(lines, diagnostic)
    }
  }
  lines.join("\n")
}
