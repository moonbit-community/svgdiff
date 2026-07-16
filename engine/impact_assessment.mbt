///|
priv struct ImpactCandidate {
  event_id : String
  atomic_difference_ids : Array[String]
  measurements : ImpactMeasurement?
}

///|
fn impact_candidate(event : VisualEvent) -> ImpactCandidate {
  let measurements = match event.rendered_outcome {
    { status: "computed", magnitude: Some(magnitude), .. } =>
      Some({
        changed_pixel_fraction: magnitude.changed_pixel_fraction,
        linear_premultiplied_rgba_rmse: magnitude.linear_premultiplied_rgba_rmse,
      })
    _ => None
  }
  {
    event_id: event.id,
    atomic_difference_ids: event.atomic_difference_ids.copy(),
    measurements,
  }
}

///|
fn impact_candidate_dominates(
  dominant : ImpactCandidate,
  dominated : ImpactCandidate,
) -> Bool {
  match (dominant.measurements, dominated.measurements) {
    (Some(left), Some(right)) =>
      left.changed_pixel_fraction >= right.changed_pixel_fraction &&
      left.linear_premultiplied_rgba_rmse >=
      right.linear_premultiplied_rgba_rmse &&
      (
        left.changed_pixel_fraction > right.changed_pixel_fraction ||
        left.linear_premultiplied_rgba_rmse >
        right.linear_premultiplied_rgba_rmse
      )
    _ => false
  }
}

///|
fn impact_measurements_equal(
  left : ImpactMeasurement?,
  right : ImpactMeasurement?,
) -> Bool {
  match (left, right) {
    (Some(left), Some(right)) => left == right
    _ => false
  }
}

///|
fn push_unique_impact_ids(
  target : Array[String],
  source : Array[String],
) -> Unit {
  for id in source {
    if !target.contains(id) {
      target.push(id)
    }
  }
}

///|
fn impact_frontier_relation(groups : Array[ImpactFrontierGroup]) -> String {
  if groups.is_empty() {
    "not_applicable"
  } else if groups.length() == 1 {
    if groups[0].event_ids.length() == 1 {
      "unique"
    } else {
      "tied"
    }
  } else if groups.any(group => group.event_ids.length() > 1) {
    "mixed"
  } else {
    "incomparable"
  }
}

///|
fn impact_assessment_for_events(
  events : Array[VisualEvent],
) -> ImpactAssessment {
  let candidates = [ for event in events => impact_candidate(event) ]
  candidates.sort_by(fn(left, right) { left.event_id.compare(right.event_id) })
  let frontier : Array[ImpactCandidate] = []
  let witnesses : Array[ImpactDominationWitness] = []
  let mut has_missing_measurements = false
  for candidate in candidates {
    if candidate.measurements is None {
      has_missing_measurements = true
    }
    let mut dominant_id : String? = None
    for possible_dominant in candidates {
      if possible_dominant.event_id != candidate.event_id &&
        impact_candidate_dominates(possible_dominant, candidate) {
        dominant_id = Some(possible_dominant.event_id)
        break
      }
    }
    match dominant_id {
      Some(dominant_event_id) =>
        witnesses.push({
          dominant_event_id,
          dominated_event_id: candidate.event_id,
          rule_id: "both_rendered_metrics_no_less_and_one_greater",
        })
      None => frontier.push(candidate)
    }
  }
  let groups : Array[ImpactFrontierGroup] = []
  for candidate in frontier {
    let mut matched_index = -1
    for index, group in groups {
      if impact_measurements_equal(group.measurements, candidate.measurements) {
        matched_index = index
        break
      }
    }
    if matched_index >= 0 {
      groups[matched_index].event_ids.push(candidate.event_id)
      push_unique_impact_ids(
        groups[matched_index].atomic_difference_ids,
        candidate.atomic_difference_ids,
      )
    } else {
      groups.push({
        event_ids: [candidate.event_id],
        atomic_difference_ids: candidate.atomic_difference_ids.copy(),
        measurements: candidate.measurements,
      })
    }
  }
  {
    policy_id: "event_rendered_pareto/v1",
    status: if candidates.is_empty() {
      "not_applicable"
    } else if has_missing_measurements {
      "partial"
    } else {
      "complete"
    },
    calibration_status: "not_calibrated",
    input_fields: [
      "events[].rendered_outcome.magnitude.changed_pixel_fraction", "events[].rendered_outcome.magnitude.linear_premultiplied_rgba_rmse",
    ],
    candidate_event_count: candidates.length(),
    frontier_relation: impact_frontier_relation(groups),
    frontier_groups: groups,
    domination_witnesses: witnesses,
  }
}

///|
fn empty_impact_assessment() -> ImpactAssessment {
  impact_assessment_for_events([])
}

///|
fn attach_impact_assessment(report : StructuredReport) -> StructuredReport {
  { ..report, impact_assessment: impact_assessment_for_events(report.events) }
}
