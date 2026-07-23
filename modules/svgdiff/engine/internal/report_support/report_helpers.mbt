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
pub fn empty_difference_magnitude() -> DifferenceMagnitude {
  {
    parameter_abs_user_units: None,
    parameter_signed_user_units: None,
    symmetric_relative: None,
    parameter_abs_css_px: None,
    parameter_viewport_fraction: None,
    parameter_entity_fraction: None,
    geometry_displacement_css_px: None,
    painted_boundary_displacement: None,
    painted_coverage_difference: None,
    geometry_viewport_fraction: None,
    presence_painted_viewport_fraction: None,
    raster_changed_pixel_fraction: None,
    raster_rgba8_rmse: None,
    raster_linear_premultiplied_rgba_rmse: None,
    intrinsic_raster: None,
    transform_effect: None,
  }
}

///|
pub fn empty_domain_ordering() -> DomainOrdering {
  { policy_id: "v2_domain_lexicographic", components: [] }
}

///|
pub fn diagnostic_location(
  source_role : String,
  span : ReportSourceSpan,
) -> DiagnosticSourceLocation {
  { source_role, source_span: span }
}

///|
pub fn diagnostic_location_from_xml(
  source_role : String,
  span : @xml.SourceSpan,
) -> DiagnosticSourceLocation {
  diagnostic_location(source_role, {
    start_offset: span.start.offset,
    end_offset: span.end.offset,
  })
}

///|
pub fn unlocated_diagnostic(
  id : String,
  code : String,
  subject_id : String,
  affected_evidence_layers : Array[String],
) -> Diagnostic {
  { id, code, subject_id, affected_evidence_layers, source_locations: [] }
}

///|
pub fn located_diagnostic(
  id : String,
  code : String,
  subject_id : String,
  affected_evidence_layers : Array[String],
  source_role : String,
  span : @xml.SourceSpan,
) -> Diagnostic {
  {
    id,
    code,
    subject_id,
    affected_evidence_layers,
    source_locations: [diagnostic_location_from_xml(source_role, span)],
  }
}

///|
pub fn same_diagnostic_location(
  left : DiagnosticSourceLocation,
  right : DiagnosticSourceLocation,
) -> Bool {
  left.source_role == right.source_role &&
  left.source_span.start_offset == right.source_span.start_offset &&
  left.source_span.end_offset == right.source_span.end_offset
}

///|
pub fn merge_diagnostic_into(
  diagnostics : Array[Diagnostic],
  diagnostic : Diagnostic,
) -> Unit {
  let mut index = 0
  while index < diagnostics.length() {
    if diagnostics[index].id == diagnostic.id {
      for location in diagnostic.source_locations {
        if !diagnostics[index].source_locations.any(current => {
            same_diagnostic_location(current, location)
          }) {
          diagnostics[index].source_locations.push(location)
        }
      }
      return
    }
    index += 1
  }
  diagnostics.push(diagnostic)
}

///|
pub fn diagnostic_ids(diagnostics : Array[Diagnostic]) -> Array[String] {
  [
    for diagnostic in diagnostics => diagnostic.id
  ]
}

///|
pub fn append_unique_subjects(
  target : Array[String],
  source : Array[String],
) -> Unit {
  for subject_id in source {
    if !target.contains(subject_id) {
      target.push(subject_id)
    }
  }
}

///|
pub fn declared_value_or_empty(fact : DeclaredVisualFact?) -> String {
  fact.map(value => value.declared_value).unwrap_or("")
}

///|
pub fn element_diagnostic_locations(
  input : String,
  source_role : String,
  local_name : String,
) -> Array[DiagnosticSourceLocation] {
  let locations : Array[DiagnosticSourceLocation] = []
  let reader = @xml.NamespaceReader::from_string(input)
  let events = reader.read_events_until_eof() catch { _ => return locations }
  for event in events {
    match event.kind {
      Start(element) | Empty(element) if element.name.local_name == local_name =>
        locations.push(diagnostic_location_from_xml(source_role, event.span))
      _ => ()
    }
  }
  locations
}

///|
pub fn attach_diagnostic_fact_locations(
  report : StructuredReport,
) -> StructuredReport {
  for diagnostic in report.diagnostics {
    if !diagnostic.source_locations.is_empty() {
      continue
    }
    for difference in report.atomic_differences {
      if !difference.computed_relation.diagnostic_ids.contains(diagnostic.id) {
        continue
      }
      match difference.source_fact_before {
        Some(fact) =>
          merge_diagnostic_into(report.diagnostics, {
            ..diagnostic,
            source_locations: [diagnostic_location("before", fact.source_span)],
          })
        None => ()
      }
      match difference.source_fact_after {
        Some(fact) =>
          merge_diagnostic_into(report.diagnostics, {
            ..diagnostic,
            source_locations: [diagnostic_location("after", fact.source_span)],
          })
        None => ()
      }
    }
  }
  report
}
