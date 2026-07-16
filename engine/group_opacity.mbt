///|
priv struct OpacityGroup {
  subject_id : String
  source_index : Int
  kind : String
  fact : DeclaredVisualFact?
  resolution : ResolvedVisualFact
  dependencies : Array[StyleDependency]
  computed_opacity : Double?
  complete : Bool
  affected_subject_ids : Array[String]
}

///|
fn group_opacity_affected_subject_ids(
  hierarchy : FillHierarchy,
  group_index : Int,
) -> Array[String] {
  let ids : Array[String] = [hierarchy.elements[group_index].subject_id]
  for index, element in hierarchy.elements {
    if index == group_index || !fill_entity_kind(element.kind) {
      continue
    }
    let mut ancestor = element.parent_index
    while ancestor is Some(parent) {
      if parent == group_index {
        if !ids.contains(element.subject_id) {
          ids.push(element.subject_id)
        }
        break
      }
      ancestor = hierarchy.elements[parent].parent_index
    }
  }
  ids
}

///|
fn opacity_groups(hierarchy : FillHierarchy) -> Array[OpacityGroup] {
  let groups : Array[OpacityGroup] = []
  for index, element in hierarchy.elements {
    if !group_opacity_container(element.kind) {
      continue
    }
    guard computed_visual_for_subject(hierarchy, element.subject_id, "opacity")
      is Some(resolution) else {
      continue
    }
    groups.push({
      subject_id: element.subject_id,
      source_index: groups.length(),
      kind: element.kind,
      fact: resolution.reported.declaration,
      resolution: resolution.reported,
      dependencies: resolution.dependencies,
      computed_opacity: @css_color.parse_alpha_value(
        resolution.reported.resolved_value,
      ),
      complete: resolution.complete,
      affected_subject_ids: group_opacity_affected_subject_ids(hierarchy, index),
    })
  }
  groups
}

///|
fn group_opacity_diagnostic_ids(
  report : StructuredReport,
  subject_id : String,
) -> Array[String] {
  let ids : Array[String] = []
  for diagnostic in report.diagnostics {
    if (
        diagnostic.subject_id == subject_id ||
        diagnostic.subject_id == "document"
      ) &&
      diagnostic.affected_evidence_layers.contains("computed_appearance") {
      ids.push(diagnostic.id)
    }
  }
  ids
}

///|
fn group_opacity_reason_code(
  report : StructuredReport,
  diagnostic_ids : Array[String],
) -> String {
  for diagnostic in report.diagnostics {
    if diagnostic_ids.contains(diagnostic.id) {
      return diagnostic.code
    }
  }
  "group_opacity_resolution_unsupported"
}

///|
fn group_opacity_rendered_evidence(
  before_svg : String,
  after_svg : String,
  profile : ComparisonProfile,
) -> RenderedEvidence {
  match
    (
      @svg.parse_svg_document(
        normalize_renderer_input_with_profile(before_svg, profile),
      ),
      @svg.parse_svg_document(
        normalize_renderer_input_with_profile(after_svg, profile),
      ),
    ) {
    (Some(before), Some(after)) =>
      computed_rendered_evidence(rendered_difference(before, after, profile))
    _ => not_computed_rendered_evidence("group_opacity_renderer_unavailable")
  }
}

///|
fn attach_group_opacity_differences(
  report : StructuredReport,
  before_svg : String,
  after_svg : String,
) -> (StructuredReport, Array[SubjectAlignment]) {
  let before_hierarchy = extract_fill_hierarchy_or_raise(before_svg) catch {
    _ => return (report, [])
  }
  let after_hierarchy = extract_fill_hierarchy_or_raise(after_svg) catch {
    _ => return (report, [])
  }
  let before = opacity_groups(before_hierarchy)
  let after = opacity_groups(after_hierarchy)
  let after_used = Array::make(after.length(), false)
  let changed_facts = report.changed_facts.copy()
  let source_resolutions = report.source_resolutions.copy()
  let differences = report.atomic_differences.copy()
  let events = report.events.copy()
  let extra_alignments : Array[SubjectAlignment] = []
  for before_group in before {
    let mut after_index = -1
    for index, after_group in after {
      if !after_used[index] && before_group.subject_id == after_group.subject_id {
        after_index = index
        break
      }
    }
    if after_index < 0 && before.length() == 1 && after.length() == 1 {
      after_index = 0
    }
    if after_index < 0 {
      continue
    }
    after_used[after_index] = true
    let after_group = after[after_index]
    if !declared_fact_changed(before_group.fact, after_group.fact) &&
      !resolution_source_changed(
        Some(before_group.resolution),
        Some(after_group.resolution),
      ) {
      continue
    }
    let alignment_id = "alignment:group-opacity:\{extra_alignments.length()}"
    let fact_id = "fact:\{alignment_id}:opacity"
    let difference_id = "diff:\{alignment_id}:opacity"
    let diagnostic_ids = group_opacity_diagnostic_ids(
      report,
      before_group.subject_id,
    )
    let computed_pair = match
      (before_group.computed_opacity, after_group.computed_opacity) {
      (Some(before), Some(after)) if before_group.complete &&
        after_group.complete => Some((before, after))
      _ => None
    }
    extra_alignments.push({
      id: alignment_id,
      subject_role: "entity",
      relation: "correspondence",
      before: [
        {
          source_index: before_group.source_index,
          kind: before_group.kind,
          authored_id: Some(before_group.subject_id),
          instance_context: None,
        },
      ],
      after: [
        {
          source_index: after_group.source_index,
          kind: after_group.kind,
          authored_id: Some(after_group.subject_id),
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
    let affected_subject_ids = before_group.affected_subject_ids.copy()
    for subject_id in after_group.affected_subject_ids {
      if !affected_subject_ids.contains(subject_id) {
        affected_subject_ids.push(subject_id)
      }
    }
    let changed_fact_ids : Array[String] = []
    if declared_fact_changed(before_group.fact, after_group.fact) {
      changed_facts.push({
        id: fact_id,
        subject_id: before_group.subject_id,
        property: "opacity",
        before: before_group.fact,
        after: after_group.fact,
        affected_subject_ids,
      })
      changed_fact_ids.push(fact_id)
    }
    let dependencies = before_group.dependencies.copy()
    append_style_dependencies(dependencies, after_group.dependencies)
    for dependency in dependencies {
      if dependency.owner_id == before_group.subject_id &&
        dependency.property == "opacity" &&
        declared_fact_changed(before_group.fact, after_group.fact) {
        continue
      }
      let before_dependency = local_property_declaration(
        before_hierarchy,
        dependency.owner_id,
        dependency.property,
      )
      let after_dependency = local_property_declaration(
        after_hierarchy,
        dependency.owner_id,
        dependency.property,
      )
      if declared_fact_changed(before_dependency, after_dependency) {
        let dependency_id = "changed:source:\{dependency.owner_id}:\{dependency.property}"
        if !changed_fact_ids.contains(dependency_id) {
          changed_fact_ids.push(dependency_id)
        }
        let mut existing_index = -1
        for index, fact in changed_facts {
          if fact.id == dependency_id {
            existing_index = index
            break
          }
        }
        if existing_index >= 0 {
          let existing = changed_facts[existing_index]
          let merged_affected = existing.affected_subject_ids.copy()
          append_unique_subjects(merged_affected, affected_subject_ids)
          changed_facts[existing_index] = {
            ..existing,
            affected_subject_ids: merged_affected,
          }
        } else {
          changed_facts.push({
            id: dependency_id,
            subject_id: dependency.owner_id,
            property: dependency.property,
            before: before_dependency,
            after: after_dependency,
            affected_subject_ids,
          })
        }
      }
    }
    source_resolutions.push({
      subject_id: before_group.subject_id,
      property: "opacity",
      before: Some(before_group.resolution),
      after: Some(after_group.resolution),
    })
    let computed_relation = match computed_pair {
      Some((before, after)) =>
        {
          status: if before == after {
            "equivalent"
          } else {
            "different"
          },
          reason_code: if before == after {
            "same_resolved_group_opacity"
          } else {
            "different_resolved_group_opacity"
          },
          missing_side: None,
          diagnostic_ids: [],
        }
      None =>
        {
          status: "indeterminate",
          reason_code: group_opacity_reason_code(report, diagnostic_ids),
          missing_side: None,
          diagnostic_ids,
        }
    }
    let magnitude = match computed_pair {
      Some((before, after)) =>
        {
          ..empty_difference_magnitude(),
          parameter_abs_user_units: Some((after - before).abs()),
          parameter_signed_user_units: Some(after - before),
          symmetric_relative: Some(symmetric_relative_delta(before, after)),
        }
      None => empty_difference_magnitude()
    }
    differences.push({
      id: difference_id,
      subject_role: "entity",
      subject_alignment_id: Some(alignment_id),
      domain: "compositing.opacity",
      source_before: declared_value_or_empty(before_group.fact),
      source_after: declared_value_or_empty(after_group.fact),
      source_fact_before: before_group.fact,
      source_fact_after: after_group.fact,
      changed_fact_ids,
      evidence_layers: ["source_semantics"],
      computed_relation,
      parameter_delta_css_px: None,
      presence_magnitude: None,
      magnitude,
      domain_ordering: empty_domain_ordering(),
    })
    events.push({
      id: "event:\{alignment_id}",
      primary_subject_id: alignment_id,
      atomic_difference_ids: [difference_id],
      rendered_outcome: match computed_pair {
        Some(_) =>
          group_opacity_rendered_evidence(before_svg, after_svg, report.profile)
        None => not_computed_rendered_evidence(computed_relation.reason_code)
      },
      difference_regions: [],
    })
  }
  (
    {
      ..report,
      changed_facts,
      source_resolutions,
      atomic_differences: differences,
      events,
    },
    extra_alignments,
  )
}
