///|
fn path_staged_magnitude(
  before_subject : SourceSubject,
  after_subject : SourceSubject,
  property : String,
  source_before : String,
  source_after : String,
  parameter_delta : Double?,
  painted_measurements : IsolatedPaintMeasurements?,
) -> DifferenceMagnitude {
  let boundary_distribution = match painted_measurements {
    Some(measurements) => measurements.boundary_displacement
    None => None
  }
  let magnitude = {
    ..empty_difference_magnitude(),
    parameter_abs_user_units: parameter_delta.map(delta => delta.abs()),
    parameter_signed_user_units: parameter_delta,
    symmetric_relative: match
      (
        parse_alignment_number(Some(source_before)),
        parse_alignment_number(Some(source_after)),
      ) {
      (Some(before), Some(after)) =>
        Some(symmetric_relative_delta(before, after))
      _ => None
    },
    geometry_displacement_css_px: boundary_distribution.map(distribution => {
      distribution.max_css_px
    }),
    painted_boundary_displacement: boundary_distribution,
    painted_coverage_difference: painted_measurements.map(measurements => {
      measurements.coverage_difference
    }),
  }
  guard parameter_delta is Some(delta) &&
    before_subject.transform_complete &&
    after_subject.transform_complete else {
    return magnitude
  }
  let direction = if property.has_suffix(".x") ||
    property.has_suffix(".x1") ||
    property.has_suffix(".x2") ||
    property.has_suffix(".rx") {
    Some(@computed.SvgLengthDirection::Horizontal)
  } else if property.has_suffix(".y") ||
    property.has_suffix(".y1") ||
    property.has_suffix(".y2") ||
    property.has_suffix(".ry") {
    Some(Vertical)
  } else {
    None
  }
  guard direction is Some(direction) else { return magnitude }
  guard common_parameter_directional_css_scale(
      before_subject.cumulative_transform,
      after_subject.cumulative_transform,
      direction,
    )
    is Some(scale) else {
    return magnitude
  }
  let css = delta.abs() * scale
  {
    ..magnitude,
    parameter_abs_css_px: Some(css),
    parameter_entity_fraction: parameter_entity_fraction_from_bounds(css, [
      source_subject_bounds(before_subject),
      source_subject_bounds(after_subject),
    ]),
  }
}

///|
pub(all) struct PathBoundaryBudget {
  mut comparisons : Int
  mut raster_pixels : Int
}

///|
pub fn PathBoundaryBudget::new() -> PathBoundaryBudget {
  { comparisons: 0, raster_pixels: 0 }
}

///|
pub fn PathBoundaryBudget::measure(
  self : PathBoundaryBudget,
  before : SourceSubject,
  after : SourceSubject,
  profile : ComparisonProfile,
) -> IsolatedPaintMeasurements? {
  let pixels = profile.viewport_width * profile.viewport_height
  let work_pixels = pixels * 2
  if !isolated_render_budget_allows(
      self.comparisons,
      self.raster_pixels,
      pixels,
    ) {
    return None
  }
  self.comparisons += 1
  self.raster_pixels += work_pixels
  isolated_subjects_painted_measurements([before], [after], profile)
}

///|
fn same_path_parameter(
  before : NormalizedPathParameter,
  after : NormalizedPathParameter,
) -> Bool {
  match (before.numeric_value, after.numeric_value) {
    (Some(left), Some(right)) => left == right
    _ => before.value == after.value
  }
}

///|
fn positional_path_segment_alignment(
  before_length : Int,
  after_length : Int,
) -> Array[(Int?, Int?)] {
  let alignment : Array[(Int?, Int?)] = []
  let shared = before_length.min(after_length)
  for index in 0..<shared {
    alignment.push((Some(index), Some(index)))
  }
  for index in shared..<before_length {
    alignment.push((Some(index), None))
  }
  for index in shared..<after_length {
    alignment.push((None, Some(index)))
  }
  alignment
}

///|
fn path_segment_edit_cost(
  before : PathSegmentEvidence,
  after : PathSegmentEvidence,
) -> Int {
  if normalized_path_segment_signature(before.normalized) ==
    normalized_path_segment_signature(after.normalized) {
    0
  } else if normalized_path_segment_kind(before.normalized) ==
    normalized_path_segment_kind(after.normalized) {
    1
  } else {
    2
  }
}

///|
fn align_path_segments(
  before : Array[PathSegmentEvidence],
  after : Array[PathSegmentEvidence],
) -> Array[(Int?, Int?)] {
  let before_length = before.length()
  let after_length = after.length()
  if after_length + 1 > 65536 / (before_length + 1) {
    return positional_path_segment_alignment(before_length, after_length)
  }
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
      let substitution = path_segment_edit_cost(
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
      let substitution = path_segment_edit_cost(
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
  let alignment : Array[(Int?, Int?)] = []
  let mut index = reversed.length() - 1
  while index >= 0 {
    alignment.push(reversed[index])
    index -= 1
  }
  alignment
}

///|
fn path_segment_alignment_changed(
  before : Array[PathSegmentEvidence],
  after : Array[PathSegmentEvidence],
  alignment : Array[(Int?, Int?)],
) -> Bool {
  for pair in alignment {
    let (before_index, after_index) = pair
    match (before_index, after_index) {
      (Some(before_index), Some(after_index)) => {
        let before_segment = before[before_index]
        let after_segment = after[after_index]
        if normalized_path_segment_kind(before_segment.normalized) !=
          normalized_path_segment_kind(after_segment.normalized) ||
          before_segment.authored_command != after_segment.authored_command {
          return true
        }
        let before_parameters = normalized_path_segment_parameters(
          before_segment.normalized,
        )
        let after_parameters = normalized_path_segment_parameters(
          after_segment.normalized,
        )
        for index in 0..<before_parameters.length() {
          if !same_path_parameter(
              before_parameters[index],
              after_parameters[index],
            ) {
            return true
          }
        }
      }
      _ => return true
    }
  }
  false
}

///|
fn append_path_atomic_difference(
  alignment : SubjectAlignment,
  before_subject : SourceSubject,
  after_subject : SourceSubject,
  suffix : String,
  property : String,
  domain : String,
  source_before : String,
  source_after : String,
  before_segment : PathSegmentEvidence?,
  after_segment : PathSegmentEvidence?,
  computed_status : String,
  reason_code : String,
  parameter_delta : Double?,
  painted_measurements : IsolatedPaintMeasurements?,
  rendered_evidence_available : Bool,
  changed_facts : Array[ChangedFact],
  differences : Array[AtomicDifference],
  difference_ids : Array[String],
) -> Unit {
  let fact_id = "fact:\{alignment.id}:d:\{suffix}"
  let difference_id = "diff:\{alignment.id}:d:\{suffix}"
  let before_fact = localized_path_fact(
    source_subject_fact(before_subject, "d"),
    property,
    before_segment,
  )
  let after_fact = localized_path_fact(
    source_subject_fact(after_subject, "d"),
    property,
    after_segment,
  )
  changed_facts.push({
    id: fact_id,
    subject_id: alignment.id,
    property,
    before: before_fact,
    after: after_fact,
    affected_subject_ids: source_subject_ids([before_subject], [after_subject]),
  })
  let evidence_layers : Array[String] = ["source_semantics"]
  if computed_status == "different" {
    evidence_layers.push("computed_appearance")
  }
  if rendered_evidence_available {
    evidence_layers.push("rendered_evidence")
  }
  differences.push({
    id: difference_id,
    subject_role: "entity",
    subject_alignment_id: Some(alignment.id),
    domain,
    source_before,
    source_after,
    source_fact_before: before_fact,
    source_fact_after: after_fact,
    changed_fact_ids: [fact_id],
    evidence_layers,
    computed_relation: {
      status: computed_status,
      reason_code,
      missing_side: None,
      diagnostic_ids: [],
    },
    parameter_delta_css_px: parameter_delta,
    presence_magnitude: None,
    magnitude: path_staged_magnitude(
      before_subject, after_subject, property, source_before, source_after, parameter_delta,
      painted_measurements,
    ),
    domain_ordering: empty_domain_ordering(),
  })
  difference_ids.push(difference_id)
}

///|
fn localized_path_fact(
  fact : DeclaredVisualFact?,
  property : String,
  segment : PathSegmentEvidence?,
) -> DeclaredVisualFact? {
  match (fact, segment) {
    (Some(fact), Some(segment)) =>
      Some({
        ..fact,
        property,
        authored_value: segment.authored_value,
        declared_value: segment.authored_value.trim().to_owned(),
        source_span: {
          start_offset: segment.source_span.start_offset,
          end_offset: segment.source_span.end_offset,
        },
      })
    _ => None
  }
}

///|
pub fn append_path_geometry_differences(
  alignment : SubjectAlignment,
  before_subject : SourceSubject,
  after_subject : SourceSubject,
  profile : ComparisonProfile,
  boundary_budget : PathBoundaryBudget,
  changed_facts : Array[ChangedFact],
  differences : Array[AtomicDifference],
  difference_ids : Array[String],
) -> Unit {
  if !before_subject.path_data_complete || !after_subject.path_data_complete {
    return
  }
  let segment_alignment = align_path_segments(
    before_subject.path_segments,
    after_subject.path_segments,
  )
  if !path_segment_alignment_changed(
      before_subject.path_segments,
      after_subject.path_segments,
      segment_alignment,
    ) {
    return
  }
  let painted_measurements = boundary_budget.measure(
    before_subject, after_subject, profile,
  )
  let rendered_evidence_available = painted_measurements is Some(_)
  for position, pair in segment_alignment {
    let (before_index, after_index) = pair
    match (before_index, after_index) {
      (Some(before_index), Some(after_index)) => {
        let before_segment = before_subject.path_segments[before_index]
        let after_segment = after_subject.path_segments[after_index]
        let before_kind = normalized_path_segment_kind(
          before_segment.normalized,
        )
        let after_kind = normalized_path_segment_kind(after_segment.normalized)
        if before_kind != after_kind {
          append_path_atomic_difference(
            alignment,
            before_subject,
            after_subject,
            "segment:\{position}:structure",
            "d.segment.\{position}",
            "geometry.path.structure",
            normalized_path_segment_signature(before_segment.normalized),
            normalized_path_segment_signature(after_segment.normalized),
            Some(before_segment),
            Some(after_segment),
            "different",
            "path_segment_kinds_differ",
            None,
            painted_measurements,
            rendered_evidence_available,
            changed_facts,
            differences,
            difference_ids,
          )
          continue
        }
        if before_segment.authored_command != after_segment.authored_command {
          append_path_atomic_difference(
            alignment,
            before_subject,
            after_subject,
            "segment:\{position}:command",
            "d.segment.\{position}.command",
            "geometry.path.command",
            before_segment.authored_command,
            after_segment.authored_command,
            Some(before_segment),
            Some(after_segment),
            "equivalent",
            "same_normalized_path_segment",
            None,
            painted_measurements,
            rendered_evidence_available,
            changed_facts,
            differences,
            difference_ids,
          )
        }
        let before_parameters = normalized_path_segment_parameters(
          before_segment.normalized,
        )
        let after_parameters = normalized_path_segment_parameters(
          after_segment.normalized,
        )
        for parameter_index in 0..<before_parameters.length() {
          let before_parameter = before_parameters[parameter_index]
          let after_parameter = after_parameters[parameter_index]
          if same_path_parameter(before_parameter, after_parameter) {
            continue
          }
          let parameter_delta = match
            (before_parameter.numeric_value, after_parameter.numeric_value) {
            (Some(before_value), Some(after_value)) =>
              Some(after_value - before_value)
            _ => None
          }
          append_path_atomic_difference(
            alignment,
            before_subject,
            after_subject,
            "segment:\{position}:parameter:\{before_parameter.name}",
            "d.segment.\{position}.\{before_parameter.name}",
            "geometry.path.parameter",
            before_parameter.value,
            after_parameter.value,
            Some(before_segment),
            Some(after_segment),
            "different",
            "path_segment_parameters_differ",
            parameter_delta,
            painted_measurements,
            rendered_evidence_available,
            changed_facts,
            differences,
            difference_ids,
          )
        }
      }
      (Some(before_index), None) =>
        append_path_atomic_difference(
          alignment,
          before_subject,
          after_subject,
          "segment:\{position}:deletion",
          "d.segment.\{position}",
          "geometry.path.structure",
          normalized_path_segment_signature(
            before_subject.path_segments[before_index].normalized,
          ),
          "",
          Some(before_subject.path_segments[before_index]),
          None,
          "different",
          "path_segment_deleted",
          None,
          painted_measurements,
          rendered_evidence_available,
          changed_facts,
          differences,
          difference_ids,
        )
      (None, Some(after_index)) =>
        append_path_atomic_difference(
          alignment,
          before_subject,
          after_subject,
          "segment:\{position}:insertion",
          "d.segment.\{position}",
          "geometry.path.structure",
          "",
          normalized_path_segment_signature(
            after_subject.path_segments[after_index].normalized,
          ),
          None,
          Some(after_subject.path_segments[after_index]),
          "different",
          "path_segment_inserted",
          None,
          painted_measurements,
          rendered_evidence_available,
          changed_facts,
          differences,
          difference_ids,
        )
      _ => ()
    }
  }
}
