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
fn event_changed_fact_ids(
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
fn attach_cause_envelopes(input_report : StructuredReport) -> StructuredReport {
  let report = ensure_changed_fact_tokens(input_report)
  let all_fact_ids = [ for fact in report.changed_facts => fact.id ]
  let diagnostic_ids = [ for diagnostic in report.diagnostics => diagnostic.id ]
  let complete = report.analysis_status == "complete"
  let events : Array[VisualEvent] = []
  for event in report.events {
    let compositing_dependency_event = event.atomic_difference_ids.any(id => {
      report.atomic_differences.any(difference => {
        difference.id == id &&
        (
          difference.domain == "compositing.opacity" ||
          difference.domain == "compositing.blend_mode" ||
          difference.domain == "compositing.isolation" ||
          difference.domain == "document.structure.stacking_order"
        )
      })
    })
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
              event_changed_fact_ids(related_event, report.atomic_differences),
            )
          }
        }
      }
      if !complete || candidates.is_empty() {
        push_unique_fact_ids(candidates, all_fact_ids)
      }
      if complete && compositing_dependency_event {
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
          fallback_scope: if candidates.length() == all_fact_ids.length() {
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
