///|
priv struct GradientDifferenceGroup {
  key : String
  before_id : String?
  after_id : String?
  difference_ids : Array[String]
  changed_fact_ids : Array[String]
  affected_subject_ids : Array[String]
}

///|
fn gradient_pair_key(
  document : GradientDocument,
  gradient : GradientSource,
) -> String {
  match gradient.authored_id {
    Some(id) => id
    None => {
      let mut ordinal = 0
      for current in document.gradients {
        if current.source_index == gradient.source_index {
          break
        }
        if current.authored_id is None && current.kind == gradient.kind {
          ordinal += 1
        }
      }
      "anonymous:\{gradient.kind}:\{ordinal}"
    }
  }
}

///|
fn gradient_for_pair_key(
  document : GradientDocument,
  key : String,
) -> GradientSource? {
  for gradient in document.gradients {
    if gradient_pair_key(document, gradient) == key {
      return Some(gradient)
    }
  }
  None
}

///|
fn gradient_pair_keys(
  before : GradientDocument,
  after : GradientDocument,
) -> Array[String] {
  let keys : Array[String] = []
  for gradient in before.gradients {
    push_unique(keys, gradient_pair_key(before, gradient))
  }
  for gradient in after.gradients {
    push_unique(keys, gradient_pair_key(after, gradient))
  }
  keys.sort()
  keys
}

///|
fn gradient_fact_source(fact : DeclaredVisualFact?) -> String {
  fact.map(fact => fact.authored_value).unwrap_or("")
}

///|
fn gradient_issue_id(issue : GradientSemanticIssue) -> String {
  "diagnostic:\{issue.code}:\{issue.subject_id}"
}

///|
fn gradient_issue_ids_for_subject(
  before : GradientDocument,
  after : GradientDocument,
  subject_ids : Array[String],
) -> Array[String] {
  let ids : Array[String] = []
  for issue in before.issues + after.issues {
    if subject_ids.contains(issue.subject_id) {
      push_unique(ids, gradient_issue_id(issue))
    }
  }
  ids
}

///|
fn gradient_issue_diagnostic(
  issue : GradientSemanticIssue,
  source_role : String,
) -> Diagnostic {
  {
    id: gradient_issue_id(issue),
    code: issue.code,
    subject_id: issue.subject_id,
    affected_evidence_layers: ["computed_appearance", "rendered_evidence"],
    source_locations: match issue.fact {
      Some(fact) => [diagnostic_location(source_role, fact.source_span)]
      None => []
    },
  }
}

///|
fn append_gradient_issues(
  diagnostics : Array[Diagnostic],
  document : GradientDocument,
  source_role : String,
) -> Unit {
  for issue in document.issues {
    merge_diagnostic_into(
      diagnostics,
      gradient_issue_diagnostic(issue, source_role),
    )
  }
}

///|
fn gradient_field_by_name(
  gradient : ComputedGradient,
  name : String,
) -> ComputedGradientField? {
  for field in gradient.fields {
    if field.name == name {
      return Some(field)
    }
  }
  None
}

///|
fn gradient_field_names(
  before : ComputedGradient,
  after : ComputedGradient,
) -> Array[String] {
  let names : Array[String] = []
  for field in before.fields {
    push_unique(names, field.name)
  }
  for field in after.fields {
    push_unique(names, field.name)
  }
  names.sort()
  names
}

///|
fn gradient_component_domain(component : String) -> String {
  match component {
    "kind" => "resource.gradient.kind"
    "href" => "resource.gradient.template"
    "gradientUnits" => "resource.gradient.units"
    "spreadMethod" => "resource.gradient.spread_method"
    "gradientTransform" => "resource.gradient.transform.list"
    "effective-coordinate-matrix" =>
      "resource.gradient.transform.effective_matrix"
    "x1" | "y1" | "x2" | "y2" | "cx" | "cy" | "r" | "fx" | "fy" | "fr" =>
      "resource.gradient.geometry.\{component}"
    _ => "resource.gradient.\{component}"
  }
}

///|
fn gradient_dimensionless_magnitude(
  before : Double?,
  after : Double?,
) -> DifferenceMagnitude {
  match (before, after) {
    (Some(before), Some(after)) => {
      let delta = after - before
      {
        ..empty_difference_magnitude(),
        parameter_abs_user_units: Some(delta.abs()),
        parameter_signed_user_units: Some(delta),
        symmetric_relative: Some(symmetric_relative_delta(before, after)),
      }
    }
    _ => empty_difference_magnitude()
  }
}

///|
fn gradient_changed_fact_id(key : String, component : String) -> String {
  "fact:gradient:\{key}:\{component}"
}

///|
fn append_gradient_component_difference(
  key : String,
  subject_id : String,
  component : String,
  domain : String,
  before_source : String,
  after_source : String,
  before_fact~ : DeclaredVisualFact?,
  after_fact~ : DeclaredVisualFact?,
  dependency_fact_ids? : Array[String] = [],
  source_semantics? : Bool = true,
  emit_computed_only? : Bool = true,
  before_computed : String,
  after_computed : String,
  before_number : Double?,
  after_number : Double?,
  complete : Bool,
  diagnostic_ids : Array[String],
  changed_facts : Array[ChangedFact],
  differences : Array[AtomicDifference],
  group : GradientDifferenceGroup,
) -> Unit {
  let source_changed = source_semantics &&
    (
      declared_fact_changed(before_fact, after_fact) ||
      before_source != after_source
    )
  let computed_changed = before_computed != after_computed
  if !source_changed && (!computed_changed || !emit_computed_only) {
    return
  }
  let difference_fact_ids = dependency_fact_ids.copy()
  for id in dependency_fact_ids {
    push_unique(group.changed_fact_ids, id)
  }
  if source_changed {
    let fact_id = gradient_changed_fact_id(key, component)
    if !changed_facts.any(fact => fact.id == fact_id) {
      changed_facts.push({
        id: fact_id,
        subject_id,
        property: component,
        before: before_fact,
        after: after_fact,
        affected_subject_ids: group.affected_subject_ids,
      })
    }
    push_unique(difference_fact_ids, fact_id)
    push_unique(group.changed_fact_ids, fact_id)
  }
  let difference_id = "diff:gradient:\{key}:\{component}"
  let evidence_layers : Array[String] = []
  if source_changed {
    evidence_layers.push("source_semantics")
  }
  if computed_changed {
    evidence_layers.push("computed_appearance")
  }
  differences.push({
    id: difference_id,
    subject_role: "resource",
    subject_alignment_id: None,
    domain,
    source_before: before_source,
    source_after: after_source,
    source_fact_before: before_fact,
    source_fact_after: after_fact,
    changed_fact_ids: difference_fact_ids,
    evidence_layers,
    computed_relation: if complete {
      {
        status: if computed_changed {
          "different"
        } else {
          "equivalent"
        },
        reason_code: if computed_changed {
          "resolved_gradient_components_differ"
        } else {
          "same_resolved_gradient_component"
        },
        missing_side: None,
        diagnostic_ids: [],
      }
    } else {
      {
        status: "indeterminate",
        reason_code: "gradient_semantics_incomplete",
        missing_side: None,
        diagnostic_ids,
      }
    },
    parameter_delta_css_px: None,
    presence_magnitude: None,
    magnitude: gradient_dimensionless_magnitude(before_number, after_number),
    domain_ordering: empty_domain_ordering(),
  })
  group.difference_ids.push(difference_id)
}

///|
fn append_gradient_presence_difference(
  key : String,
  before : GradientSource?,
  after : GradientSource?,
  changed_facts : Array[ChangedFact],
  differences : Array[AtomicDifference],
  group : GradientDifferenceGroup,
) -> Unit {
  if before is Some(_) && after is Some(_) {
    return
  }
  let insertion = before is None
  let subject_id = match after {
    Some(gradient) => gradient.subject_id
    None => before.map(gradient => gradient.subject_id).unwrap_or(key)
  }
  let component = "presence"
  let fact_id = gradient_changed_fact_id(key, component)
  changed_facts.push({
    id: fact_id,
    subject_id,
    property: component,
    before: None,
    after: None,
    affected_subject_ids: group.affected_subject_ids,
  })
  group.changed_fact_ids.push(fact_id)
  let difference_id = "diff:gradient:\{key}:presence"
  differences.push({
    id: difference_id,
    subject_role: "resource",
    subject_alignment_id: None,
    domain: "resource.gradient.presence",
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
    source_fact_before: None,
    source_fact_after: None,
    changed_fact_ids: [fact_id],
    evidence_layers: ["source_semantics", "computed_appearance"],
    computed_relation: {
      status: "not_applicable",
      reason_code: if insertion {
        "before_resource_absent"
      } else {
        "after_resource_absent"
      },
      missing_side: Some(if insertion { "before" } else { "after" }),
      diagnostic_ids: [],
    },
    parameter_delta_css_px: None,
    presence_magnitude: None,
    magnitude: empty_difference_magnitude(),
    domain_ordering: empty_domain_ordering(),
  })
  group.difference_ids.push(difference_id)
}

///|
fn gradient_stop_color_signature(stop : ComputedGradientStop) -> String {
  stop.color.signature()
}

///|
fn gradient_dependency_fact_ids(
  changed_facts : Array[ChangedFact],
  subject_ids : Array[String],
) -> Array[String] {
  let ids : Array[String] = []
  for fact in changed_facts {
    if subject_ids.any(subject_id => {
        fact.subject_id == subject_id ||
        fact.affected_subject_ids.contains(subject_id)
      }) {
      push_unique(ids, fact.id)
    }
  }
  ids
}

///|
fn append_gradient_stop_dependency_facts(
  before_document : GradientDocument,
  after_document : GradientDocument,
  before_stop : ComputedGradientStop,
  after_stop : ComputedGradientStop,
  changed_facts : Array[ChangedFact],
) -> Unit {
  let dependencies = before_stop.dependencies.copy()
  append_style_dependencies(dependencies, after_stop.dependencies)
  for dependency in dependencies {
    let before_fact = local_property_declaration(
      before_document.hierarchy,
      dependency.owner_id,
      dependency.property,
    )
    let after_fact = local_property_declaration(
      after_document.hierarchy,
      dependency.owner_id,
      dependency.property,
    )
    if !declared_fact_changed(before_fact, after_fact) {
      continue
    }
    let id = "changed:source:\{dependency.owner_id}:\{dependency.property}"
    let affected_subject_ids = [before_stop.subject_id, after_stop.subject_id]
    let mut found = false
    for fact in changed_facts {
      if fact.id == id {
        for subject_id in affected_subject_ids {
          push_unique(fact.affected_subject_ids, subject_id)
        }
        found = true
      }
    }
    if !found {
      changed_facts.push({
        id,
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
fn append_gradient_stop_differences(
  key : String,
  subject_id : String,
  before : ComputedGradient,
  after : ComputedGradient,
  before_document : GradientDocument,
  after_document : GradientDocument,
  diagnostic_ids : Array[String],
  changed_facts : Array[ChangedFact],
  differences : Array[AtomicDifference],
  group : GradientDifferenceGroup,
) -> Unit {
  let count = before.stops.length().max(after.stops.length())
  for index in 0..<count {
    let before_stop = before.stops.get(index)
    let after_stop = after.stops.get(index)
    match (before_stop, after_stop) {
      (Some(before_stop), Some(after_stop)) => {
        let prefix = "stop:\{index}"
        append_gradient_stop_dependency_facts(
          before_document, after_document, before_stop, after_stop, changed_facts,
        )
        let dependency_fact_ids = gradient_dependency_fact_ids(changed_facts, [
          before_stop.subject_id,
          after_stop.subject_id,
        ])
        append_gradient_component_difference(
          key,
          subject_id,
          "\{prefix}:offset",
          "resource.gradient.stop.offset",
          gradient_fact_source(before_stop.offset_fact),
          gradient_fact_source(after_stop.offset_fact),
          before_fact=before_stop.offset_fact,
          after_fact=after_stop.offset_fact,
          before_stop.offset.to_string(),
          after_stop.offset.to_string(),
          Some(before_stop.offset),
          Some(after_stop.offset),
          before.complete &&
          after.complete &&
          before_stop.complete &&
          after_stop.complete,
          diagnostic_ids,
          changed_facts,
          differences,
          group,
        )
        append_gradient_component_difference(
          key,
          subject_id,
          "\{prefix}:color",
          "resource.gradient.stop.stop_color",
          gradient_fact_source(before_stop.color_fact),
          gradient_fact_source(after_stop.color_fact),
          before_fact=before_stop.color_fact,
          after_fact=after_stop.color_fact,
          dependency_fact_ids~,
          gradient_stop_color_signature(before_stop),
          gradient_stop_color_signature(after_stop),
          None,
          None,
          before.complete &&
          after.complete &&
          before_stop.complete &&
          after_stop.complete,
          diagnostic_ids,
          changed_facts,
          differences,
          group,
        )
        append_gradient_component_difference(
          key,
          subject_id,
          "\{prefix}:opacity",
          "resource.gradient.stop.stop_opacity",
          gradient_fact_source(before_stop.opacity_fact),
          gradient_fact_source(after_stop.opacity_fact),
          before_fact=before_stop.opacity_fact,
          after_fact=after_stop.opacity_fact,
          dependency_fact_ids~,
          before_stop.stop_opacity.to_string(),
          after_stop.stop_opacity.to_string(),
          Some(before_stop.stop_opacity),
          Some(after_stop.stop_opacity),
          before.complete &&
          after.complete &&
          before_stop.complete &&
          after_stop.complete,
          diagnostic_ids,
          changed_facts,
          differences,
          group,
        )
        let effective_source_changed = declared_fact_changed(
            before_stop.color_fact,
            after_stop.color_fact,
          ) ||
          declared_fact_changed(
            before_stop.opacity_fact,
            after_stop.opacity_fact,
          )
        if effective_source_changed ||
          before_stop.effective_alpha != after_stop.effective_alpha {
          append_gradient_component_difference(
            key,
            subject_id,
            "\{prefix}:effective-alpha",
            "resource.gradient.stop.effective_alpha",
            before_stop.effective_alpha.to_string(),
            after_stop.effective_alpha.to_string(),
            before_fact=None,
            after_fact=None,
            dependency_fact_ids=group.changed_fact_ids.copy(),
            source_semantics=false,
            before_stop.effective_alpha.to_string(),
            after_stop.effective_alpha.to_string(),
            Some(before_stop.effective_alpha),
            Some(after_stop.effective_alpha),
            before.complete &&
            after.complete &&
            before_stop.complete &&
            after_stop.complete,
            diagnostic_ids,
            changed_facts,
            differences,
            group,
          )
        }
      }
      (None, Some(stop)) | (Some(stop), None) => {
        let insertion = before_stop is None
        let component = "stop:\{index}:presence"
        append_gradient_component_difference(
          key,
          subject_id,
          component,
          "resource.gradient.stop.presence",
          if insertion {
            ""
          } else {
            stop.signature()
          },
          if insertion {
            stop.signature()
          } else {
            ""
          },
          before_fact=None,
          after_fact=None,
          if insertion {
            "absent"
          } else {
            "present"
          },
          if insertion {
            "present"
          } else {
            "absent"
          },
          None,
          None,
          before.complete && after.complete && stop.complete,
          diagnostic_ids,
          changed_facts,
          differences,
          group,
        )
      }
      _ => ()
    }
  }
}

///|
fn append_gradient_resource_pair(
  key : String,
  before_source : GradientSource?,
  after_source : GradientSource?,
  before_document : GradientDocument,
  after_document : GradientDocument,
  changed_facts : Array[ChangedFact],
  differences : Array[AtomicDifference],
) -> GradientDifferenceGroup {
  let group : GradientDifferenceGroup = {
    key,
    before_id: before_source.bind(gradient => gradient.authored_id),
    after_id: after_source.bind(gradient => gradient.authored_id),
    difference_ids: [],
    changed_fact_ids: [],
    affected_subject_ids: [],
  }
  append_gradient_presence_difference(
    key, before_source, after_source, changed_facts, differences, group,
  )
  guard (before_source, after_source)
    is (Some(before_source), Some(after_source)) else {
    return group
  }
  let before = resolve_computed_gradient(before_document, before_source, None)
  let after = resolve_computed_gradient(after_document, after_source, None)
  let subject_id = after_source.subject_id
  let diagnostic_ids = gradient_issue_ids_for_subject(
    before_document,
    after_document,
    before.template_chain + after.template_chain,
  )
  append_gradient_component_difference(
    key,
    subject_id,
    "kind",
    gradient_component_domain("kind"),
    before_source.kind,
    after_source.kind,
    before_fact=None,
    after_fact=None,
    before.kind,
    after.kind,
    None,
    None,
    before.complete && after.complete,
    diagnostic_ids,
    changed_facts,
    differences,
    group,
  )
  append_gradient_component_difference(
    key,
    subject_id,
    "href",
    gradient_component_domain("href"),
    gradient_fact_source(before_source.href_fact),
    gradient_fact_source(after_source.href_fact),
    before_fact=before_source.href_fact,
    after_fact=after_source.href_fact,
    emit_computed_only=false,
    before.signature(),
    after.signature(),
    None,
    None,
    before.complete && after.complete,
    diagnostic_ids,
    changed_facts,
    differences,
    group,
  )
  for name in gradient_field_names(before, after) {
    let before_field = gradient_field_by_name(before, name)
    let after_field = gradient_field_by_name(after, name)
    append_gradient_component_difference(
      key,
      subject_id,
      name,
      gradient_component_domain(name),
      before_field.map(field => gradient_fact_source(field.fact)).unwrap_or(""),
      after_field.map(field => gradient_fact_source(field.fact)).unwrap_or(""),
      before_fact=before_field.bind(field => field.fact),
      after_fact=after_field.bind(field => field.fact),
      before_field.map(field => field.value).unwrap_or("absent"),
      after_field.map(field => field.value).unwrap_or("absent"),
      before_field.bind(field => field.number),
      after_field.bind(field => field.number),
      before.complete &&
      after.complete &&
      before_field.map(field => field.complete).unwrap_or(true) &&
      after_field.map(field => field.complete).unwrap_or(true),
      diagnostic_ids,
      changed_facts,
      differences,
      group,
    )
  }
  append_gradient_component_difference(
    key,
    subject_id,
    "effective-coordinate-matrix",
    gradient_component_domain("effective-coordinate-matrix"),
    before.coordinate_transform.signature(),
    after.coordinate_transform.signature(),
    before_fact=None,
    after_fact=None,
    dependency_fact_ids=group.changed_fact_ids.copy(),
    source_semantics=false,
    before.coordinate_transform.signature(),
    after.coordinate_transform.signature(),
    None,
    None,
    before.complete && after.complete,
    diagnostic_ids,
    changed_facts,
    differences,
    group,
  )
  append_gradient_stop_differences(
    key, subject_id, before, after, before_document, after_document, diagnostic_ids,
    changed_facts, differences, group,
  )
  group
}

///|
fn gradient_subject_for_reference(
  subjects : Array[SourceSubject],
  reference : SubjectReference,
) -> SourceSubject? {
  for subject in subjects {
    if subject.reference.source_index == reference.source_index &&
      subject.reference.kind == reference.kind {
      return Some(subject)
    }
  }
  None
}

///|
fn gradient_subject_id(subject : SourceSubject) -> String {
  subject.reference.authored_id.unwrap_or(
    "\{subject.reference.kind}:\{subject.reference.source_index}",
  )
}

///|
fn gradient_group_for_id(
  groups : Array[GradientDifferenceGroup],
  id : String,
) -> GradientDifferenceGroup? {
  for group in groups {
    if group.before_id == Some(id) || group.after_id == Some(id) {
      return Some(group)
    }
  }
  None
}

///|
fn gradient_rendered_evidence(
  report : StructuredReport,
  before_svg : String,
  after_svg : String,
) -> RenderedEvidence {
  for event in report.events {
    if event.rendered_outcome.status == "computed" {
      return event.rendered_outcome
    }
  }
  match
    (
      @svg.parse_svg_document(
        normalize_renderer_input_with_profile(before_svg, report.profile),
      ),
      @svg.parse_svg_document(
        normalize_renderer_input_with_profile(after_svg, report.profile),
      ),
    ) {
    (Some(before), Some(after)) =>
      computed_rendered_evidence(
        rendered_difference(before, after, report.profile),
      )
    _ => not_computed_rendered_evidence("gradient_renderer_unavailable")
  }
}

///|
fn event_index_for_alignment(
  events : Array[VisualEvent],
  alignment : SubjectAlignment,
) -> Int? {
  for index, event in events {
    if event.primary_subject_id == alignment.id ||
      alignment.before.any(reference => {
        reference.authored_id == Some(event.primary_subject_id)
      }) ||
      alignment.after.any(reference => {
        reference.authored_id == Some(event.primary_subject_id)
      }) {
      return Some(index)
    }
  }
  None
}

///|
fn difference_index_for_alignment_domain(
  differences : Array[AtomicDifference],
  alignment_id : String,
  domain : String,
) -> Int? {
  for index, difference in differences {
    if difference.subject_alignment_id == Some(alignment_id) &&
      difference.domain == domain {
      return Some(index)
    }
  }
  None
}

///|
fn append_gradient_entity_differences(
  report : StructuredReport,
  before_svg : String,
  after_svg : String,
  before_document : GradientDocument,
  after_document : GradientDocument,
  groups : Array[GradientDifferenceGroup],
  changed_facts : Array[ChangedFact],
  differences : Array[AtomicDifference],
  events : Array[VisualEvent],
) -> Unit {
  let before_subjects = extract_source_subjects_with_profile_or_raise(
    before_svg,
    report.profile,
  ) catch {
    _ => return
  }
  let after_subjects = extract_source_subjects_with_profile_or_raise(
    after_svg,
    report.profile,
  ) catch {
    _ => return
  }
  let rendered = gradient_rendered_evidence(report, before_svg, after_svg)
  for alignment in report.subject_alignments {
    guard alignment.before is [before_reference] &&
      alignment.after is [after_reference] else {
      continue
    }
    guard gradient_subject_for_reference(before_subjects, before_reference)
      is Some(before_subject) else {
      continue
    }
    guard gradient_subject_for_reference(after_subjects, after_reference)
      is Some(after_subject) else {
      continue
    }
    for property in ["fill", "stroke"] {
      let before_value = subject_value(before_subject, property).unwrap_or("")
      let after_value = subject_value(after_subject, property).unwrap_or("")
      guard paint_server_reference(before_value) is Some(before_id) else {
        continue
      }
      guard paint_server_reference(after_value) is Some(after_id) else {
        continue
      }
      guard resolve_gradient_by_id(
          before_document,
          before_id,
          Some(before_subject),
        )
        is GradientResolved(before_gradient) else {
        continue
      }
      guard resolve_gradient_by_id(
          after_document,
          after_id,
          Some(after_subject),
        )
        is GradientResolved(after_gradient) else {
        continue
      }
      let before_group = gradient_group_for_id(groups, before_id)
      let after_group = gradient_group_for_id(groups, after_id)
      let resource_difference_ids : Array[String] = []
      let resource_fact_ids : Array[String] = []
      for group in groups {
        if before_group.map(value => value.key) == Some(group.key) ||
          after_group.map(value => value.key) == Some(group.key) {
          for id in group.difference_ids {
            push_unique(resource_difference_ids, id)
          }
          for id in group.changed_fact_ids {
            push_unique(resource_fact_ids, id)
          }
          let entity_id = gradient_subject_id(after_subject)
          push_unique(group.affected_subject_ids, entity_id)
          for fact in changed_facts {
            if group.changed_fact_ids.contains(fact.id) {
              push_unique(fact.affected_subject_ids, entity_id)
            }
          }
        }
      }
      let before_signature = before_gradient.signature()
      let after_signature = after_gradient.signature()
      let source_fact_before = source_subject_fact(before_subject, property)
      let source_fact_after = source_subject_fact(after_subject, property)
      let source_changed = declared_fact_changed(
        source_fact_before, source_fact_after,
      )
      if !source_changed &&
        before_signature == after_signature &&
        resource_difference_ids.is_empty() {
        continue
      }
      let diagnostic_ids = gradient_issue_ids_for_subject(
        before_document,
        after_document,
        before_gradient.template_chain + after_gradient.template_chain,
      )
      let complete = before_gradient.complete && after_gradient.complete
      let relation : ComputedRelation = if complete {
        {
          status: if before_signature == after_signature {
            "equivalent"
          } else {
            "different"
          },
          reason_code: if before_signature == after_signature {
            "same_resolved_gradient_paint"
          } else {
            "resolved_gradient_paints_differ"
          },
          missing_side: None,
          diagnostic_ids: [],
        }
      } else {
        {
          status: "indeterminate",
          reason_code: "gradient_semantics_incomplete",
          missing_side: None,
          diagnostic_ids,
        }
      }
      let domain = if property == "fill" {
        "paint.fill"
      } else {
        "paint.stroke"
      }
      let existing_index = difference_index_for_alignment_domain(
        differences,
        alignment.id,
        domain,
      )
      let difference_id = existing_index
        .map(index => differences[index].id)
        .unwrap_or("diff:\{alignment.id}:\{property}:gradient")
      let changed_fact_ids = resource_fact_ids.copy()
      match existing_index {
        Some(index) =>
          for id in differences[index].changed_fact_ids {
            push_unique(changed_fact_ids, id)
          }
        None => ()
      }
      let entity_id = gradient_subject_id(after_subject)
      for fact in changed_facts {
        if fact.subject_id == entity_id ||
          fact.affected_subject_ids.contains(entity_id) {
          push_unique(changed_fact_ids, fact.id)
        }
      }
      let evidence_layers : Array[String] = []
      if source_changed {
        evidence_layers.push("source_semantics")
      }
      if relation.status == "different" {
        evidence_layers.push("computed_appearance")
      }
      if rendered.status == "computed" {
        evidence_layers.push("rendered_evidence")
      }
      let difference : AtomicDifference = {
        id: difference_id,
        subject_role: "entity",
        subject_alignment_id: Some(alignment.id),
        domain,
        source_before: gradient_fact_source(source_fact_before),
        source_after: gradient_fact_source(source_fact_after),
        source_fact_before,
        source_fact_after,
        changed_fact_ids,
        evidence_layers,
        computed_relation: relation,
        parameter_delta_css_px: None,
        presence_magnitude: None,
        magnitude: empty_difference_magnitude(),
        domain_ordering: empty_domain_ordering(),
      }
      match existing_index {
        Some(index) => differences[index] = difference
        None => differences.push(difference)
      }
      let event_difference_ids = resource_difference_ids.copy()
      event_difference_ids.push(difference_id)
      match event_index_for_alignment(events, alignment) {
        Some(index) =>
          for id in event_difference_ids {
            push_unique(events[index].atomic_difference_ids, id)
          }
        None =>
          events.push({
            id: "event:\{alignment.id}:\{property}:gradient",
            primary_subject_id: gradient_subject_id(after_subject),
            atomic_difference_ids: event_difference_ids,
            rendered_outcome: rendered,
            difference_regions: [],
          })
      }
    }
  }
}

///|
fn append_unreferenced_gradient_events(
  groups : Array[GradientDifferenceGroup],
  events : Array[VisualEvent],
  rendered : RenderedEvidence,
) -> Unit {
  let attached : Array[String] = []
  for event in events {
    for id in event.atomic_difference_ids {
      push_unique(attached, id)
    }
  }
  for group in groups {
    let remaining = [
      for id in group.difference_ids if !attached.contains(id) => id
    ]
    if !remaining.is_empty() {
      events.push({
        id: "event:gradient:\{group.key}",
        primary_subject_id: match group.after_id {
          Some(id) => id
          None => group.before_id.unwrap_or(group.key)
        },
        atomic_difference_ids: remaining,
        rendered_outcome: rendered,
        difference_regions: [],
      })
    }
  }
}

///|
fn attach_gradient_differences(
  report : StructuredReport,
  before_svg : String,
  after_svg : String,
) -> StructuredReport {
  guard extract_gradient_document(before_svg, report.profile)
    is Some(before_document) else {
    return report
  }
  guard extract_gradient_document(after_svg, report.profile)
    is Some(after_document) else {
    return report
  }
  if before_document.gradients.is_empty() && after_document.gradients.is_empty() {
    return report
  }
  let changed_facts = report.changed_facts.copy()
  let differences = [
    for difference in report.atomic_differences if !difference.id.has_prefix(
      "diff:resource:gradient:",
    ) => difference
  ]
  let events : Array[VisualEvent] = []
  for event in report.events {
    let ids = [
      for id in event.atomic_difference_ids if !id.has_prefix(
        "diff:resource:gradient:",
      ) => id
    ]
    if !ids.is_empty() {
      events.push({ ..event, atomic_difference_ids: ids })
    }
  }
  let groups : Array[GradientDifferenceGroup] = []
  for key in gradient_pair_keys(before_document, after_document) {
    groups.push(
      append_gradient_resource_pair(
        key,
        gradient_for_pair_key(before_document, key),
        gradient_for_pair_key(after_document, key),
        before_document,
        after_document,
        changed_facts,
        differences,
      ),
    )
  }
  append_gradient_entity_differences(
    report, before_svg, after_svg, before_document, after_document, groups, changed_facts,
    differences, events,
  )
  let rendered = gradient_rendered_evidence(report, before_svg, after_svg)
  append_unreferenced_gradient_events(groups, events, rendered)
  let diagnostics = [
    for diagnostic in report.diagnostics if diagnostic.code !=
    "analysis_coverage_unproven" => diagnostic
  ]
  append_gradient_issues(diagnostics, before_document, "before")
  append_gradient_issues(diagnostics, after_document, "after")
  {
    ..report,
    analysis_status: if diagnostics.is_empty() {
      "complete"
    } else {
      "partial"
    },
    changed_facts,
    atomic_differences: differences,
    events,
    diagnostics,
  }
}
