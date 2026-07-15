///|
priv struct StructuralAlignedSubject {
  alignment : SubjectAlignment
  before : SourceSubject
  after : SourceSubject
}

///|
fn structural_aligned_subjects(
  alignments : Array[SubjectAlignment],
  before : Array[SourceSubject],
  after : Array[SourceSubject],
) -> Array[StructuralAlignedSubject] {
  let result : Array[StructuralAlignedSubject] = []
  for alignment in alignments {
    match
      (
        subjects_for_references(before, alignment.before),
        subjects_for_references(after, alignment.after),
      ) {
      ([before_subject], [after_subject]) =>
        result.push({ alignment, before: before_subject, after: after_subject })
      _ => ()
    }
  }
  result
}

///|
fn structural_consequence_difference_ids(
  report : StructuredReport,
  alignment_id : String,
) -> Array[String] {
  [
    for difference in report.atomic_differences if difference.subject_alignment_id ==
    Some(alignment_id) &&
    difference.computed_relation.status == "different" &&
    difference.domain.find("document.structure.") != Some(0) => difference.id
  ]
}

///|
fn structural_event_rendered_evidence(
  report : StructuredReport,
  consequence_ids : Array[String],
) -> RenderedEvidence? {
  for event in report.events {
    if event.atomic_difference_ids.any(id => consequence_ids.contains(id)) {
      return Some(event.rendered_outcome)
    }
  }
  None
}

///|
fn structural_difference_evidence_layers(
  report : StructuredReport,
  consequence_ids : Array[String],
) -> Array[String] {
  let layers : Array[String] = ["source_semantics", "computed_appearance"]
  match structural_event_rendered_evidence(report, consequence_ids) {
    Some(evidence) if evidence.status == "computed" =>
      layers.push("rendered_evidence")
    _ => ()
  }
  layers
}

///|
fn append_structural_fact_to_consequences(
  report : StructuredReport,
  consequence_ids : Array[String],
  fact_id : String,
) -> StructuredReport {
  let differences : Array[AtomicDifference] = []
  for difference in report.atomic_differences {
    if consequence_ids.contains(difference.id) {
      let changed_fact_ids = difference.changed_fact_ids.copy()
      if !changed_fact_ids.contains(fact_id) {
        changed_fact_ids.push(fact_id)
      }
      differences.push({ ..difference, changed_fact_ids, })
    } else {
      differences.push(difference)
    }
  }
  { ..report, atomic_differences: differences }
}

///|
fn append_structural_difference_to_event(
  report : StructuredReport,
  consequence_ids : Array[String],
  difference_id : String,
  fallback_subject_id : String,
) -> StructuredReport {
  let events : Array[VisualEvent] = []
  let mut attached = false
  for event in report.events {
    if !attached &&
      event.atomic_difference_ids.any(id => consequence_ids.contains(id)) {
      let difference_ids = event.atomic_difference_ids.copy()
      difference_ids.push(difference_id)
      events.push({ ..event, atomic_difference_ids: difference_ids })
      attached = true
    } else {
      events.push(event)
    }
  }
  if !attached {
    events.push({
      id: "event:\{difference_id}",
      primary_subject_id: fallback_subject_id,
      atomic_difference_ids: [difference_id],
      rendered_outcome: not_computed_rendered_evidence(
        "structural_consequence_event_unavailable",
      ),
      difference_regions: [],
    })
  }
  { ..report, events, }
}

///|
fn append_aligned_structural_difference(
  report : StructuredReport,
  aligned : StructuralAlignedSubject,
  kind : String,
  before_signature : String,
  after_signature : String,
  consequence_ids : Array[String],
) -> StructuredReport {
  let fact_id = "fact:\{aligned.alignment.id}:structure:\{kind}"
  let difference_id = "diff:\{aligned.alignment.id}:structure:\{kind}"
  report.changed_facts.push({
    id: fact_id,
    subject_id: aligned.alignment.id,
    property: "structure.\{kind}",
    before: None,
    after: None,
    affected_subject_ids: alignment_subject_ids([aligned.before], [
      aligned.after,
    ]),
  })
  let report = append_structural_fact_to_consequences(
    report, consequence_ids, fact_id,
  )
  report.atomic_differences.push({
    id: difference_id,
    subject_role: "entity",
    subject_alignment_id: Some(aligned.alignment.id),
    domain: "document.structure.\{kind}",
    source_before: before_signature,
    source_after: after_signature,
    source_fact_before: None,
    source_fact_after: None,
    changed_fact_ids: [fact_id],
    evidence_layers: structural_difference_evidence_layers(
      report, consequence_ids,
    ),
    computed_relation: {
      status: "different",
      reason_code: if kind == "ancestry" {
        "effective_parent_paths_differ"
      } else {
        "instance_resolution_paths_differ"
      },
      missing_side: None,
      diagnostic_ids: [],
    },
    parameter_delta_css_px: None,
    presence_magnitude: None,
    magnitude: empty_difference_magnitude(),
    domain_ordering: empty_domain_ordering(),
  })
  append_structural_difference_to_event(
    report,
    consequence_ids,
    difference_id,
    aligned.alignment.id,
  )
}

///|
fn attach_aligned_structural_differences(
  report : StructuredReport,
  aligned_subjects : Array[StructuralAlignedSubject],
) -> StructuredReport {
  let mut report = report
  for aligned in aligned_subjects {
    let consequence_ids = structural_consequence_difference_ids(
      report,
      aligned.alignment.id,
    )
    if consequence_ids.is_empty() {
      continue
    }
    if aligned.before.structural_parent_path_signature !=
      aligned.after.structural_parent_path_signature {
      report = append_aligned_structural_difference(
        report,
        aligned,
        "ancestry",
        aligned.before.structural_parent_path_signature,
        aligned.after.structural_parent_path_signature,
        consequence_ids,
      )
    }
    if aligned.before.instance_resolution_signature !=
      aligned.after.instance_resolution_signature {
      report = append_aligned_structural_difference(
        report,
        aligned,
        "resource_resolution",
        aligned.before.instance_resolution_signature,
        aligned.after.instance_resolution_signature,
        consequence_ids,
      )
    }
  }
  report
}

///|
fn structural_bounds_overlap(left : CssBounds, right : CssBounds) -> Bool {
  left.x < right.x + right.width &&
  left.x + left.width > right.x &&
  left.y < right.y + right.height &&
  left.y + left.height > right.y
}

///|
fn structural_subjects_may_overlap(
  left : SourceSubject,
  right : SourceSubject,
) -> Bool {
  match (source_subject_bounds(left), source_subject_bounds(right)) {
    (Some(left), Some(right)) => structural_bounds_overlap(left, right)
    _ => true
  }
}

///|
fn structural_order_inverted(
  left : StructuralAlignedSubject,
  right : StructuralAlignedSubject,
) -> Bool {
  let before_order = left.before.reference.source_index.compare(
    right.before.reference.source_index,
  )
  let after_order = left.after.reference.source_index.compare(
    right.after.reference.source_index,
  )
  before_order != 0 && after_order != 0 && before_order != after_order
}

///|
fn append_stacking_difference(
  report : StructuredReport,
  left : StructuralAlignedSubject,
  right : StructuralAlignedSubject,
  rendered : RenderedEvidence,
) -> Unit {
  let pair_id = "\{left.alignment.id}:\{right.alignment.id}"
  let fact_id = "fact:structure:stacking:\{pair_id}"
  let difference_id = "diff:structure:stacking:\{pair_id}"
  let affected = alignment_subject_ids([left.before, right.before], [
    left.after,
    right.after,
  ])
  report.changed_facts.push({
    id: fact_id,
    subject_id: "document",
    property: "structure.stacking_order",
    before: None,
    after: None,
    affected_subject_ids: affected,
  })
  report.atomic_differences.push({
    id: difference_id,
    subject_role: "entity",
    subject_alignment_id: None,
    domain: "document.structure.stacking_order",
    source_before: "\{left.alignment.id} before \{right.alignment.id}",
    source_after: "\{right.alignment.id} before \{left.alignment.id}",
    source_fact_before: None,
    source_fact_after: None,
    changed_fact_ids: [fact_id],
    evidence_layers: [
      "source_semantics", "computed_appearance", "rendered_evidence",
    ],
    computed_relation: {
      status: "different",
      reason_code: "overlapping_draw_order_inverted",
      missing_side: None,
      diagnostic_ids: [],
    },
    parameter_delta_css_px: None,
    presence_magnitude: None,
    magnitude: empty_difference_magnitude(),
    domain_ordering: empty_domain_ordering(),
  })
  report.events.push({
    id: "event:structure:stacking:\{pair_id}",
    primary_subject_id: "document",
    atomic_difference_ids: [difference_id],
    rendered_outcome: rendered,
    difference_regions: [],
  })
}

///|
fn attach_stacking_differences(
  report : StructuredReport,
  aligned_subjects : Array[StructuralAlignedSubject],
  rendered : RenderedEvidence,
) -> Unit {
  guard rendered.status == "computed" else { return }
  guard rendered.magnitude is Some(magnitude) && magnitude.changed_pixels > 0 else {
    return
  }
  for left_index in 0..<aligned_subjects.length() {
    for right_index in (left_index + 1)..<aligned_subjects.length() {
      let left = aligned_subjects[left_index]
      let right = aligned_subjects[right_index]
      if structural_order_inverted(left, right) &&
        (
          structural_subjects_may_overlap(left.before, right.before) ||
          structural_subjects_may_overlap(left.after, right.after)
        ) {
        append_stacking_difference(report, left, right, rendered)
      }
    }
  }
}

///|
fn structural_rendered_evidence(
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
    _ => not_computed_rendered_evidence("structural_renderer_unavailable")
  }
}

///|
fn attach_structural_differences(
  report : StructuredReport,
  before_svg : String,
  after_svg : String,
  alignments : Array[SubjectAlignment],
) -> StructuredReport {
  let before = extract_source_subjects_with_profile_or_raise(
    before_svg,
    report.profile,
  ) catch {
    _ => return report
  }
  let after = extract_source_subjects_with_profile_or_raise(
    after_svg,
    report.profile,
  ) catch {
    _ => return report
  }
  let aligned_subjects = structural_aligned_subjects(alignments, before, after)
  let report = attach_aligned_structural_differences(report, aligned_subjects)
  attach_stacking_differences(
    report,
    aligned_subjects,
    structural_rendered_evidence(before_svg, after_svg, report.profile),
  )
  report
}
