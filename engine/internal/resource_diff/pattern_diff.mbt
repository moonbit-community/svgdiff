///|
priv struct PatternDifferenceGroup {
  key : String
  before_id : String?
  after_id : String?
  difference_ids : Array[String]
  changed_fact_ids : Array[String]
  affected_subject_ids : Array[String]
}

///|
fn pattern_pair_keys(
  before : Array[PatternSource],
  after : Array[PatternSource],
) -> Array[String] {
  let keys : Array[String] = []
  for pattern in before {
    match pattern.authored_id {
      Some(id) => push_unique(keys, "id:\{id}")
      None => ()
    }
  }
  for pattern in after {
    match pattern.authored_id {
      Some(id) => push_unique(keys, "id:\{id}")
      None => ()
    }
  }
  let anonymous = before
    .filter(pattern => pattern.authored_id is None)
    .length()
    .max(after.filter(pattern => pattern.authored_id is None).length())
  for index = 0; index < anonymous; index = index + 1 {
    keys.push("anonymous:\{index}")
  }
  keys
}

///|
fn pattern_for_key(
  patterns : Array[PatternSource],
  key : String,
) -> PatternSource? {
  if key.has_prefix("id:") {
    let id = key.view(start_offset=3).to_owned()
    for pattern in patterns {
      if pattern.authored_id == Some(id) {
        return Some(pattern)
      }
    }
    return None
  }
  let index = parse_alignment_number(Some(key.view(start_offset=10).to_owned()))
    .map(number => number.to_int())
    .unwrap_or(-1)
  let anonymous = patterns.filter(pattern => pattern.authored_id is None)
  anonymous.get(index)
}

///|
fn pattern_issue_id(issue : PatternSemanticIssue) -> String {
  let code = issue.code.replace_all(old="_", new="-")
  "diagnostic:\{code}:\{issue.subject_id}"
}

///|
fn append_pattern_issues(
  diagnostics : Array[Diagnostic],
  document : PatternDocument,
  source_role : String,
) -> Unit {
  for issue in document.issues {
    let locations = match issue.fact {
      Some(fact) => [diagnostic_location(source_role, fact.source_span)]
      None => []
    }
    merge_diagnostic_into(diagnostics, {
      id: pattern_issue_id(issue),
      code: issue.code,
      subject_id: issue.subject_id,
      affected_evidence_layers: ["computed_appearance", "rendered_evidence"],
      source_locations: locations,
    })
  }
}

///|
fn pattern_issue_ids(
  before : PatternDocument,
  after : PatternDocument,
  subjects : Array[String],
) -> Array[String] {
  let ids : Array[String] = []
  for issue in before.issues + after.issues {
    if subjects.contains(issue.subject_id) {
      push_unique(ids, pattern_issue_id(issue))
    }
  }
  ids
}

///|
fn pattern_field_by_name(
  pattern : ComputedPattern,
  name : String,
) -> ComputedPatternField? {
  for field in pattern.fields {
    if field.name == name {
      return Some(field)
    }
  }
  None
}

///|
fn pattern_field_names(
  before : ComputedPattern,
  after : ComputedPattern,
) -> Array[String] {
  let names : Array[String] = []
  for field in before.fields + after.fields {
    push_unique(names, field.name)
  }
  names
}

///|
fn pattern_domain(component : String) -> String {
  if component.has_prefix("child:") {
    if component.find(":transform:") is Some(_) {
      return "resource.pattern.child.transform"
    }
    let mut child_component = "content"
    for part in component.split(":") {
      child_component = part.to_owned()
    }
    return "resource.pattern.child.\{child_component.replace_all(old="-", new="_")}"
  }
  match component {
    "patternUnits" => "resource.pattern.units"
    "patternContentUnits" => "resource.pattern.content_units"
    "patternTransform" => "resource.pattern.transform.list"
    "tile-matrix" => "resource.pattern.transform.tile_matrix"
    "content-matrix" => "resource.pattern.transform.content_matrix"
    "viewBox" => "resource.pattern.viewport.view_box"
    "preserveAspectRatio" => "resource.pattern.viewport.preserve_aspect_ratio"
    "overflow" => "resource.pattern.viewport.overflow"
    "content" => "resource.pattern.content"
    "content-order" => "resource.pattern.content_order"
    "href" => "resource.pattern.reference"
    "presence" => "resource.pattern.presence"
    _ => "resource.pattern.geometry.\{component}"
  }
}

///|
fn pattern_fact_source(fact : DeclaredVisualFact?) -> String {
  fact.map(fact => fact.declared_value).unwrap_or("")
}

///|
fn append_pattern_component_difference(
  key : String,
  subject_id : String,
  component : String,
  before_source : String,
  after_source : String,
  before_fact : DeclaredVisualFact?,
  after_fact : DeclaredVisualFact?,
  before_computed : String,
  after_computed : String,
  before_number : Double?,
  after_number : Double?,
  complete : Bool,
  diagnostic_ids : Array[String],
  changed_facts : Array[ChangedFact],
  differences : Array[AtomicDifference],
  group : PatternDifferenceGroup,
) -> Unit {
  let source_changed = declared_fact_changed(before_fact, after_fact) ||
    before_source != after_source
  let computed_changed = before_computed != after_computed
  if !source_changed && !computed_changed {
    return
  }
  let fact_ids : Array[String] = []
  if source_changed {
    let fact_id = "fact:pattern:\{key}:\{component}"
    changed_facts.push({
      id: fact_id,
      subject_id,
      property: component,
      before: before_fact,
      after: after_fact,
      affected_subject_ids: group.affected_subject_ids,
    })
    fact_ids.push(fact_id)
    group.changed_fact_ids.push(fact_id)
  } else {
    fact_ids.push_iter(group.changed_fact_ids.iter())
  }
  let magnitude = match (before_number, after_number) {
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
  let id = "diff:pattern:\{key}:\{component}"
  differences.push({
    id,
    subject_role: "resource",
    subject_alignment_id: None,
    domain: pattern_domain(component),
    source_before: before_source,
    source_after: after_source,
    source_fact_before: before_fact,
    source_fact_after: after_fact,
    changed_fact_ids: fact_ids,
    evidence_layers: (if source_changed { ["source_semantics"] } else { [] }) +
    (if computed_changed { ["computed_appearance"] } else { [] }),
    computed_relation: if complete {
      {
        status: if computed_changed {
          "different"
        } else {
          "equivalent"
        },
        reason_code: if computed_changed {
          "resolved_pattern_components_differ"
        } else {
          "same_resolved_pattern_component"
        },
        missing_side: None,
        diagnostic_ids: [],
      }
    } else {
      {
        status: "indeterminate",
        reason_code: "pattern_semantics_incomplete",
        missing_side: None,
        diagnostic_ids,
      }
    },
    parameter_delta_css_px: None,
    presence_magnitude: None,
    magnitude,
    domain_ordering: empty_domain_ordering(),
  })
  group.difference_ids.push(id)
}

///|
fn computed_pattern_child_for_key(
  pattern : ComputedPattern,
  key : String,
) -> ComputedPatternChild? {
  for child in pattern.children {
    if child.subject_id == key {
      return Some(child)
    }
  }
  None
}

///|
fn pattern_child_order_signature(pattern : ComputedPattern) -> String {
  let mut result = ""
  for child in pattern.children {
    if result != "" {
      result += ","
    }
    result += child.subject_id
  }
  result
}

///|
fn pattern_child_transform_for_key(
  child : ComputedPatternChild,
  key : String,
) -> ComputedPatternChildTransform? {
  for transform in child.transforms {
    if transform.key == key {
      return Some(transform)
    }
  }
  None
}

///|
fn append_pattern_child_differences(
  key : String,
  subject_id : String,
  before : ComputedPattern,
  after : ComputedPattern,
  diagnostic_ids : Array[String],
  changed_facts : Array[ChangedFact],
  differences : Array[AtomicDifference],
  group : PatternDifferenceGroup,
) -> Unit {
  let child_keys : Array[String] = []
  for child in before.children + after.children {
    push_unique(child_keys, child.subject_id)
  }
  for child_key in child_keys {
    let before_child = computed_pattern_child_for_key(before, child_key)
    let after_child = computed_pattern_child_for_key(after, child_key)
    match (before_child, after_child) {
      (Some(before_child), Some(after_child)) => {
        let properties : Array[String] = []
        for fact in before_child.facts + after_child.facts {
          push_unique(properties, fact.property)
        }
        for property in properties {
          if property == "transform" {
            continue
          }
          let before_fact = declared_fact_in_array(before_child.facts, property)
          let after_fact = declared_fact_in_array(after_child.facts, property)
          let before_computed = declared_fact_in_array(
            before_child.computed_facts,
            property,
          )
          let after_computed = declared_fact_in_array(
            after_child.computed_facts,
            property,
          )
          append_pattern_component_difference(
            key,
            subject_id,
            "child:\{child_key}:\{property}",
            pattern_fact_source(before_fact),
            pattern_fact_source(after_fact),
            before_fact,
            after_fact,
            pattern_fact_source(before_computed),
            pattern_fact_source(after_computed),
            None,
            None,
            before.complete &&
            after.complete &&
            before_child.complete &&
            after_child.complete,
            diagnostic_ids,
            changed_facts,
            differences,
            group,
          )
        }
        let transform_keys : Array[String] = []
        for transform in before_child.transforms + after_child.transforms {
          push_unique(transform_keys, transform.key)
        }
        for transform_key in transform_keys {
          let before_transform = pattern_child_transform_for_key(
            before_child, transform_key,
          )
          let after_transform = pattern_child_transform_for_key(
            after_child, transform_key,
          )
          append_pattern_component_difference(
            key,
            subject_id,
            "child:\{child_key}:transform:\{transform_key}",
            before_transform
            .map(value => value.fact.declared_value)
            .unwrap_or(""),
            after_transform
            .map(value => value.fact.declared_value)
            .unwrap_or(""),
            before_transform.map(value => value.fact),
            after_transform.map(value => value.fact),
            before_transform.map(value => value.computed).unwrap_or("absent"),
            after_transform.map(value => value.computed).unwrap_or("absent"),
            None,
            None,
            before.complete &&
            after.complete &&
            before_child.complete &&
            after_child.complete,
            diagnostic_ids,
            changed_facts,
            differences,
            group,
          )
        }
        append_pattern_component_difference(
          key,
          subject_id,
          "child:\{child_key}:computed_signature",
          before_child.kind,
          after_child.kind,
          None,
          None,
          before_child.signature,
          after_child.signature,
          None,
          None,
          before.complete &&
          after.complete &&
          before_child.complete &&
          after_child.complete,
          diagnostic_ids,
          changed_facts,
          differences,
          group,
        )
      }
      _ =>
        append_pattern_component_difference(
          key,
          subject_id,
          "child:\{child_key}:presence",
          before_child.map(child => child.kind).unwrap_or(""),
          after_child.map(child => child.kind).unwrap_or(""),
          None,
          None,
          before_child.map(child => child.signature).unwrap_or("absent"),
          after_child.map(child => child.signature).unwrap_or("absent"),
          None,
          None,
          before.complete && after.complete,
          diagnostic_ids,
          changed_facts,
          differences,
          group,
        )
    }
  }
}

///|
fn append_pattern_resource_pair(
  key : String,
  before_source : PatternSource?,
  after_source : PatternSource?,
  before_document : PatternDocument,
  after_document : PatternDocument,
  group : PatternDifferenceGroup,
  changed_facts : Array[ChangedFact],
  differences : Array[AtomicDifference],
) -> Unit {
  guard (before_source, after_source)
    is (Some(before_source), Some(after_source)) else {
    let insertion = before_source is None
    let id = "diff:pattern:\{key}:presence"
    let fact_id = "fact:pattern:\{key}:presence"
    let subject_id = after_source
      .map(pattern => pattern.subject_id)
      .unwrap_or(
        before_source.map(pattern => pattern.subject_id).unwrap_or(key),
      )
    changed_facts.push({
      id: fact_id,
      subject_id,
      property: "presence",
      before: None,
      after: None,
      affected_subject_ids: group.affected_subject_ids,
    })
    group.changed_fact_ids.push(fact_id)
    group.difference_ids.push(id)
    differences.push({
      id,
      subject_role: "resource",
      subject_alignment_id: None,
      domain: pattern_domain("presence"),
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
    return
  }
  let before = resolve_computed_pattern(before_document, before_source, None)
  let after = resolve_computed_pattern(after_document, after_source, None)
  let chain = before.template_chain + after.template_chain
  let diagnostic_ids = pattern_issue_ids(before_document, after_document, chain)
  for name in pattern_field_names(before, after) {
    let before_field = pattern_field_by_name(before, name)
    let after_field = pattern_field_by_name(after, name)
    append_pattern_component_difference(
      key,
      after_source.subject_id,
      name,
      before_field.map(field => pattern_fact_source(field.fact)).unwrap_or(""),
      after_field.map(field => pattern_fact_source(field.fact)).unwrap_or(""),
      before_field.bind(field => field.fact),
      after_field.bind(field => field.fact),
      before_field.map(field => field.value).unwrap_or("absent"),
      after_field.map(field => field.value).unwrap_or("absent"),
      before_field.bind(field => field.number),
      after_field.bind(field => field.number),
      before.complete && after.complete,
      diagnostic_ids,
      changed_facts,
      differences,
      group,
    )
  }
  for
    component_and_values in [
      (
        "href",
        pattern_fact_source(before_source.href_fact),
        pattern_fact_source(after_source.href_fact),
        before_source.href_fact,
        after_source.href_fact,
      ),
      (
        "tile-matrix",
        before.tile_matrix.signature(),
        after.tile_matrix.signature(),
        None,
        None,
      ),
      (
        "content-matrix",
        before.content_matrix.signature(),
        after.content_matrix.signature(),
        None,
        None,
      ),
      (
        "content-order",
        pattern_child_order_signature(before),
        pattern_child_order_signature(after),
        None,
        None,
      ),
    ] {
    let (component, before_value, after_value, before_fact, after_fact) = component_and_values
    append_pattern_component_difference(
      key,
      after_source.subject_id,
      component,
      before_value,
      after_value,
      before_fact,
      after_fact,
      before_value,
      after_value,
      None,
      None,
      before.complete && after.complete,
      diagnostic_ids,
      changed_facts,
      differences,
      group,
    )
  }
  append_pattern_child_differences(
    key,
    after_source.subject_id,
    before,
    after,
    diagnostic_ids,
    changed_facts,
    differences,
    group,
  )
}

///|
fn pattern_group_for_id(
  groups : Array[PatternDifferenceGroup],
  id : String,
) -> PatternDifferenceGroup? {
  for group in groups {
    if group.before_id == Some(id) || group.after_id == Some(id) {
      return Some(group)
    }
  }
  None
}

///|
fn pattern_subject_for_reference(
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
fn pattern_subject_id(subject : SourceSubject) -> String {
  subject.reference.authored_id.unwrap_or(
    "\{subject.reference.kind}:\{subject.reference.source_index}",
  )
}

///|
fn populate_pattern_consumers(
  groups : Array[PatternDifferenceGroup],
  before_svg : String,
  after_svg : String,
  profile : ComparisonProfile,
) -> Unit {
  for source in [before_svg, after_svg] {
    let subjects = extract_source_subjects_with_profile_or_raise(
      source, profile,
    ) catch {
      _ => continue
    }
    for subject in subjects {
      for property in ["fill", "stroke"] {
        match
          paint_server_reference(subject_value(subject, property).unwrap_or("")) {
          Some(id) =>
            match pattern_group_for_id(groups, id) {
              Some(group) =>
                push_unique(
                  group.affected_subject_ids,
                  pattern_subject_id(subject),
                )
              None => ()
            }
          None => ()
        }
      }
    }
  }
}

///|
fn append_pattern_entity_differences(
  report : StructuredReport,
  before_svg : String,
  after_svg : String,
  before_document : PatternDocument,
  after_document : PatternDocument,
  groups : Array[PatternDifferenceGroup],
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
    guard pattern_subject_for_reference(before_subjects, before_reference)
      is Some(before_subject) else {
      continue
    }
    guard pattern_subject_for_reference(after_subjects, after_reference)
      is Some(after_subject) else {
      continue
    }
    for property in ["fill", "stroke"] {
      let before_fact = source_subject_fact(before_subject, property)
      let after_fact = source_subject_fact(after_subject, property)
      guard authored_paint_server_reference(before_subject, property)
        is Some(before_id) else {
        continue
      }
      guard authored_paint_server_reference(after_subject, property)
        is Some(after_id) else {
        continue
      }
      let before_pattern = match
        paint_server_reference(
          subject_value(before_subject, property).unwrap_or(""),
        ) {
        Some(active_id) if active_id == before_id =>
          match
            resolve_pattern_by_id(
              before_document,
              before_id,
              Some(before_subject),
            ) {
            PatternResolved(pattern) => Some(pattern)
            PatternUnavailable => None
          }
        _ => None
      }
      let after_pattern = match
        paint_server_reference(
          subject_value(after_subject, property).unwrap_or(""),
        ) {
        Some(active_id) if active_id == after_id =>
          match
            resolve_pattern_by_id(after_document, after_id, Some(after_subject)) {
            PatternResolved(pattern) => Some(pattern)
            PatternUnavailable => None
          }
        _ => None
      }
      if before_pattern is None && after_pattern is None {
        continue
      }
      let before_group = pattern_group_for_id(groups, before_id)
      let after_group = pattern_group_for_id(groups, after_id)
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
        }
      }
      let before_signature = before_pattern
        .map(pattern => pattern.signature())
        .unwrap_or(
          generic_effective_paint(before_subject, property, before_fact).unwrap_or(
            "none",
          ),
        )
      let after_signature = after_pattern
        .map(pattern => pattern.signature())
        .unwrap_or(
          generic_effective_paint(after_subject, property, after_fact).unwrap_or(
            "none",
          ),
        )
      let changed_fact_ids = resource_fact_ids.copy()
      if declared_fact_changed(before_fact, after_fact) {
        let consumer_property = if property == "fill" {
          "paint.fill"
        } else {
          "paint.stroke"
        }
        let mut existing_fact_id : String? = None
        for fact in changed_facts {
          if fact.subject_id == pattern_subject_id(after_subject) &&
            fact.property == consumer_property &&
            fact.before.map(value => value.declared_value) ==
            before_fact.map(value => value.declared_value) &&
            fact.after.map(value => value.declared_value) ==
            after_fact.map(value => value.declared_value) {
            existing_fact_id = Some(fact.id)
            break
          }
        }
        let fact_id = existing_fact_id.unwrap_or(
          "fact:pattern-consumer:\{alignment.id}:\{property}",
        )
        if existing_fact_id is None {
          changed_facts.push({
            id: fact_id,
            subject_id: pattern_subject_id(after_subject),
            property: consumer_property,
            before: before_fact,
            after: after_fact,
            affected_subject_ids: [pattern_subject_id(after_subject)],
          })
        }
        push_unique(changed_fact_ids, fact_id)
      }
      if before_signature == after_signature &&
        !declared_fact_changed(before_fact, after_fact) &&
        resource_difference_ids.is_empty() {
        continue
      }
      let domain = if property == "fill" {
        "paint.fill"
      } else {
        "paint.stroke"
      }
      let existing = difference_index_for_alignment_domain(
        differences,
        alignment.id,
        domain,
      )
      let difference_id = existing
        .map(index => differences[index].id)
        .unwrap_or("diff:\{alignment.id}:\{property}:pattern")
      let chain = before_pattern
        .map(pattern => pattern.template_chain)
        .unwrap_or([]) +
        after_pattern.map(pattern => pattern.template_chain).unwrap_or([])
      let diagnostic_ids = pattern_issue_ids(
        before_document, after_document, chain,
      )
      let complete = before_pattern
        .map(pattern => pattern.complete)
        .unwrap_or(true) &&
        after_pattern.map(pattern => pattern.complete).unwrap_or(true)
      let evidence_layers : Array[String] = []
      if declared_fact_changed(before_fact, after_fact) {
        evidence_layers.push("source_semantics")
      }
      if complete && before_signature != after_signature {
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
        source_before: pattern_fact_source(before_fact),
        source_after: pattern_fact_source(after_fact),
        source_fact_before: before_fact,
        source_fact_after: after_fact,
        changed_fact_ids,
        evidence_layers,
        computed_relation: if complete {
          {
            status: if before_signature == after_signature {
              "equivalent"
            } else {
              "different"
            },
            reason_code: if before_signature == after_signature {
              "same_resolved_pattern_paint"
            } else {
              "resolved_pattern_paints_differ"
            },
            missing_side: None,
            diagnostic_ids: [],
          }
        } else {
          {
            status: "indeterminate",
            reason_code: "pattern_semantics_incomplete",
            missing_side: None,
            diagnostic_ids,
          }
        },
        parameter_delta_css_px: None,
        presence_magnitude: None,
        magnitude: empty_difference_magnitude(),
        domain_ordering: empty_domain_ordering(),
      }
      match existing {
        Some(index) => differences[index] = difference
        None => differences.push(difference)
      }
      let event_ids = resource_difference_ids.copy()
      event_ids.push(difference_id)
      match event_index_for_alignment(events, alignment) {
        Some(index) =>
          for id in event_ids {
            push_unique(events[index].atomic_difference_ids, id)
          }
        None =>
          events.push({
            id: "event:\{alignment.id}:\{property}:pattern",
            primary_subject_id: pattern_subject_id(after_subject),
            atomic_difference_ids: event_ids,
            rendered_outcome: rendered,
            difference_regions: [],
          })
      }
    }
  }
}

///|
pub fn attach_pattern_differences(
  report : StructuredReport,
  before_svg : String,
  after_svg : String,
) -> StructuredReport {
  guard extract_pattern_document(before_svg, report.profile)
    is Some(before_document) else {
    return report
  }
  guard extract_pattern_document(after_svg, report.profile)
    is Some(after_document) else {
    return report
  }
  if before_document.patterns.is_empty() && after_document.patterns.is_empty() {
    return report
  }
  let diagnostics = report.diagnostics.copy()
  append_pattern_issues(diagnostics, before_document, "before")
  append_pattern_issues(diagnostics, after_document, "after")
  let changed_facts = report.changed_facts.copy()
  let differences = report.atomic_differences.copy()
  let events = report.events.copy()
  let groups : Array[PatternDifferenceGroup] = []
  for
    key in pattern_pair_keys(before_document.patterns, after_document.patterns) {
    let before_source = pattern_for_key(before_document.patterns, key)
    let after_source = pattern_for_key(after_document.patterns, key)
    groups.push({
      key,
      before_id: before_source.bind(pattern => pattern.authored_id),
      after_id: after_source.bind(pattern => pattern.authored_id),
      difference_ids: [],
      changed_fact_ids: [],
      affected_subject_ids: [],
    })
  }
  populate_pattern_consumers(groups, before_svg, after_svg, report.profile)
  for group in groups {
    append_pattern_resource_pair(
      group.key,
      pattern_for_key(before_document.patterns, group.key),
      pattern_for_key(after_document.patterns, group.key),
      before_document,
      after_document,
      group,
      changed_facts,
      differences,
    )
  }
  append_pattern_entity_differences(
    report, before_svg, after_svg, before_document, after_document, groups, changed_facts,
    differences, events,
  )
  let rendered = gradient_rendered_evidence(report, before_svg, after_svg)
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
        id: "event:pattern:\{group.key}",
        primary_subject_id: group.after_id.unwrap_or(
          group.before_id.unwrap_or(group.key),
        ),
        atomic_difference_ids: remaining,
        rendered_outcome: rendered,
        difference_regions: [],
      })
    }
  }
  let diagnostics = [
    for diagnostic in diagnostics if diagnostic.code !=
    "analysis_coverage_unproven" => diagnostic
  ]
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
