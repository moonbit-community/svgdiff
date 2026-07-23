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
fn viewport_property_order() -> Array[String] {
  ["x", "y", "width", "height", "viewBox", "preserveAspectRatio"]
}

///|
fn viewport_fact_at(
  site : SourceTransformSite?,
  property : String,
) -> DeclaredVisualFact? {
  match site {
    Some(site) =>
      for fact in site.viewport_facts {
        if fact.property == property {
          return Some(fact)
        }
      }
    None => ()
  }
  None
}

///|
fn viewport_fact_changed(
  before : DeclaredVisualFact?,
  after : DeclaredVisualFact?,
) -> Bool {
  match (before, after) {
    (None, None) => false
    (Some(_), None) | (None, Some(_)) => true
    (Some(before), Some(after)) =>
      before.authored_value != after.authored_value ||
      before.declared_value != after.declared_value ||
      before.origin != after.origin
  }
}

///|
fn viewport_fact_change_id(
  before : SourceTransformSite?,
  after : SourceTransformSite?,
  property : String,
) -> String {
  let before_index = match before {
    Some(site) => site.node_index.to_string()
    None => "none"
  }
  let after_index = match after {
    Some(site) => site.node_index.to_string()
    None => "none"
  }
  "fact:viewport:\{before_index}:\{after_index}:\{property}"
}

///|
fn add_viewport_fact_changes_for_alignment(
  changes : Array[TransformFactChange],
  before_sites : Array[SourceTransformSite],
  after_sites : Array[SourceTransformSite],
  site_alignment : Array[(Int?, Int?)],
  affected_subject_ids : Array[String],
) -> Unit {
  for pair in site_alignment {
    let (before_index, after_index) = pair
    let before_site = transform_site_at(before_sites, before_index)
    let after_site = transform_site_at(after_sites, after_index)
    for property in viewport_property_order() {
      let before_fact = viewport_fact_at(before_site, property)
      let after_fact = viewport_fact_at(after_site, property)
      if !viewport_fact_changed(before_fact, after_fact) {
        continue
      }
      let id = viewport_fact_change_id(before_site, after_site, property)
      let mut existing = false
      for change in changes {
        if change.id == id {
          for subject_id in affected_subject_ids {
            if !change.affected_subject_ids.contains(subject_id) {
              change.affected_subject_ids.push(subject_id)
            }
          }
          existing = true
        }
      }
      if !existing {
        changes.push({
          id,
          subject_id: transform_change_subject_id(before_site, after_site),
          property,
          before: before_fact,
          after: after_fact,
          affected_subject_ids: affected_subject_ids.copy(),
        })
      }
    }
  }
}

///|
fn viewport_diagnostic_ids(
  report : StructuredReport,
  code : String,
  before : SourceTransformSite?,
  after : SourceTransformSite?,
) -> Array[String] {
  [
    for diagnostic in report.diagnostics if diagnostic.code == code &&
    transform_syntax_diagnostic_matches(diagnostic, before, after) => {
      diagnostic.id
    }
  ]
}

///|
fn viewport_local_matrix(site : SourceTransformSite?) -> AffineTransform {
  match site {
    Some(site) => site.viewport_matrix
    None => AffineTransform::identity()
  }
}

///|
fn viewport_site_complete(site : SourceTransformSite?) -> Bool {
  match site {
    Some(site) => site.viewport_complete
    None => true
  }
}

///|
fn viewport_relation(
  report : StructuredReport,
  before : SourceTransformSite?,
  after : SourceTransformSite?,
) -> ComputedRelation {
  if !viewport_site_complete(before) || !viewport_site_complete(after) {
    return {
      status: "indeterminate",
      reason_code: "viewport_semantics_unsupported",
      missing_side: None,
      diagnostic_ids: viewport_diagnostic_ids(
        report, "viewport_semantics_unsupported", before, after,
      ),
    }
  }
  let equal = viewport_local_matrix(before) == viewport_local_matrix(after)
  {
    status: if equal {
      "equivalent"
    } else {
      "different"
    },
    reason_code: if equal {
      "same_local_viewport_mapping"
    } else {
      "local_viewport_mappings_differ"
    },
    missing_side: None,
    diagnostic_ids: viewport_diagnostic_ids(
      report, "renderer_viewport_raster_unproven", before, after,
    ),
  }
}

///|
fn append_viewport_differences(
  report : StructuredReport,
  alignment : SubjectAlignment,
  before : SourceSubject,
  after : SourceSubject,
  site_alignment : Array[(Int?, Int?)],
  changes : Array[TransformFactChange],
  differences : Array[AtomicDifference],
  difference_ids : Array[String],
) -> Array[String] {
  let changed_fact_ids : Array[String] = []
  for pair in site_alignment {
    let (before_index, after_index) = pair
    let before_site = transform_site_at(before.transform_chain, before_index)
    let after_site = transform_site_at(after.transform_chain, after_index)
    for property in viewport_property_order() {
      let before_fact = viewport_fact_at(before_site, property)
      let after_fact = viewport_fact_at(after_site, property)
      if !viewport_fact_changed(before_fact, after_fact) {
        continue
      }
      let fact_id = viewport_fact_change_id(before_site, after_site, property)
      changed_fact_ids.push(fact_id)
      let change = match transform_fact_change(changes, fact_id) {
        Some(change) => change
        None => continue
      }
      let difference_id = "diff:\{alignment.id}:viewport:\{fact_id}"
      let relation = viewport_relation(report, before_site, after_site)
      let evidence_layers : Array[String] = ["source_semantics"]
      if relation.status != "indeterminate" {
        evidence_layers.push("computed_appearance")
        evidence_layers.push("rendered_evidence")
      }
      differences.push({
        id: difference_id,
        subject_role: "entity",
        subject_alignment_id: Some(alignment.id),
        domain: "document.viewport",
        source_before: declared_value_or_empty(change.before),
        source_after: declared_value_or_empty(change.after),
        source_fact_before: change.before,
        source_fact_after: change.after,
        changed_fact_ids: [fact_id],
        evidence_layers,
        computed_relation: relation,
        parameter_delta_css_px: None,
        presence_magnitude: None,
        magnitude: empty_difference_magnitude(),
        domain_ordering: empty_domain_ordering(),
      })
      difference_ids.push(difference_id)
    }
  }
  changed_fact_ids
}
