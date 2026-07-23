///|
fn event_subject_id_for_difference(
  events : Array[VisualEvent],
  difference_id : String,
) -> String {
  for event in events {
    if event.atomic_difference_ids.contains(difference_id) {
      return event.primary_subject_id
    }
  }
  "document"
}

///|
fn ensure_changed_fact_tokens(report : StructuredReport) -> StructuredReport {
  let changed_facts = report.changed_facts.copy()
  let differences : Array[AtomicDifference] = []
  for difference in report.atomic_differences {
    let ids = difference.changed_fact_ids.copy()
    if ids.is_empty() {
      let id = "fact:auto:\{difference.id}"
      ids.push(id)
      changed_facts.push({
        id,
        subject_id: difference.subject_alignment_id.unwrap_or(
          event_subject_id_for_difference(report.events, difference.id),
        ),
        property: difference.domain,
        before: difference.source_fact_before,
        after: difference.source_fact_after,
        affected_subject_ids: [
          event_subject_id_for_difference(report.events, difference.id),
        ],
      })
    }
    differences.push({ ..difference, changed_fact_ids: ids })
  }
  { ..report, changed_facts, atomic_differences: differences }
}

///|
fn push_unique_fact_ids(target : Array[String], source : Array[String]) -> Unit {
  for id in source {
    if !target.contains(id) {
      target.push(id)
    }
  }
}

///|
pub(all) struct SubjectInfluenceEntry {
  subject_id : String
  fact_ids : Array[String]
}

///|
pub(all) struct SubjectInfluenceIndex {
  fact_order : Array[String]
  entries : Array[SubjectInfluenceEntry]
}

///|
pub(all) enum InfluenceOperation {
  LeafInput
  GroupSurface
  ClipEffect
  MaskEffect
  FilterEffect
  BlendEffect
  IsolationEffect
  CompositingOrder
}

///|
pub fn influence_operation_for_domain(domain : String) -> InfluenceOperation {
  if domain == "compositing.opacity" {
    return GroupSurface
  }
  if domain.has_prefix("clipping.") || domain.has_prefix("resource.clip.") {
    return ClipEffect
  }
  if domain.has_prefix("masking.") || domain.has_prefix("resource.mask.") {
    return MaskEffect
  }
  if domain.has_prefix("filtering.") || domain.has_prefix("resource.filter.") {
    return FilterEffect
  }
  if domain == "compositing.blend_mode" {
    return BlendEffect
  }
  if domain == "compositing.isolation" {
    return IsolationEffect
  }
  if domain == "document.structure.stacking_order" {
    return CompositingOrder
  }
  LeafInput
}

///|
fn event_influence_operation(
  event : VisualEvent,
  differences : Array[AtomicDifference],
) -> InfluenceOperation {
  for difference in differences {
    if event.atomic_difference_ids.contains(difference.id) {
      match influence_operation_for_domain(difference.domain) {
        LeafInput => ()
        operation => return operation
      }
    }
  }
  LeafInput
}

///|
fn operation_uses_direct_subject_fanout(operation : InfluenceOperation) -> Bool {
  match operation {
    LeafInput => false
    GroupSurface
    | ClipEffect
    | MaskEffect
    | FilterEffect
    | BlendEffect
    | IsolationEffect
    | CompositingOrder => true
  }
}

///|
pub fn build_subject_influence_index(
  changed_facts : Array[ChangedFact],
) -> SubjectInfluenceIndex {
  let fact_order : Array[String] = []
  let entries : Array[SubjectInfluenceEntry] = []
  for fact in changed_facts {
    push_unique_fact_ids(fact_order, [fact.id])
    for subject_id in fact.affected_subject_ids {
      let mut found = false
      for index, entry in entries {
        if entry.subject_id == subject_id {
          let fact_ids = entry.fact_ids.copy()
          push_unique_fact_ids(fact_ids, [fact.id])
          entries[index] = { ..entry, fact_ids, }
          found = true
          break
        }
      }
      if !found {
        entries.push({ subject_id, fact_ids: [fact.id] })
      }
    }
  }
  { fact_order, entries }
}

///|
pub fn subject_influence_fact_ids(
  index : SubjectInfluenceIndex,
  subject_ids : Array[String],
) -> Array[String] {
  let reached : Array[String] = []
  for entry in index.entries {
    if subject_ids.contains(entry.subject_id) {
      push_unique_fact_ids(reached, entry.fact_ids)
    }
  }
  let ordered : Array[String] = []
  for fact_id in index.fact_order {
    if reached.contains(fact_id) {
      ordered.push(fact_id)
    }
  }
  ordered
}

///|
fn subject_reference_influence_id(reference : SubjectReference) -> String {
  match reference.instance_context {
    Some(context) => context.instance_id
    None =>
      reference.authored_id.unwrap_or(
        "\{reference.kind}:\{reference.source_index}",
      )
  }
}

///|
pub fn alignment_influence_subject_ids(
  alignment : SubjectAlignment,
) -> Array[String] {
  let ids : Array[String] = []
  for reference in alignment.before {
    let id = subject_reference_influence_id(reference)
    if !ids.contains(id) {
      ids.push(id)
    }
  }
  for reference in alignment.after {
    let id = subject_reference_influence_id(reference)
    if !ids.contains(id) {
      ids.push(id)
    }
  }
  ids
}

///|
fn entity_alignment_for_influence_event(
  event : VisualEvent,
  alignments : Array[SubjectAlignment],
) -> SubjectAlignment? {
  for alignment in alignments {
    if alignment.subject_role != "entity" {
      continue
    }
    if event.primary_subject_id == alignment.id ||
      alignment.before.any(reference => {
        subject_reference_influence_id(reference) == event.primary_subject_id
      }) ||
      alignment.after.any(reference => {
        subject_reference_influence_id(reference) == event.primary_subject_id
      }) {
      return Some(alignment)
    }
  }
  None
}

///|
pub fn event_changed_fact_ids(
  event : VisualEvent,
  differences : Array[AtomicDifference],
) -> Array[String] {
  let ids : Array[String] = []
  for difference in differences {
    if event.atomic_difference_ids.contains(difference.id) {
      push_unique_fact_ids(ids, difference.changed_fact_ids)
    }
  }
  ids
}

///|
pub fn event_influence_subject_ids(
  event : VisualEvent,
  report : StructuredReport,
  direct_fact_ids : Array[String],
) -> Array[String] {
  let ids : Array[String] = []
  match entity_alignment_for_influence_event(event, report.subject_alignments) {
    Some(alignment) =>
      for subject_id in alignment_influence_subject_ids(alignment) {
        if !ids.contains(subject_id) {
          ids.push(subject_id)
        }
      }
    None => ()
  }
  if ids.is_empty() ||
    operation_uses_direct_subject_fanout(
      event_influence_operation(event, report.atomic_differences),
    ) {
    for fact in report.changed_facts {
      if direct_fact_ids.contains(fact.id) {
        for subject_id in fact.affected_subject_ids {
          if !ids.contains(subject_id) {
            ids.push(subject_id)
          }
        }
      }
    }
  }
  ids
}

///|
pub fn event_may_influence_fact_ids(
  event : VisualEvent,
  report : StructuredReport,
  index : SubjectInfluenceIndex,
) -> Array[String] {
  let direct = event_changed_fact_ids(event, report.atomic_differences)
  let candidates = direct.copy()
  push_unique_fact_ids(
    candidates,
    subject_influence_fact_ids(
      index,
      event_influence_subject_ids(event, report, direct),
    ),
  )
  candidates
}

///|
pub fn attach_cause_envelopes(
  input_report : StructuredReport,
) -> StructuredReport {
  let report = ensure_changed_fact_tokens(input_report)
  let influence_index = build_subject_influence_index(report.changed_facts)
  let all_fact_ids = [ for fact in report.changed_facts => fact.id ]
  let diagnostic_ids = [ for diagnostic in report.diagnostics => diagnostic.id ]
  let complete = report.analysis_status == "complete"
  let events : Array[VisualEvent] = []
  for event in report.events {
    let regions : Array[DifferenceRegion] = []
    for region in event.difference_regions {
      let candidates : Array[String] = []
      if complete {
        for related_event in report.events {
          if related_event.difference_regions.any(related_region => {
              related_region.id == region.id
            }) {
            push_unique_fact_ids(
              candidates,
              event_may_influence_fact_ids(
                related_event, report, influence_index,
              ),
            )
          }
        }
      }
      let comparison_fallback = !complete || candidates.is_empty()
      if comparison_fallback {
        push_unique_fact_ids(candidates, all_fact_ids)
      }
      regions.push({
        ..region,
        cause_envelope: {
          guarantee: if complete {
            "sound_overapproximation"
          } else {
            "not_established"
          },
          coverage: if complete {
            "complete"
          } else {
            "partial"
          },
          fallback_scope: if comparison_fallback {
            "comparison"
          } else {
            "event_region"
          },
          candidate_changed_fact_ids: candidates,
          diagnostic_ids: if complete {
            []
          } else {
            diagnostic_ids
          },
        },
      })
    }
    events.push({ ..event, difference_regions: regions })
  }
  { ..report, events, }
}
