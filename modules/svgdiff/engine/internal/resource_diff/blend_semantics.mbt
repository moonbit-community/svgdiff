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
fn blend_site_for_owner(
  sites : Array[BlendSite],
  owner_id : String,
) -> BlendSite? {
  for site in sites {
    if site.owner_id == owner_id {
      return Some(site)
    }
  }
  None
}

///|
fn blend_report_diagnostic_ids(
  report : StructuredReport,
  subject_ids : Array[String],
) -> Array[String] {
  let ids : Array[String] = []
  for diagnostic in report.diagnostics {
    if subject_ids.contains(diagnostic.subject_id) ||
      diagnostic.subject_id == "document" {
      ids.push(diagnostic.id)
    }
  }
  ids
}

///|
fn blend_rendered_evidence(
  before_svg : String,
  after_svg : String,
  profile : ComparisonProfile,
) -> RenderedEvidence {
  match
    (
      render_product_source_to_image(before_svg, profile),
      render_product_source_to_image(after_svg, profile),
    ) {
    (Some(before), Some(after)) =>
      computed_rendered_evidence(rendered_image_difference(before, after))
    _ => not_computed_rendered_evidence("blend_renderer_unavailable")
  }
}

///|
fn blend_property_fact(
  site : BlendSite,
  property : String,
) -> DeclaredVisualFact? {
  if property == "mix-blend-mode" {
    site.blend_fact
  } else {
    site.isolation_fact
  }
}

///|
fn blend_property_resolution(
  site : BlendSite,
  property : String,
) -> ResolvedVisualFact {
  if property == "mix-blend-mode" {
    site.blend_resolution
  } else {
    site.isolation_resolution
  }
}

///|
fn blend_property_dependencies(
  site : BlendSite,
  property : String,
) -> Array[StyleDependency] {
  if property == "mix-blend-mode" {
    site.blend_dependencies
  } else {
    site.isolation_dependencies
  }
}

///|
fn blend_property_value(site : BlendSite, property : String) -> String {
  if property == "mix-blend-mode" {
    site.blend_mode
  } else {
    site.isolation
  }
}

///|
fn blend_append_dependency_facts(
  changed_facts : Array[ChangedFact],
  changed_fact_ids : Array[String],
  before : BlendSemanticDocument,
  after : BlendSemanticDocument,
  dependencies : Array[StyleDependency],
  affected_subject_ids : Array[String],
  direct_owner_id : String,
  direct_property : String,
) -> Unit {
  for dependency in dependencies {
    if dependency.owner_id == direct_owner_id &&
      dependency.property == direct_property {
      continue
    }
    let before_fact = local_property_declaration(
      before.hierarchy,
      dependency.owner_id,
      dependency.property,
    )
    let after_fact = local_property_declaration(
      after.hierarchy,
      dependency.owner_id,
      dependency.property,
    )
    if !declared_fact_changed(before_fact, after_fact) {
      continue
    }
    let fact_id = "changed:source:\{dependency.owner_id}:\{dependency.property}"
    if !changed_fact_ids.contains(fact_id) {
      changed_fact_ids.push(fact_id)
    }
    let mut found = false
    for index, fact in changed_facts {
      if fact.id == fact_id {
        let merged = fact.affected_subject_ids.copy()
        append_unique_subjects(merged, affected_subject_ids)
        changed_facts[index] = { ..fact, affected_subject_ids: merged }
        found = true
        break
      }
    }
    if !found {
      changed_facts.push({
        id: fact_id,
        subject_id: dependency.owner_id,
        property: dependency.property,
        before: before_fact,
        after: after_fact,
        affected_subject_ids,
      })
    }
  }
}

///|
pub fn attach_blend_differences(
  report : StructuredReport,
  before_svg : String,
  after_svg : String,
) -> (StructuredReport, Array[SubjectAlignment]) {
  let before = try
    resolve_blend_semantic_document_or_raise(before_svg, report.profile)
  catch {
    _ => return (report, [])
  } noraise {
    value => value
  }
  let after = try
    resolve_blend_semantic_document_or_raise(after_svg, report.profile)
  catch {
    _ => return (report, [])
  } noraise {
    value => value
  }
  let owner_ids : Array[String] = []
  for site in before.sites + after.sites {
    if (site.blend_fact is Some(_) || site.isolation_fact is Some(_)) &&
      !owner_ids.contains(site.owner_id) {
      owner_ids.push(site.owner_id)
    }
  }
  owner_ids.sort()
  if owner_ids.is_empty() {
    return (report, [])
  }
  let changed_facts = report.changed_facts.copy()
  let resolutions = report.source_resolutions.copy()
  let differences = report.atomic_differences.copy()
  let events = report.events.copy()
  let alignments : Array[SubjectAlignment] = []
  let rendered = blend_rendered_evidence(before_svg, after_svg, report.profile)
  for owner_id in owner_ids {
    guard blend_site_for_owner(before.sites, owner_id) is Some(left) &&
      blend_site_for_owner(after.sites, owner_id) is Some(right) else {
      continue
    }
    let alignment_id = "alignment:compositing:\{owner_id}"
    alignments.push({
      id: alignment_id,
      subject_role: "entity",
      relation: "correspondence",
      before: [
        {
          source_index: left.source_index,
          kind: left.kind,
          authored_id: Some(owner_id),
          instance_context: None,
        },
      ],
      after: [
        {
          source_index: right.source_index,
          kind: right.kind,
          authored_id: Some(owner_id),
          instance_context: None,
        },
      ],
      basis: "group_identity_or_singleton",
      evidence: {
        score_kind: "group_identity_or_singleton",
        selected_score: None,
        candidate_count: 0,
        equal_score_candidate_count: 0,
        ambiguity: "not_assessed",
        confidence: None,
        confidence_status: "not_calibrated",
      },
    })
    let affected = left.affected_subject_ids.copy()
    append_unique_subjects(affected, right.affected_subject_ids)
    for property in ["mix-blend-mode", "isolation"] {
      let left_fact = blend_property_fact(left, property)
      let right_fact = blend_property_fact(right, property)
      let left_resolution = blend_property_resolution(left, property)
      let right_resolution = blend_property_resolution(right, property)
      if !declared_fact_changed(left_fact, right_fact) &&
        !resolution_source_changed(
          Some(left_resolution),
          Some(right_resolution),
        ) {
        continue
      }
      let fact_id = "fact:compositing:\{owner_id}:\{property}"
      let difference_id = "diff:compositing:\{owner_id}:\{property}"
      let changed_fact_ids : Array[String] = []
      if declared_fact_changed(left_fact, right_fact) {
        changed_facts.push({
          id: fact_id,
          subject_id: owner_id,
          property,
          before: left_fact,
          after: right_fact,
          affected_subject_ids: affected,
        })
        changed_fact_ids.push(fact_id)
      }
      let dependencies = blend_property_dependencies(left, property)
      append_style_dependencies(
        dependencies,
        blend_property_dependencies(right, property),
      )
      blend_append_dependency_facts(
        changed_facts, changed_fact_ids, before, after, dependencies, affected, owner_id,
        property,
      )
      resolutions.push({
        subject_id: owner_id,
        property,
        before: Some(left_resolution),
        after: Some(right_resolution),
      })
      let left_value = blend_property_value(left, property)
      let right_value = blend_property_value(right, property)
      let diagnostic_ids = blend_report_diagnostic_ids(report, affected)
      let complete = left.complete &&
        right.complete &&
        diagnostic_ids.is_empty()
      let relation : ComputedRelation = if complete {
        {
          status: if left_value == right_value {
            "equivalent"
          } else {
            "different"
          },
          reason_code: if left_value == right_value {
            "same_resolved_compositing_value"
          } else {
            "resolved_compositing_values_differ"
          },
          missing_side: None,
          diagnostic_ids: [],
        }
      } else {
        {
          status: "indeterminate",
          reason_code: "compositing_coverage_partial",
          missing_side: None,
          diagnostic_ids,
        }
      }
      differences.push({
        id: difference_id,
        subject_role: if fill_entity_kind(left.kind) {
          "entity"
        } else {
          "container"
        },
        subject_alignment_id: Some(alignment_id),
        domain: if property == "mix-blend-mode" {
          "compositing.blend_mode"
        } else {
          "compositing.isolation"
        },
        source_before: declared_value_or_empty(left_fact),
        source_after: declared_value_or_empty(right_fact),
        source_fact_before: left_fact,
        source_fact_after: right_fact,
        changed_fact_ids,
        evidence_layers: if complete && left_value != right_value {
          ["source_semantics", "computed_appearance", "rendered_evidence"]
        } else {
          ["source_semantics"]
        },
        computed_relation: relation,
        parameter_delta_css_px: None,
        presence_magnitude: None,
        magnitude: empty_difference_magnitude(),
        domain_ordering: empty_domain_ordering(),
      })
      events.push({
        id: "event:compositing:\{owner_id}:\{property}",
        primary_subject_id: owner_id,
        atomic_difference_ids: [difference_id],
        rendered_outcome: if complete {
          rendered
        } else {
          not_computed_rendered_evidence("compositing_renderer_unavailable")
        },
        difference_regions: [],
      })
    }
  }
  (
    {
      ..report,
      changed_facts,
      source_resolutions: resolutions,
      atomic_differences: differences,
      events,
    },
    alignments,
  )
}
