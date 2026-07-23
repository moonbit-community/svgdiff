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
fn structural_definition_domain(property : String) -> String {
  match property {
    "href" => "document.reference"
    "viewBox" | "preserveAspectRatio" => "geometry.viewport"
    "transform" => "geometry.transform"
    _ => generic_property_domain(property)
  }
}

///|
fn append_unused_definition_fact_difference(
  report : StructuredReport,
  subject_id : String,
  property : String,
  before : DeclaredVisualFact?,
  after : DeclaredVisualFact?,
  missing_side : String?,
) -> Unit {
  let safe_subject_id = subject_id.replace_all(old=":", new="-")
  let fact_id = "fact:unused-definition:\{safe_subject_id}:\{property}"
  let difference_id = "diff:unused-definition:\{safe_subject_id}:\{property}"
  report.changed_facts.push({
    id: fact_id,
    subject_id,
    property,
    before,
    after,
    affected_subject_ids: [],
  })
  report.atomic_differences.push({
    id: difference_id,
    subject_role: "resource",
    subject_alignment_id: None,
    domain: structural_definition_domain(property),
    source_before: if property == "presence" && missing_side == Some("after") {
      "present"
    } else {
      declared_value_or_empty(before)
    },
    source_after: if property == "presence" && missing_side == Some("before") {
      "present"
    } else {
      declared_value_or_empty(after)
    },
    source_fact_before: before,
    source_fact_after: after,
    changed_fact_ids: [fact_id],
    evidence_layers: ["source_semantics"],
    computed_relation: {
      status: "not_applicable",
      reason_code: "unused_definition",
      missing_side,
      diagnostic_ids: [],
    },
    parameter_delta_css_px: None,
    presence_magnitude: None,
    magnitude: empty_difference_magnitude(),
    domain_ordering: empty_domain_ordering(),
  })
}

///|
fn attach_unused_definition_differences(
  report : StructuredReport,
  before_svg : String,
  after_svg : String,
) -> StructuredReport {
  let before_document = extract_structural_document_or_raise(before_svg) catch {
    _ => return report
  }
  let after_document = extract_structural_document_or_raise(after_svg) catch {
    _ => return report
  }
  let before_css = parse_static_css_document_or_raise(before_svg) catch {
    _ => return report
  }
  let after_css = parse_static_css_document_or_raise(after_svg) catch {
    _ => return report
  }
  let before_indices = unused_definition_indices(before_document)
  let after_indices = unused_definition_indices(after_document)
  let after_used = Array::make(after_indices.length(), false)
  for before_index in before_indices {
    let before_node = before_document.nodes[before_index]
    let before_authored_id = authored_subject_id(before_node.element)
    let mut matched = -1
    for candidate, after_index in after_indices {
      if after_used[candidate] {
        continue
      }
      let after_node = after_document.nodes[after_index]
      let after_authored_id = authored_subject_id(after_node.element)
      if before_node.kind == after_node.kind &&
        (
          (
            before_authored_id is Some(_) &&
            before_authored_id == after_authored_id
          ) ||
          (before_authored_id is None && after_authored_id is None)
        ) {
        matched = candidate
        break
      }
    }
    if matched < 0 {
      if before_node.kind != "defs" {
        append_unused_definition_fact_difference(
          report,
          before_node.source_id,
          "presence",
          None,
          None,
          Some("after"),
        )
      }
      continue
    }
    after_used[matched] = true
    let after_node = after_document.nodes[after_indices[matched]]
    let before_facts = structural_definition_facts(
      before_svg, before_css, before_node,
    )
    let after_facts = structural_definition_facts(
      after_svg, after_css, after_node,
    )
    let properties : Array[String] = []
    for fact in before_facts + after_facts {
      if !properties.contains(fact.property) {
        properties.push(fact.property)
      }
    }
    properties.sort()
    for property in properties {
      let before_fact = declared_fact_in_array(before_facts, property)
      let after_fact = declared_fact_in_array(after_facts, property)
      if declared_fact_changed(before_fact, after_fact) {
        append_unused_definition_fact_difference(
          report,
          before_node.source_id,
          property,
          before_fact,
          after_fact,
          match (before_fact, after_fact) {
            (None, Some(_)) => Some("before")
            (Some(_), None) => Some("after")
            _ => None
          },
        )
      }
    }
  }
  for candidate, after_index in after_indices {
    if !after_used[candidate] {
      let after_node = after_document.nodes[after_index]
      if after_node.kind != "defs" {
        append_unused_definition_fact_difference(
          report,
          after_node.source_id,
          "presence",
          None,
          None,
          Some("before"),
        )
      }
    }
  }
  report
}
