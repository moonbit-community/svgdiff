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
priv struct MarkerResourcePair {
  before : MarkerResource?
  after : MarkerResource?
}

///|
fn marker_resource_pairs(
  before : Array[MarkerResource],
  after : Array[MarkerResource],
) -> Array[MarkerResourcePair] {
  let pairs : Array[MarkerResourcePair] = []
  let used = Array::make(after.length(), false)
  for before_resource in before {
    let mut selected = -1
    for index, after_resource in after {
      if !used[index] && before_resource.subject_id == after_resource.subject_id {
        selected = index
        break
      }
    }
    if selected < 0 && before_resource.authored_id is None {
      for index, _ in after {
        if !used[index] && after[index].authored_id is None {
          selected = index
          break
        }
      }
    }
    if selected >= 0 {
      used[selected] = true
      pairs.push({ before: Some(before_resource), after: Some(after[selected]) })
    } else {
      pairs.push({ before: Some(before_resource), after: None })
    }
  }
  for index, after_resource in after {
    if !used[index] {
      pairs.push({ before: None, after: Some(after_resource) })
    }
  }
  pairs
}

///|
fn marker_resource_property_order() -> Array[String] {
  [
    "markerUnits", "markerWidth", "markerHeight", "refX", "refY", "orient", "viewBox",
    "preserveAspectRatio", "overflow", "content",
  ]
}

///|
fn marker_resource_fact(
  resource : MarkerResource,
  property : String,
) -> DeclaredVisualFact? {
  if property == "content" {
    return Some(resource.content_fact)
  }
  shape_fact(resource.facts, property)
}

///|
fn marker_resource_value(
  resource : MarkerResource,
  property : String,
) -> String {
  match property {
    "markerUnits" => resource.marker_units
    "markerWidth" => canonical_shape_number(resource.marker_width)
    "markerHeight" => canonical_shape_number(resource.marker_height)
    "refX" => canonical_shape_number(resource.ref_x)
    "refY" => canonical_shape_number(resource.ref_y)
    "orient" =>
      if resource.orient_kind == "angle" {
        canonical_shape_number(resource.orient_angle)
      } else {
        resource.orient_kind
      }
    "viewBox" =>
      match resource.view_box {
        Some(value) => normalized_view_box_signature(value)
        None => "none"
      }
    "preserveAspectRatio" =>
      preserve_aspect_ratio_signature(resource.preserve_aspect_ratio)
    "overflow" => resource.overflow
    "content" => resource.content_fact.declared_value
    _ => ""
  }
}

///|
fn marker_resource_source_changed(
  before : DeclaredVisualFact?,
  after : DeclaredVisualFact?,
) -> Bool {
  match (before, after) {
    (None, None) => false
    (Some(left), Some(right)) =>
      left.authored_value != right.authored_value ||
      left.declared_value != right.declared_value ||
      left.origin != right.origin
    _ => true
  }
}

///|
fn marker_resource_domain(property : String) -> String {
  match property {
    "markerUnits" => "resource.marker.units"
    "markerWidth" | "markerHeight" => "resource.marker.viewport_size"
    "refX" | "refY" => "resource.marker.reference_point"
    "orient" => "resource.marker.orientation"
    "viewBox" | "preserveAspectRatio" => "resource.marker.viewport_mapping"
    "overflow" => "resource.marker.overflow"
    "content" => "resource.marker.content"
    _ => "resource.marker.unsupported"
  }
}

///|
fn marker_resource_diagnostic_ids(
  report : StructuredReport,
  subject_ids : Array[String],
) -> Array[String] {
  [
    for diagnostic in report.diagnostics if subject_ids.contains(
      diagnostic.subject_id,
    ) &&
    (
      diagnostic.code == "marker_resource_semantics_unsupported" ||
      diagnostic.code == "marker_content_semantics_unsupported" ||
      diagnostic.code == "renderer_marker_raster_unproven"
    ) => diagnostic.id
  ]
}

///|
fn marker_resource_affected_subjects(
  before_subjects : Array[SourceSubject],
  after_subjects : Array[SourceSubject],
  resource_id : String,
) -> Array[String] {
  let ids : Array[String] = []
  for subject in before_subjects {
    if subject_references_marker(subject, Some(resource_id)) {
      let id = source_subject_id(subject)
      if !ids.contains(id) {
        ids.push(id)
      }
    }
  }
  for subject in after_subjects {
    if subject_references_marker(subject, Some(resource_id)) {
      let id = source_subject_id(subject)
      if !ids.contains(id) {
        ids.push(id)
      }
    }
  }
  ids.sort()
  ids
}

///|
fn marker_resource_relation(
  report : StructuredReport,
  before : MarkerResource,
  after : MarkerResource,
  property : String,
  affected_subject_ids : Array[String],
) -> ComputedRelation {
  if affected_subject_ids.is_empty() {
    return {
      status: "equivalent",
      reason_code: "unreferenced_marker_resource",
      missing_side: None,
      diagnostic_ids: [],
    }
  }
  let diagnostic_ids = marker_resource_diagnostic_ids(
    report,
    [before.subject_id, ..affected_subject_ids],
  )
  if !before.complete || !after.complete {
    return {
      status: "indeterminate",
      reason_code: "marker_resource_semantics_unsupported",
      missing_side: None,
      diagnostic_ids,
    }
  }
  let equivalent = marker_resource_value(before, property) ==
    marker_resource_value(after, property)
  if equivalent {
    return {
      status: "equivalent",
      reason_code: "same_marker_resource_value",
      missing_side: None,
      diagnostic_ids,
    }
  }
  if (before.marker_width == 0.0 && after.marker_width == 0.0) ||
    (before.marker_height == 0.0 && after.marker_height == 0.0) {
    return {
      status: "equivalent",
      reason_code: "marker_viewport_suppresses_paint",
      missing_side: None,
      diagnostic_ids,
    }
  }
  if property == "preserveAspectRatio" &&
    before.view_box is None &&
    after.view_box is None {
    return {
      status: "equivalent",
      reason_code: "marker_viewbox_mapping_not_applicable",
      missing_side: None,
      diagnostic_ids,
    }
  }
  if diagnostic_ids.any(id => {
      id.find("marker-content-semantics-unsupported") is Some(_)
    }) {
    return {
      status: "indeterminate",
      reason_code: "marker_content_semantics_unsupported",
      missing_side: None,
      diagnostic_ids,
    }
  }
  {
    status: "different",
    reason_code: "marker_resource_values_differ",
    missing_side: None,
    diagnostic_ids,
  }
}

///|
fn marker_resource_event_evidence() -> RenderedEvidence {
  not_computed_rendered_evidence("renderer_marker_raster_unproven")
}

///|
fn append_marker_resource_presence_difference(
  report : StructuredReport,
  resource : MarkerResource,
  missing_side : String,
  affected_subject_ids : Array[String],
  changed_facts : Array[ChangedFact],
  differences : Array[AtomicDifference],
  events : Array[VisualEvent],
) -> Unit {
  let fact_id = "fact:marker-resource:\{missing_side}:\{resource.node_index}:\{resource.subject_id}:presence"
  let difference_id = "diff:marker-resource:\{missing_side}:\{resource.node_index}:\{resource.subject_id}:presence"
  let insertion = missing_side == "before"
  changed_facts.push({
    id: fact_id,
    subject_id: resource.subject_id,
    property: "presence",
    before: if insertion {
      None
    } else {
      Some(resource.content_fact)
    },
    after: if insertion {
      Some(resource.content_fact)
    } else {
      None
    },
    affected_subject_ids,
  })
  differences.push({
    id: difference_id,
    subject_role: "resource",
    subject_alignment_id: None,
    domain: "resource.marker.presence",
    source_before: if insertion {
      ""
    } else {
      "present"
    },
    source_after: if insertion {
      "present"
    } else {
      ""
    },
    source_fact_before: if insertion {
      None
    } else {
      Some(resource.content_fact)
    },
    source_fact_after: if insertion {
      Some(resource.content_fact)
    } else {
      None
    },
    changed_fact_ids: [fact_id],
    evidence_layers: if affected_subject_ids.is_empty() {
      ["source_semantics"]
    } else {
      ["source_semantics", "computed_appearance"]
    },
    computed_relation: {
      status: if affected_subject_ids.is_empty() {
        "equivalent"
      } else {
        "not_applicable"
      },
      reason_code: if affected_subject_ids.is_empty() {
        "unreferenced_marker_resource"
      } else if insertion {
        "before_resource_absent"
      } else {
        "after_resource_absent"
      },
      missing_side: Some(missing_side),
      diagnostic_ids: marker_resource_diagnostic_ids(
        report,
        [resource.subject_id, ..affected_subject_ids],
      ),
    },
    parameter_delta_css_px: None,
    presence_magnitude: None,
    magnitude: empty_difference_magnitude(),
    domain_ordering: empty_domain_ordering(),
  })
  events.push({
    id: "event:marker-resource:\{resource.subject_id}:presence",
    primary_subject_id: resource.subject_id,
    atomic_difference_ids: [difference_id],
    rendered_outcome: marker_resource_event_evidence(),
    difference_regions: [],
  })
}

///|
pub fn attach_marker_resource_differences(
  report : StructuredReport,
  before_svg : String,
  after_svg : String,
) -> StructuredReport {
  let before_resources = extract_marker_resources_or_raise(
    before_svg,
    report.profile,
  ) catch {
    _ => return report
  }
  let after_resources = extract_marker_resources_or_raise(
    after_svg,
    report.profile,
  ) catch {
    _ => return report
  }
  let before_subjects = extract_source_subjects_with_profile_or_raise(
    before_svg,
    report.profile,
  ) catch {
    _ => []
  }
  let after_subjects = extract_source_subjects_with_profile_or_raise(
    after_svg,
    report.profile,
  ) catch {
    _ => []
  }
  let changed_facts = report.changed_facts.copy()
  let differences = report.atomic_differences.copy()
  let events = report.events.copy()
  for pair in marker_resource_pairs(before_resources, after_resources) {
    match (pair.before, pair.after) {
      (Some(before), Some(after)) => {
        let affected_subject_ids = marker_resource_affected_subjects(
          before_subjects,
          after_subjects,
          before.subject_id,
        )
        let difference_ids : Array[String] = []
        for property in marker_resource_property_order() {
          let before_fact = marker_resource_fact(before, property)
          let after_fact = marker_resource_fact(after, property)
          if !marker_resource_source_changed(before_fact, after_fact) {
            continue
          }
          let fact_id = "fact:marker-resource:\{before.node_index}:\{after.node_index}:\{property}"
          let difference_id = "diff:marker-resource:\{before.node_index}:\{after.node_index}:\{property}"
          let relation = marker_resource_relation(
            report, before, after, property, affected_subject_ids,
          )
          changed_facts.push({
            id: fact_id,
            subject_id: before.subject_id,
            property,
            before: before_fact,
            after: after_fact,
            affected_subject_ids,
          })
          differences.push({
            id: difference_id,
            subject_role: "resource",
            subject_alignment_id: None,
            domain: marker_resource_domain(property),
            source_before: declared_value_or_empty(before_fact),
            source_after: declared_value_or_empty(after_fact),
            source_fact_before: before_fact,
            source_fact_after: after_fact,
            changed_fact_ids: [fact_id],
            evidence_layers: if relation.status == "different" {
              ["source_semantics", "computed_appearance"]
            } else {
              ["source_semantics"]
            },
            computed_relation: relation,
            parameter_delta_css_px: match property {
              "markerWidth" => Some(after.marker_width - before.marker_width)
              "markerHeight" => Some(after.marker_height - before.marker_height)
              "refX" => Some(after.ref_x - before.ref_x)
              "refY" => Some(after.ref_y - before.ref_y)
              "orient" if before.orient_kind == "angle" &&
                after.orient_kind == "angle" =>
                Some(after.orient_angle - before.orient_angle)
              _ => None
            },
            presence_magnitude: None,
            magnitude: empty_difference_magnitude(),
            domain_ordering: empty_domain_ordering(),
          })
          difference_ids.push(difference_id)
        }
        if !difference_ids.is_empty() {
          events.push({
            id: "event:marker-resource:\{before.subject_id}",
            primary_subject_id: before.subject_id,
            atomic_difference_ids: difference_ids,
            rendered_outcome: marker_resource_event_evidence(),
            difference_regions: [],
          })
        }
      }
      (Some(resource), None) =>
        append_marker_resource_presence_difference(
          report,
          resource,
          "after",
          marker_resource_affected_subjects(
            before_subjects,
            after_subjects,
            resource.subject_id,
          ),
          changed_facts,
          differences,
          events,
        )
      (None, Some(resource)) =>
        append_marker_resource_presence_difference(
          report,
          resource,
          "before",
          marker_resource_affected_subjects(
            before_subjects,
            after_subjects,
            resource.subject_id,
          ),
          changed_facts,
          differences,
          events,
        )
      _ => ()
    }
  }
  { ..report, changed_facts, atomic_differences: differences, events }
}

///|
pub fn append_marker_resource_diagnostics(
  input : String,
  profile : ComparisonProfile,
  source_role : String,
  diagnostics : Array[Diagnostic],
) -> Unit raise {
  for resource in extract_marker_resources_or_raise(input, profile) {
    if !resource.complete {
      merge_diagnostic_into(diagnostics, {
        ..unlocated_diagnostic(
          "diagnostic:marker-resource-semantics-unsupported:\{resource.subject_id}",
          "marker_resource_semantics_unsupported",
          resource.subject_id,
          ["source_semantics", "computed_appearance", "rendered_evidence"],
        ),
        source_locations: resource.invalid_facts.map(fn(fact) {
          diagnostic_location(source_role, fact.source_span)
        }),
      })
    }
  }
}
