///|
priv struct TransformFactChange {
  id : String
  subject_id : String
  property : String
  before : DeclaredVisualFact?
  after : DeclaredVisualFact?
  affected_subject_ids : Array[String]
}

///|
fn transform_site_match_cost(
  before : SourceTransformSite,
  after : SourceTransformSite,
) -> Int {
  if before.kind != after.kind {
    2
  } else if before.authored_id is Some(_) &&
    before.authored_id == after.authored_id {
    0
  } else {
    1
  }
}

///|
fn align_transform_sites(
  before : Array[SourceTransformSite],
  after : Array[SourceTransformSite],
) -> Array[(Int?, Int?)] {
  let before_length = before.length()
  let after_length = after.length()
  let width = after_length + 1
  let costs = Array::make((before_length + 1) * width, 0)
  for before_index in 0..<=before_length {
    costs[before_index * width] = before_index
  }
  for after_index in 0..<=after_length {
    costs[after_index] = after_index
  }
  for before_index in 1..<=before_length {
    for after_index in 1..<=after_length {
      let substitution = transform_site_match_cost(
        before[before_index - 1],
        after[after_index - 1],
      )
      costs[before_index * width + after_index] = (costs[(before_index - 1) *
        width +
        after_index] +
        1)
        .min(costs[before_index * width + after_index - 1] + 1)
        .min(costs[(before_index - 1) * width + after_index - 1] + substitution)
    }
  }
  let reversed : Array[(Int?, Int?)] = []
  let mut before_index = before_length
  let mut after_index = after_length
  while before_index > 0 || after_index > 0 {
    if before_index > 0 && after_index > 0 {
      let substitution = transform_site_match_cost(
        before[before_index - 1],
        after[after_index - 1],
      )
      if costs[before_index * width + after_index] ==
        costs[(before_index - 1) * width + after_index - 1] + substitution {
        reversed.push((Some(before_index - 1), Some(after_index - 1)))
        before_index -= 1
        after_index -= 1
        continue
      }
    }
    if before_index > 0 &&
      costs[before_index * width + after_index] ==
      costs[(before_index - 1) * width + after_index] + 1 {
      reversed.push((Some(before_index - 1), None))
      before_index -= 1
    } else {
      reversed.push((None, Some(after_index - 1)))
      after_index -= 1
    }
  }
  let result : Array[(Int?, Int?)] = []
  let mut index = reversed.length() - 1
  while index >= 0 {
    result.push(reversed[index])
    index -= 1
  }
  result
}

///|
fn transform_site_fact(
  sites : Array[SourceTransformSite],
  index : Int?,
) -> DeclaredVisualFact? {
  match index {
    Some(index) => sites[index].fact
    None => None
  }
}

///|
fn transform_site_at(
  sites : Array[SourceTransformSite],
  index : Int?,
) -> SourceTransformSite? {
  match index {
    Some(index) => Some(sites[index])
    None => None
  }
}

///|
fn normalized_transform_site_signature(site : SourceTransformSite?) -> String {
  match site {
    Some(site) if site.complete => site.normalized_signature
    _ => ""
  }
}

///|
fn transform_declaration_changed(
  before : SourceTransformSite?,
  after : SourceTransformSite?,
) -> Bool {
  let before_fact = match before {
    Some(site) => site.fact
    None => None
  }
  let after_fact = match after {
    Some(site) => site.fact
    None => None
  }
  match (before_fact, after_fact) {
    (None, None) => false
    (Some(_), None) | (None, Some(_)) => true
    (Some(before_fact), Some(after_fact)) =>
      match (before, after) {
        (Some(before), Some(after)) if before.complete && after.complete =>
          normalized_transform_site_signature(Some(before)) !=
          normalized_transform_site_signature(Some(after))
        _ => before_fact.declared_value != after_fact.declared_value
      }
  }
}

///|
fn transform_fact_change_id(
  before : SourceTransformSite?,
  after : SourceTransformSite?,
) -> String {
  let before_index = match before {
    Some(site) => site.node_index.to_string()
    None => "none"
  }
  let after_index = match after {
    Some(site) => site.node_index.to_string()
    None => "none"
  }
  "fact:transform:\{before_index}:\{after_index}:transform"
}

///|
fn transform_change_subject_id(
  before : SourceTransformSite?,
  after : SourceTransformSite?,
) -> String {
  match (before, after) {
    (Some(site), _) => site.subject_id
    (_, Some(site)) => site.subject_id
    _ => "document"
  }
}

///|
fn add_transform_fact_change(
  changes : Array[TransformFactChange],
  before_sites : Array[SourceTransformSite],
  after_sites : Array[SourceTransformSite],
  pair : (Int?, Int?),
  affected_subject_ids : Array[String],
) -> Unit {
  let (before_index, after_index) = pair
  let before = transform_site_at(before_sites, before_index)
  let after = transform_site_at(after_sites, after_index)
  if !transform_declaration_changed(before, after) {
    return
  }
  let id = transform_fact_change_id(before, after)
  for change in changes {
    if change.id == id {
      for subject_id in affected_subject_ids {
        if !change.affected_subject_ids.contains(subject_id) {
          change.affected_subject_ids.push(subject_id)
        }
      }
      return
    }
  }
  changes.push({
    id,
    subject_id: transform_change_subject_id(before, after),
    property: "transform",
    before: transform_site_fact(before_sites, before_index),
    after: transform_site_fact(after_sites, after_index),
    affected_subject_ids: affected_subject_ids.copy(),
  })
}

///|
fn transform_fact_changes_for_alignment(
  before : SourceSubject,
  after : SourceSubject,
  affected_subject_ids : Array[String],
  changes : Array[TransformFactChange],
) -> Array[(Int?, Int?)] {
  let site_alignment = align_transform_sites(
    before.transform_chain,
    after.transform_chain,
  )
  for pair in site_alignment {
    add_transform_fact_change(
      changes,
      before.transform_chain,
      after.transform_chain,
      pair,
      affected_subject_ids,
    )
  }
  add_viewport_fact_changes_for_alignment(
    changes,
    before.transform_chain,
    after.transform_chain,
    site_alignment,
    affected_subject_ids,
  )
  site_alignment
}

///|
fn transform_syntax_diagnostic_ids(
  report : StructuredReport,
  before : SourceTransformSite?,
  after : SourceTransformSite?,
) -> Array[String] {
  [
    for diagnostic in report.diagnostics if diagnostic.code ==
    "transform_syntax_unsupported" &&
    transform_syntax_diagnostic_matches(diagnostic, before, after) => {
      diagnostic.id
    }
  ]
}

///|
fn transform_renderer_diagnostic_ids(
  report : StructuredReport,
  before : SourceTransformSite?,
  after : SourceTransformSite?,
) -> Array[String] {
  [
    for diagnostic in report.diagnostics if diagnostic.code ==
    "renderer_transform_raster_unproven" &&
    transform_syntax_diagnostic_matches(diagnostic, before, after) => {
      diagnostic.id
    }
  ]
}

///|
fn transform_chain_renderer_diagnostic_ids(
  report : StructuredReport,
  before : SourceSubject,
  after : SourceSubject,
) -> Array[String] {
  let ids : Array[String] = []
  fn append_unique(source : Array[String]) -> Unit {
    for id in source {
      if !ids.contains(id) {
        ids.push(id)
      }
    }
  }
  for site in before.transform_chain {
    append_unique(transform_renderer_diagnostic_ids(report, Some(site), None))
    append_unique(
      viewport_diagnostic_ids(
        report,
        "renderer_viewport_raster_unproven",
        Some(site),
        None,
      ),
    )
  }
  for site in after.transform_chain {
    append_unique(transform_renderer_diagnostic_ids(report, None, Some(site)))
    append_unique(
      viewport_diagnostic_ids(
        report,
        "renderer_viewport_raster_unproven",
        None,
        Some(site),
      ),
    )
  }
  ids.sort()
  ids
}

///|
fn transform_syntax_diagnostic_matches(
  diagnostic : Diagnostic,
  before : SourceTransformSite?,
  after : SourceTransformSite?,
) -> Bool {
  match (before, after) {
    (Some(before), Some(after)) =>
      diagnostic.subject_id == before.subject_id ||
      diagnostic.subject_id == before.kind ||
      diagnostic.subject_id == after.subject_id ||
      diagnostic.subject_id == after.kind
    (Some(before), None) =>
      diagnostic.subject_id == before.subject_id ||
      diagnostic.subject_id == before.kind
    (None, Some(after)) =>
      diagnostic.subject_id == after.subject_id ||
      diagnostic.subject_id == after.kind
    _ => false
  }
}

///|
fn transform_list_relation(
  report : StructuredReport,
  before : SourceTransformSite?,
  after : SourceTransformSite?,
) -> ComputedRelation {
  let diagnostics = transform_syntax_diagnostic_ids(report, before, after)
  let renderer_diagnostics = transform_renderer_diagnostic_ids(
    report, before, after,
  )
  match (before, after) {
    (Some(before), Some(after)) if before.complete && after.complete =>
      if before.matrix == after.matrix {
        {
          status: "equivalent",
          reason_code: "same_local_transform_matrix",
          missing_side: None,
          diagnostic_ids: renderer_diagnostics,
        }
      } else {
        {
          status: "different",
          reason_code: "local_transform_matrices_differ",
          missing_side: None,
          diagnostic_ids: renderer_diagnostics,
        }
      }
    (Some(before), None) if before.complete =>
      {
        status: if before.matrix.is_identity() {
          "equivalent"
        } else {
          "different"
        },
        reason_code: if before.matrix.is_identity() {
          "removed_identity_transform"
        } else {
          "removed_local_transform"
        },
        missing_side: None,
        diagnostic_ids: renderer_diagnostics,
      }
    (None, Some(after)) if after.complete =>
      {
        status: if after.matrix.is_identity() {
          "equivalent"
        } else {
          "different"
        },
        reason_code: if after.matrix.is_identity() {
          "added_identity_transform"
        } else {
          "added_local_transform"
        },
        missing_side: None,
        diagnostic_ids: renderer_diagnostics,
      }
    _ =>
      {
        status: "indeterminate",
        reason_code: "transform_syntax_unsupported",
        missing_side: None,
        diagnostic_ids: diagnostics,
      }
  }
}

///|
fn transform_fact_change(
  changes : Array[TransformFactChange],
  id : String,
) -> TransformFactChange? {
  for change in changes {
    if change.id == id {
      return Some(change)
    }
  }
  None
}

///|
fn append_transform_difference(
  report : StructuredReport,
  alignment : SubjectAlignment,
  before : SourceSubject,
  after : SourceSubject,
  site_alignment : Array[(Int?, Int?)],
  changes : Array[TransformFactChange],
  differences : Array[AtomicDifference],
  difference_ids : Array[String],
) -> Array[String] {
  let changed_fact_ids = append_viewport_differences(
    report, alignment, before, after, site_alignment, changes, differences, difference_ids,
  )
  for pair in site_alignment {
    let (before_index, after_index) = pair
    let before_site = transform_site_at(before.transform_chain, before_index)
    let after_site = transform_site_at(after.transform_chain, after_index)
    if !transform_declaration_changed(before_site, after_site) {
      continue
    }
    let fact_id = transform_fact_change_id(before_site, after_site)
    changed_fact_ids.push(fact_id)
    let change = match transform_fact_change(changes, fact_id) {
      Some(change) => change
      None => continue
    }
    let difference_id = "diff:\{alignment.id}:transform:list:\{fact_id}"
    let relation = transform_list_relation(report, before_site, after_site)
    let evidence_layers : Array[String] = ["source_semantics"]
    if relation.status != "indeterminate" {
      evidence_layers.push("computed_appearance")
    }
    differences.push({
      id: difference_id,
      subject_role: "entity",
      subject_alignment_id: Some(alignment.id),
      domain: "geometry.transform.list",
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
  if before.transform_complete &&
    after.transform_complete &&
    before.cumulative_transform != after.cumulative_transform {
    let difference_id = "diff:\{alignment.id}:transform:cumulative"
    differences.push({
      id: difference_id,
      subject_role: "entity",
      subject_alignment_id: Some(alignment.id),
      domain: "geometry.transform.cumulative_matrix",
      source_before: before.cumulative_transform.signature(),
      source_after: after.cumulative_transform.signature(),
      source_fact_before: None,
      source_fact_after: None,
      changed_fact_ids,
      evidence_layers: ["computed_appearance", "rendered_evidence"],
      computed_relation: {
        status: "different",
        reason_code: "cumulative_transform_matrices_differ",
        missing_side: None,
        diagnostic_ids: transform_chain_renderer_diagnostic_ids(
          report, before, after,
        ),
      },
      parameter_delta_css_px: None,
      presence_magnitude: None,
      magnitude: empty_difference_magnitude(),
      domain_ordering: empty_domain_ordering(),
    })
    difference_ids.push(difference_id)
    append_transform_effect_differences(
      report, alignment, before, after, changed_fact_ids, differences, difference_ids,
    )
  }
  changed_fact_ids
}

///|
fn transform_rendered_evidence(
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
    _ => not_computed_rendered_evidence("transform_syntax_unsupported")
  }
}

///|
fn attach_transform_differences(
  report : StructuredReport,
  before_svg : String,
  after_svg : String,
  alignments : Array[SubjectAlignment],
) -> StructuredReport {
  let before_subjects = extract_source_subjects_with_profile_or_raise(
    before_svg,
    report.profile,
  ) catch {
    _ => return report
  }
  let after_subjects = extract_source_subjects_with_profile_or_raise(
    after_svg,
    report.profile,
  ) catch {
    _ => return report
  }
  let changes : Array[TransformFactChange] = []
  for alignment in alignments {
    let before = subjects_for_references(before_subjects, alignment.before)
    let after = subjects_for_references(after_subjects, alignment.after)
    match (before, after) {
      ([before], [after]) =>
        ignore(
          transform_fact_changes_for_alignment(
            before,
            after,
            alignment_subject_ids([before], [after]),
            changes,
          ),
        )
      _ => ()
    }
  }
  if changes.is_empty() {
    return report
  }
  let changed_facts = report.changed_facts.copy()
  for change in changes {
    changed_facts.push({
      id: change.id,
      subject_id: change.subject_id,
      property: change.property,
      before: change.before,
      after: change.after,
      affected_subject_ids: change.affected_subject_ids,
    })
  }
  let differences = report.atomic_differences.copy()
  let events = report.events.copy()
  let rendered = transform_rendered_evidence(
    before_svg,
    after_svg,
    report.profile,
  )
  for alignment in alignments {
    let before = subjects_for_references(before_subjects, alignment.before)
    let after = subjects_for_references(after_subjects, alignment.after)
    match (before, after) {
      ([before], [after]) => {
        let site_alignment = align_transform_sites(
          before.transform_chain,
          after.transform_chain,
        )
        let difference_ids : Array[String] = []
        ignore(
          append_transform_difference(
            report, alignment, before, after, site_alignment, changes, differences,
            difference_ids,
          ),
        )
        if !difference_ids.is_empty() {
          events.push({
            id: "event:\{alignment.id}:transform",
            primary_subject_id: alignment.id,
            atomic_difference_ids: difference_ids,
            rendered_outcome: rendered,
            difference_regions: [],
          })
        }
      }
      _ => ()
    }
  }
  { ..report, changed_facts, atomic_differences: differences, events }
}
