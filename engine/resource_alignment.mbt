///|
fn resource_alignment_kinds(domain : String) -> Array[String] {
  if domain.has_prefix("resource.gradient.") {
    ["linearGradient", "radialGradient"]
  } else if domain.has_prefix("resource.pattern.") {
    ["pattern"]
  } else if domain.has_prefix("resource.marker.") {
    ["marker"]
  } else if domain.has_prefix("resource.clip.") {
    ["clipPath"]
  } else if domain.has_prefix("resource.mask.") {
    ["mask"]
  } else if domain.has_prefix("resource.filter.") {
    ["filter"]
  } else if domain.has_prefix("resource.image.") {
    ["image"]
  } else {
    []
  }
}

///|
fn resource_reference_subject_id(reference : SubjectReference) -> String {
  reference.authored_id.unwrap_or("\{reference.kind}:\{reference.source_index}")
}

///|
fn resource_reference_matches_subject(
  reference : SubjectReference,
  subject_id : String,
) -> Bool {
  let reference_id = resource_reference_subject_id(reference)
  subject_id == reference_id || subject_id.has_prefix("\{reference_id}:")
}

///|
fn resource_alignment_allowed(
  alignment : SubjectAlignment,
  kinds : Array[String],
) -> Bool {
  if alignment.subject_role != "resource" {
    return false
  }
  kinds.is_empty() ||
  (alignment.before + alignment.after).any(reference => {
    kinds.contains(reference.kind)
  })
}

///|
fn changed_fact_for_id(
  changed_facts : Array[ChangedFact],
  id : String,
) -> ChangedFact? {
  for fact in changed_facts {
    if fact.id == id {
      return Some(fact)
    }
  }
  None
}

///|
fn resource_alignment_by_subject(
  alignments : Array[SubjectAlignment],
  changed_facts : Array[ChangedFact],
  difference : AtomicDifference,
  kinds : Array[String],
) -> String? {
  let subject_ids : Array[String] = []
  for fact_id in difference.changed_fact_ids {
    match changed_fact_for_id(changed_facts, fact_id) {
      Some(fact) => push_unique(subject_ids, fact.subject_id)
      None => ()
    }
  }
  for alignment in alignments {
    if !resource_alignment_allowed(alignment, kinds) {
      continue
    }
    if subject_ids.any(subject_id => {
        (alignment.before + alignment.after).any(reference => {
          resource_reference_matches_subject(reference, subject_id)
        })
      }) {
      return Some(alignment.id)
    }
  }
  None
}

///|
fn nearest_resource_alignment_for_offset(
  alignments : Array[SubjectAlignment],
  kinds : Array[String],
  source_role : String,
  source_offset : Int,
) -> String? {
  let mut selected : String? = None
  let mut selected_offset = -1
  for alignment in alignments {
    if !resource_alignment_allowed(alignment, kinds) {
      continue
    }
    let references = if source_role == "before" {
      alignment.before
    } else {
      alignment.after
    }
    for reference in references {
      if reference.source_index <= source_offset &&
        reference.source_index > selected_offset {
        selected = Some(alignment.id)
        selected_offset = reference.source_index
      }
    }
  }
  selected
}

///|
fn resource_alignment_by_source_span(
  alignments : Array[SubjectAlignment],
  difference : AtomicDifference,
  kinds : Array[String],
) -> String? {
  let before = difference.source_fact_before.bind(fact => {
    nearest_resource_alignment_for_offset(
      alignments,
      kinds,
      "before",
      fact.source_span.start_offset,
    )
  })
  let after = difference.source_fact_after.bind(fact => {
    nearest_resource_alignment_for_offset(
      alignments,
      kinds,
      "after",
      fact.source_span.start_offset,
    )
  })
  match (before, after) {
    (Some(before), Some(after)) if before == after => Some(before)
    (Some(before), None) => Some(before)
    (None, Some(after)) => Some(after)
    _ => None
  }
}

///|
fn sole_resource_alignment(
  alignments : Array[SubjectAlignment],
  kinds : Array[String],
) -> String? {
  let candidates = [
    for alignment in alignments if resource_alignment_allowed(alignment, kinds) => {
      alignment.id
    }
  ]
  match candidates {
    [id] => Some(id)
    _ => None
  }
}

///|
fn attach_resource_alignment_ids(report : StructuredReport) -> StructuredReport {
  let differences : Array[AtomicDifference] = []
  for difference in report.atomic_differences {
    if difference.subject_role != "resource" ||
      difference.subject_alignment_id is Some(_) {
      differences.push(difference)
      continue
    }
    let kinds = resource_alignment_kinds(difference.domain)
    let by_subject = resource_alignment_by_subject(
      report.subject_alignments,
      report.changed_facts,
      difference,
      kinds,
    )
    let alignment_id = match by_subject {
      Some(id) => Some(id)
      None =>
        match
          resource_alignment_by_source_span(
            report.subject_alignments,
            difference,
            kinds,
          ) {
          Some(id) => Some(id)
          None => sole_resource_alignment(report.subject_alignments, kinds)
        }
    }
    differences.push({ ..difference, subject_alignment_id: alignment_id })
  }
  { ..report, atomic_differences: differences }
}
