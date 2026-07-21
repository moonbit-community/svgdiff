///|
fn report_changed_fact_property(
  report : StructuredReport,
  difference : AtomicDifference,
) -> String? {
  match difference.source_fact_before {
    Some(fact) => return Some(fact.property)
    None => ()
  }
  match difference.source_fact_after {
    Some(fact) => return Some(fact.property)
    None => ()
  }
  for id in difference.changed_fact_ids {
    for fact in report.changed_facts {
      if fact.id == id {
        return Some(fact.property)
      }
    }
  }
  None
}

///|
fn same_analysis_atomic_difference(
  base_report : StructuredReport,
  base : AtomicDifference,
  extra_report : StructuredReport,
  extra : AtomicDifference,
) -> Bool {
  base.subject_role == extra.subject_role &&
  base.subject_alignment_id is Some(base_alignment) &&
  extra.subject_alignment_id == Some(base_alignment) &&
  base.domain == extra.domain &&
  report_changed_fact_property(base_report, base) ==
  report_changed_fact_property(extra_report, extra) &&
  base.source_before == extra.source_before &&
  base.source_after == extra.source_after
}

///|
fn difference_for_report_id(
  differences : Array[AtomicDifference],
  id : String,
) -> AtomicDifference? {
  for difference in differences {
    if difference.id == id {
      return Some(difference)
    }
  }
  None
}

///|
fn event_alignment_id(
  event : VisualEvent,
  differences : Array[AtomicDifference],
) -> String? {
  for id in event.atomic_difference_ids {
    match difference_for_report_id(differences, id) {
      Some({ subject_role: "entity", subject_alignment_id: Some(id), .. }) =>
        return Some(id)
      _ => ()
    }
  }
  None
}

///|
fn replace_event_atomic_id(
  events : Array[VisualEvent],
  old_id : String,
  new_id : String,
) -> Unit {
  for event in events {
    for index, id in event.atomic_difference_ids {
      if id == old_id {
        event.atomic_difference_ids[index] = new_id
      }
    }
  }
}

///|
fn append_atomic_to_owner_event(
  events : Array[VisualEvent],
  differences : Array[AtomicDifference],
  difference : AtomicDifference,
  source_events : Array[VisualEvent],
) -> Unit {
  match difference.subject_alignment_id {
    Some(alignment_id) =>
      for event in events {
        if event_alignment_id(event, differences) == Some(alignment_id) {
          if !event.atomic_difference_ids.contains(difference.id) {
            event.atomic_difference_ids.push(difference.id)
          }
          return
        }
      }
    None => ()
  }
  for event in source_events {
    if event.atomic_difference_ids.contains(difference.id) {
      events.push({ ..event, atomic_difference_ids: [difference.id] })
      return
    }
  }
}

///|
fn append_unique_resolution(
  resolutions : Array[SourceResolutionPair],
  resolution : SourceResolutionPair,
) -> Unit {
  if !resolutions.any(current => {
      current.subject_id == resolution.subject_id &&
      current.property == resolution.property
    }) {
    resolutions.push(resolution)
  }
}

///|
fn compose_analysis_reports(
  base_report : StructuredReport,
  extra_report : StructuredReport,
  alignments : Array[SubjectAlignment],
) -> StructuredReport {
  let base_report = attach_subject_alignments(base_report, alignments)
  let extra_report = attach_subject_alignments(extra_report, alignments)
  let differences = base_report.atomic_differences.copy()
  let events = [
    for event in base_report.events => {
      { ..event, atomic_difference_ids: event.atomic_difference_ids.copy() }
    }
  ]
  let original_base_count = differences.length()
  for extra in extra_report.atomic_differences {
    let mut duplicate_index : Int? = None
    for index in 0..<original_base_count {
      if same_analysis_atomic_difference(
          base_report,
          differences[index],
          extra_report,
          extra,
        ) {
        duplicate_index = Some(index)
        break
      }
    }
    match duplicate_index {
      Some(index) => {
        let old_id = differences[index].id
        differences[index] = extra
        replace_event_atomic_id(events, old_id, extra.id)
      }
      None => {
        differences.push(extra)
        append_atomic_to_owner_event(
          events,
          differences,
          extra,
          extra_report.events,
        )
      }
    }
  }
  let referenced_fact_ids : Array[String] = []
  for difference in differences {
    for id in difference.changed_fact_ids {
      if !referenced_fact_ids.contains(id) {
        referenced_fact_ids.push(id)
      }
    }
  }
  let changed_facts : Array[ChangedFact] = []
  for source in [base_report.changed_facts, extra_report.changed_facts] {
    for fact in source {
      if referenced_fact_ids.contains(fact.id) &&
        !changed_facts.any(current => current.id == fact.id) {
        changed_facts.push(fact)
      }
    }
  }
  let source_resolutions = base_report.source_resolutions.copy()
  for resolution in extra_report.source_resolutions {
    append_unique_resolution(source_resolutions, resolution)
  }
  let diagnostics = base_report.diagnostics.copy()
  for diagnostic in extra_report.diagnostics {
    merge_diagnostic_into(diagnostics, diagnostic)
  }
  {
    ..base_report,
    analysis_status: if base_report.analysis_status == "complete" &&
      extra_report.analysis_status == "complete" &&
      diagnostics.is_empty() {
      "complete"
    } else {
      "partial"
    },
    changed_facts,
    source_resolutions,
    atomic_differences: differences,
    events,
    diagnostics,
  }
}
