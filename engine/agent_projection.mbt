///|
const AGENT_PROJECTION_VERSION : String = "svgdiff-agent-projection/1"

///|
fn agent_projection_header(report : StructuredReport) -> Json {
  {
    "projection_version": AGENT_PROJECTION_VERSION,
    "source_schema_version": report.schema_version,
    "record_type": "header",
    "sequence": 0,
    "section_counts": {
      "coverage_matrix": report.coverage_matrix.length(),
      "renderer_capability_gaps": report.renderer_capability_gaps.length(),
      "subject_alignments": report.subject_alignments.length(),
      "changed_facts": report.changed_facts.length(),
      "source_resolutions": report.source_resolutions.length(),
      "atomic_differences": report.atomic_differences.length(),
      "events": report.events.length(),
      "diagnostics": report.diagnostics.length(),
    },
    "value": {
      "schema_version": report.schema_version,
      "analysis_status": report.analysis_status,
      "impact_assessment": report.impact_assessment,
      "profile": report.profile,
    },
  }
}

///|
fn agent_projection_item(
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
fn[T : ToJson] append_agent_projection_section(
  lines : Array[String],
  schema_version : String,
  section : String,
  values : Array[T],
  sequence : Int,
) -> Int {
  let mut next_sequence = sequence
  for index, value in values {
    lines.push(
      agent_projection_item(
        schema_version,
        next_sequence,
        section,
        index,
        value.to_json(),
      ).stringify(),
    )
    next_sequence += 1
  }
  next_sequence
}

///|
/// Serialize this report as lossless line-addressable Agent projection JSONL.
///
/// The header retains all non-array report fields and exact section counts.
/// Each following record retains one canonical array item. Concatenating every
/// record reconstructs the complete Structured Report without semantic loss.
pub fn StructuredReport::to_agent_projection_json_lines(
  self : StructuredReport,
) -> String {
  let lines = [agent_projection_header(self).stringify()]
  let mut sequence = 1
  sequence = append_agent_projection_section(
    lines,
    self.schema_version,
    "coverage_matrix",
    self.coverage_matrix,
    sequence,
  )
  sequence = append_agent_projection_section(
    lines,
    self.schema_version,
    "renderer_capability_gaps",
    self.renderer_capability_gaps,
    sequence,
  )
  sequence = append_agent_projection_section(
    lines,
    self.schema_version,
    "subject_alignments",
    self.subject_alignments,
    sequence,
  )
  sequence = append_agent_projection_section(
    lines,
    self.schema_version,
    "changed_facts",
    self.changed_facts,
    sequence,
  )
  sequence = append_agent_projection_section(
    lines,
    self.schema_version,
    "source_resolutions",
    self.source_resolutions,
    sequence,
  )
  sequence = append_agent_projection_section(
    lines,
    self.schema_version,
    "atomic_differences",
    self.atomic_differences,
    sequence,
  )
  sequence = append_agent_projection_section(
    lines,
    self.schema_version,
    "events",
    self.events,
    sequence,
  )
  let _ = append_agent_projection_section(
    lines,
    self.schema_version,
    "diagnostics",
    self.diagnostics,
    sequence,
  )
  lines.join("\n")
}
