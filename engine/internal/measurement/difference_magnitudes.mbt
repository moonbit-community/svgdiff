///|
fn rendered_magnitude_for_difference(
  report : StructuredReport,
  difference_id : String,
) -> RenderedMagnitude? {
  for event in report.events {
    if event.atomic_difference_ids.contains(difference_id) {
      return event.rendered_outcome.magnitude
    }
  }
  None
}

///|
fn numeric_source_pair(difference : AtomicDifference) -> (Double, Double)? {
  match
    (
      parse_alignment_number(Some(difference.source_before)),
      parse_alignment_number(Some(difference.source_after)),
    ) {
    (Some(before), Some(after)) => Some((before, after))
    _ => None
  }
}

///|
pub fn symmetric_relative_delta(before : Double, after : Double) -> Double {
  let denominator = before.abs() + after.abs()
  if denominator == 0.0 {
    0.0
  } else {
    2.0 * (after - before).abs() / denominator
  }
}

///|
fn transform_translation_displacement(
  effect : TransformEffectMagnitude?,
) -> Double? {
  match effect {
    Some(TranslationEffect(value)) => Some(value.norm_css_px)
    _ => None
  }
}

///|
fn scalar_spatial_parameter(property : String) -> Bool {
  match property {
    "x"
    | "y"
    | "cx"
    | "cy"
    | "x1"
    | "y1"
    | "x2"
    | "y2"
    | "width"
    | "height"
    | "rx"
    | "ry"
    | "r"
    | "stroke-width"
    | "stroke-dashoffset" => true
    _ => false
  }
}

///|
fn difference_parameter_property(difference : AtomicDifference) -> String? {
  match difference.source_fact_before {
    Some(fact) => Some(fact.property)
    None => difference.source_fact_after.map(fact => fact.property)
  }
}

///|
fn alignment_for_difference(
  report : StructuredReport,
  difference : AtomicDifference,
) -> SubjectAlignment? {
  match difference.subject_alignment_id {
    Some(id) =>
      for alignment in report.subject_alignments {
        if alignment.id == id {
          return Some(alignment)
        }
      } nobreak {
        None
      }
    None => None
  }
}

///|
fn parameter_directional_css_scale(
  matrix : AffineTransform,
  direction : SvgLengthDirection,
) -> Double {
  if direction == Horizontal {
    @math.hypot(matrix.a, matrix.b)
  } else if direction == Vertical {
    @math.hypot(matrix.c, matrix.d)
  } else {
    matrix.max_linear_scale()
  }
}

///|
fn parameter_scales_equal(left : Double, right : Double) -> Bool {
  (left - right).abs() <= 1.0e-12 * left.abs().max(right.abs()).max(1.0)
}

///|
fn directional_parameter_mappings_equal(
  before : AffineTransform,
  after : AffineTransform,
  direction : SvgLengthDirection,
) -> Bool {
  if direction == Horizontal {
    parameter_scales_equal(before.a, after.a) &&
    parameter_scales_equal(before.b, after.b)
  } else if direction == Vertical {
    parameter_scales_equal(before.c, after.c) &&
    parameter_scales_equal(before.d, after.d)
  } else {
    parameter_scales_equal(before.a, after.a) &&
    parameter_scales_equal(before.b, after.b) &&
    parameter_scales_equal(before.c, after.c) &&
    parameter_scales_equal(before.d, after.d)
  }
}

///|
pub fn common_parameter_directional_css_scale(
  before : AffineTransform,
  after : AffineTransform,
  direction : SvgLengthDirection,
) -> Double? {
  if directional_parameter_mappings_equal(before, after, direction) {
    Some(parameter_directional_css_scale(before, direction))
  } else {
    None
  }
}

///|
fn uniform_linear_css_scale(matrix : AffineTransform) -> Double? {
  let maximum = matrix.max_linear_scale()
  if maximum == 0.0 {
    return Some(0.0)
  }
  let determinant = (matrix.a * matrix.d - matrix.b * matrix.c).abs()
  let minimum = determinant / maximum
  if parameter_scales_equal(maximum, minimum) {
    Some(maximum)
  } else {
    None
  }
}

///|
fn scalar_parameter_css_scale(
  subject : SourceSubject,
  property : String,
) -> Double? {
  if (property == "stroke-width" || property == "stroke-dashoffset") &&
    subject.stroke_non_scaling {
    return Some(1.0)
  }
  let matrix = subject.cumulative_transform
  if property == "stroke-width" || property == "stroke-dashoffset" {
    uniform_linear_css_scale(matrix)
  } else {
    Some(
      parameter_directional_css_scale(
        matrix,
        basic_shape_length_direction(property),
      ),
    )
  }
}

///|
pub fn common_scalar_parameter_css_scale(
  before : SourceSubject,
  after : SourceSubject,
  property : String,
) -> Double? {
  match
    (
      scalar_parameter_css_scale(before, property),
      scalar_parameter_css_scale(after, property),
    ) {
    (Some(before_scale), Some(after_scale)) =>
      if parameter_scales_equal(before_scale, after_scale) {
        Some(before_scale)
      } else {
        None
      }
    _ => None
  }
}

///|
fn scalar_parameter_css_mappings_equal(
  before : SourceSubject,
  after : SourceSubject,
  property : String,
) -> Bool {
  if property == "stroke-width" || property == "stroke-dashoffset" {
    if before.stroke_non_scaling != after.stroke_non_scaling {
      return false
    }
    match
      (
        scalar_parameter_css_scale(before, property),
        scalar_parameter_css_scale(after, property),
      ) {
      (Some(before_scale), Some(after_scale)) =>
        parameter_scales_equal(before_scale, after_scale)
      _ => false
    }
  } else {
    directional_parameter_mappings_equal(
      before.cumulative_transform,
      after.cumulative_transform,
      basic_shape_length_direction(property),
    )
  }
}

///|
fn entity_characteristic_size_from_bounds(
  bounds_values : Array[CssBounds?],
) -> Double? {
  let mut characteristic_size = 0.0
  for bounds_value in bounds_values {
    match bounds_value {
      Some(bounds) =>
        characteristic_size = characteristic_size.max(
          @math.hypot(bounds.width, bounds.height),
        )
      None => ()
    }
  }
  if characteristic_size > 0.0 {
    Some(characteristic_size)
  } else {
    None
  }
}

///|
pub fn parameter_entity_fraction_from_bounds(
  css : Double,
  bounds_values : Array[CssBounds?],
) -> Double? {
  entity_characteristic_size_from_bounds(bounds_values).map(size => css / size)
}

///|
fn entity_characteristic_size(
  report : StructuredReport,
  difference : AtomicDifference,
  before_subjects : Array[SourceSubject],
  after_subjects : Array[SourceSubject],
) -> Double? {
  guard difference.subject_role == "entity" else { return None }
  guard alignment_for_difference(report, difference) is Some(alignment) else {
    return None
  }
  let subjects = subjects_for_references(before_subjects, alignment.before) +
    subjects_for_references(after_subjects, alignment.after)
  guard !subjects.is_empty() else { return None }
  let bounds_values : Array[CssBounds?] = []
  for subject in subjects {
    bounds_values.push(source_subject_bounds(subject))
  }
  entity_characteristic_size_from_bounds(bounds_values)
}

///|
fn entity_parameter_scales(
  report : StructuredReport,
  difference : AtomicDifference,
  parameter_abs : Double?,
  before_subjects : Array[SourceSubject],
  after_subjects : Array[SourceSubject],
) -> (Double?, Double?) {
  guard difference.subject_role == "entity" else { return (None, None) }
  guard difference_parameter_property(difference) is Some(property) &&
    scalar_spatial_parameter(property) else {
    return (None, None)
  }
  guard parameter_abs is Some(parameter_abs) else { return (None, None) }
  guard alignment_for_difference(report, difference) is Some(alignment) else {
    return (None, None)
  }
  let before = subjects_for_references(before_subjects, alignment.before)
  let after = subjects_for_references(after_subjects, alignment.after)
  let subjects = before + after
  guard !subjects.is_empty() &&
    subjects.all(subject => subject.transform_complete) else {
    return (None, None)
  }
  let mut scale : Double? = None
  let mut reference_subject : SourceSubject? = None
  for subject in subjects {
    guard scalar_parameter_css_scale(subject, property) is Some(subject_scale) else {
      return (None, None)
    }
    match reference_subject {
      Some(reference) if !scalar_parameter_css_mappings_equal(
          reference, subject, property,
        ) => return (None, None)
      None => {
        reference_subject = Some(subject)
        scale = Some(subject_scale)
      }
      _ => ()
    }
  }
  guard scale is Some(scale) else { return (None, None) }
  let css = parameter_abs * scale
  (
    Some(css),
    entity_characteristic_size(
      report, difference, before_subjects, after_subjects,
    ).map(characteristic_size => css / characteristic_size),
  )
}

///|
priv struct IsolatedPaintCacheEntry {
  alignment_id : String
  measurements : IsolatedPaintMeasurements?
}

///|
priv struct IsolatedPaintMeasurementCache {
  mut comparisons : Int
  mut raster_pixels : Int
  entries : Array[IsolatedPaintCacheEntry]
}

///|
fn IsolatedPaintMeasurementCache::new() -> IsolatedPaintMeasurementCache {
  { comparisons: 0, raster_pixels: 0, entries: [] }
}

///|
fn boundary_isolated_paint_supported(
  subject : SourceSubject,
  property : String,
) -> Bool {
  match subject_value(subject, property) {
    Some(value) => value.find("url(") is None
    None => true
  }
}

///|
fn boundary_isolation_supported(subject : SourceSubject) -> Bool {
  subject.geometry_complete &&
  subject.stroke_complete &&
  subject.transform_complete &&
  subject.resource_owner_id is None &&
  subject.clip_complete &&
  subject.clip_resource_id is None &&
  subject.mask_complete &&
  subject.mask_resource_id is None &&
  subject.marker_complete &&
  !subject.marker_active &&
  (subject.kind != "path" || subject.path_data_complete) &&
  boundary_isolated_paint_supported(subject, "fill") &&
  boundary_isolated_paint_supported(subject, "stroke") &&
  (match subject_value(subject, "filter") {
    Some(value) => value == "none"
    None => true
  })
}

///|
fn IsolatedPaintMeasurementCache::measure(
  self : IsolatedPaintMeasurementCache,
  alignment_id : String,
  before : Array[SourceSubject],
  after : Array[SourceSubject],
  profile : ComparisonProfile,
) -> IsolatedPaintMeasurements? {
  for entry in self.entries {
    if entry.alignment_id == alignment_id {
      return entry.measurements
    }
  }
  let pixels = profile.viewport_width * profile.viewport_height
  let work_pixels = pixels * 2
  let measurements = if before.is_empty() ||
    after.is_empty() ||
    !before.all(boundary_isolation_supported) ||
    !after.all(boundary_isolation_supported) ||
    !isolated_render_budget_allows(self.comparisons, self.raster_pixels, pixels) {
    None
  } else {
    self.comparisons += 1
    self.raster_pixels += work_pixels
    isolated_subjects_painted_measurements(before, after, profile)
  }
  self.entries.push({ alignment_id, measurements })
  measurements
}

///|
fn isolated_paint_measurements_for_difference(
  report : StructuredReport,
  difference : AtomicDifference,
  before_subjects : Array[SourceSubject],
  after_subjects : Array[SourceSubject],
  cache : IsolatedPaintMeasurementCache,
) -> IsolatedPaintMeasurements? {
  guard difference.subject_role == "entity" &&
    difference.computed_relation.status == "different" &&
    difference.domain.find("presence.") != Some(0) &&
    difference.domain != "presence" &&
    difference.domain.find("geometry.path.") != Some(0) else {
    return None
  }
  guard alignment_for_difference(report, difference) is Some(alignment) else {
    return None
  }
  cache.measure(
    alignment.id,
    subjects_for_references(before_subjects, alignment.before),
    subjects_for_references(after_subjects, alignment.after),
    report.profile,
  )
}

///|
fn difference_magnitude(
  report : StructuredReport,
  difference : AtomicDifference,
  before_subjects : Array[SourceSubject],
  after_subjects : Array[SourceSubject],
  isolated_paint_cache : IsolatedPaintMeasurementCache,
) -> DifferenceMagnitude {
  let parameter_delta = match difference.parameter_delta_css_px {
    Some(delta) => Some(delta)
    None =>
      match difference.magnitude.parameter_signed_user_units {
        Some(delta) => Some(delta)
        None =>
          match numeric_source_pair(difference) {
            Some((before, after)) => Some(after - before)
            None => None
          }
      }
  }
  let parameter_abs = match parameter_delta {
    Some(delta) => Some(delta.abs())
    None => None
  }
  let symmetric_relative = match difference.magnitude.symmetric_relative {
    Some(value) => Some(value)
    None =>
      match numeric_source_pair(difference) {
        Some((before, after)) => Some(symmetric_relative_delta(before, after))
        None => None
      }
  }
  let geometry = difference.domain.find("geometry.") == Some(0)
  let path_geometry = difference.domain.find("geometry.path.") == Some(0)
  let transform_translation = transform_translation_displacement(
    difference.magnitude.transform_effect,
  )
  let viewport_diagonal = (report.profile.viewport_width.to_double() *
  report.profile.viewport_width.to_double() +
  report.profile.viewport_height.to_double() *
  report.profile.viewport_height.to_double()).sqrt()
  let rendered = rendered_magnitude_for_difference(report, difference.id)
  let isolated_paint_measurements = isolated_paint_measurements_for_difference(
    report, difference, before_subjects, after_subjects, isolated_paint_cache,
  )
  let painted_boundary_displacement = match
    difference.magnitude.painted_boundary_displacement {
    Some(distribution) => Some(distribution)
    None if geometry =>
      match isolated_paint_measurements {
        Some(measurements) => measurements.boundary_displacement
        None => None
      }
    None => None
  }
  let painted_coverage_difference = match
    difference.magnitude.painted_coverage_difference {
    Some(coverage) => Some(coverage)
    None =>
      isolated_paint_measurements.map(measurements => {
        measurements.coverage_difference
      })
  }
  let (entity_parameter_css_px, entity_parameter_fraction) = entity_parameter_scales(
    report, difference, parameter_abs, before_subjects, after_subjects,
  )
  let translation_entity_fraction = match transform_translation {
    Some(css) =>
      entity_characteristic_size(
        report, difference, before_subjects, after_subjects,
      ).map(characteristic_size => css / characteristic_size)
    None => None
  }
  let parameter_abs_css_px = match difference.magnitude.parameter_abs_css_px {
    Some(value) => Some(value)
    None if entity_parameter_css_px is Some(_) => entity_parameter_css_px
    None if transform_translation is Some(_) => transform_translation
    None => None
  }
  {
    parameter_abs_user_units: parameter_abs,
    parameter_signed_user_units: parameter_delta,
    symmetric_relative,
    parameter_abs_css_px,
    parameter_viewport_fraction: parameter_abs_css_px.map(value => {
      value / viewport_diagonal
    }),
    parameter_entity_fraction: match
      difference.magnitude.parameter_entity_fraction {
      Some(value) => Some(value)
      None if translation_entity_fraction is Some(_) =>
        translation_entity_fraction
      None => entity_parameter_fraction
    },
    geometry_displacement_css_px: if transform_translation is Some(_) {
      transform_translation
    } else if path_geometry {
      difference.magnitude.geometry_displacement_css_px
    } else if difference.magnitude.geometry_displacement_css_px is Some(_) {
      difference.magnitude.geometry_displacement_css_px
    } else {
      None
    },
    painted_boundary_displacement,
    painted_coverage_difference,
    geometry_viewport_fraction: if geometry {
      let displacement = if transform_translation is Some(_) {
        transform_translation
      } else if path_geometry {
        difference.magnitude.geometry_displacement_css_px
      } else if difference.magnitude.geometry_displacement_css_px is Some(_) {
        difference.magnitude.geometry_displacement_css_px
      } else {
        None
      }
      match displacement {
        Some(value) => Some(value / viewport_diagonal)
        None => None
      }
    } else {
      None
    },
    presence_painted_viewport_fraction: match difference.presence_magnitude {
      Some(presence) => Some(presence.painted_viewport_fraction)
      None => None
    },
    raster_changed_pixel_fraction: match rendered {
      Some(rendered) => Some(rendered.changed_pixel_fraction)
      None => None
    },
    raster_rgba8_rmse: match rendered {
      Some(rendered) => Some(rendered.rgba8_rmse)
      None => None
    },
    raster_linear_premultiplied_rgba_rmse: match rendered {
      Some(rendered) => Some(rendered.linear_premultiplied_rgba_rmse)
      None => None
    },
    intrinsic_raster: difference.magnitude.intrinsic_raster,
    transform_effect: difference.magnitude.transform_effect,
  }
}

///|
fn push_measurement(components : Array[Double], value : Double?) -> Unit {
  match value {
    Some(value) => components.push(value)
    None => ()
  }
}

///|
fn ordering_for_magnitude(
  domain : String,
  magnitude : DifferenceMagnitude,
) -> DomainOrdering {
  let components : Array[Double] = []
  match (domain, magnitude.transform_effect) {
    ("geometry.transform.translation", Some(TranslationEffect(value))) => {
      components.push(value.norm_css_px)
      push_measurement(components, magnitude.geometry_viewport_fraction)
      push_measurement(components, magnitude.raster_changed_pixel_fraction)
    }
    ("geometry.transform.rotation", Some(RotationEffect(value))) => {
      components.push(value.abs_delta_degrees)
      push_measurement(components, magnitude.raster_changed_pixel_fraction)
    }
    ("geometry.transform.scale", Some(ScaleEffect(value))) => {
      components.push(value.max_abs_delta)
      push_measurement(components, magnitude.raster_changed_pixel_fraction)
    }
    ("geometry.transform.skew", Some(SkewEffect(value))) => {
      components.push(value.abs_delta_degrees)
      push_measurement(components, magnitude.raster_changed_pixel_fraction)
    }
    _ =>
      if domain == "resource.image.content" {
        match magnitude.intrinsic_raster {
          Some(value) => {
            push_measurement(components, value.linear_premultiplied_rgba_rmse)
            push_measurement(components, value.rgba8_rmse)
            push_measurement(components, value.changed_pixel_fraction)
          }
          None => ()
        }
      } else if domain.find("geometry.") == Some(0) {
        push_measurement(components, magnitude.geometry_displacement_css_px)
        push_measurement(components, magnitude.geometry_viewport_fraction)
        push_measurement(components, magnitude.raster_changed_pixel_fraction)
      } else if domain.find("paint.") == Some(0) {
        push_measurement(
          components,
          magnitude.raster_linear_premultiplied_rgba_rmse,
        )
        push_measurement(components, magnitude.raster_rgba8_rmse)
        push_measurement(components, magnitude.raster_changed_pixel_fraction)
      } else if domain.find("presence.") == Some(0) || domain == "presence" {
        push_measurement(
          components,
          magnitude.presence_painted_viewport_fraction,
        )
        push_measurement(components, magnitude.raster_changed_pixel_fraction)
      } else {
        push_measurement(components, magnitude.raster_changed_pixel_fraction)
        push_measurement(
          components,
          magnitude.raster_linear_premultiplied_rgba_rmse,
        )
        push_measurement(components, magnitude.raster_rgba8_rmse)
      }
  }
  { policy_id: "v2_domain_lexicographic", components }
}

///|
fn compare_ordering_components(
  left : Array[Double],
  right : Array[Double],
) -> Int {
  let shared = left.length().min(right.length())
  for index in 0..<shared {
    if left[index] > right[index] {
      return -1
    }
    if left[index] < right[index] {
      return 1
    }
  }
  right.length() - left.length()
}

///|
fn difference_rank(differences : Array[AtomicDifference], id : String) -> Int {
  for index, difference in differences {
    if difference.id == id {
      return index
    }
  }
  differences.length()
}

///|
pub fn attach_difference_magnitudes(
  report : StructuredReport,
  before_svg : String,
  after_svg : String,
) -> StructuredReport {
  let before_subjects = extract_source_subjects_with_profile_or_raise(
    before_svg,
    report.profile,
  ) catch {
    _ => []
  }
  let after_subjects = extract_source_subjects_with_profile_or_raise(
    after_svg,
    report.profile,
  ) catch {
    _ => []
  }
  let measured : Array[AtomicDifference] = []
  let domain_order : Array[String] = []
  let isolated_paint_cache = IsolatedPaintMeasurementCache::new()
  for difference in report.atomic_differences {
    if !domain_order.contains(difference.domain) {
      domain_order.push(difference.domain)
    }
    let magnitude = difference_magnitude(
      report, difference, before_subjects, after_subjects, isolated_paint_cache,
    )
    let evidence_layers = difference.evidence_layers.copy()
    match magnitude.painted_boundary_displacement {
      Some(boundary) if boundary.max_css_px > 0.0 &&
        !evidence_layers.contains("rendered_evidence") =>
        evidence_layers.push("rendered_evidence")
      _ => ()
    }
    match magnitude.painted_coverage_difference {
      Some(coverage) if coverage.fraction > 0.0 &&
        !evidence_layers.contains("rendered_evidence") =>
        evidence_layers.push("rendered_evidence")
      _ => ()
    }
    measured.push({
      ..difference,
      magnitude,
      evidence_layers,
      domain_ordering: ordering_for_magnitude(difference.domain, magnitude),
    })
  }
  let differences : Array[AtomicDifference] = []
  for domain in domain_order {
    let same_domain = [
      for difference in measured if difference.domain == domain => difference
    ]
    same_domain.sort_by(fn(left, right) {
      let ordering = compare_ordering_components(
        left.domain_ordering.components,
        right.domain_ordering.components,
      )
      if ordering != 0 {
        ordering
      } else {
        left.id.compare(right.id)
      }
    })
    differences.push_iter(same_domain.iter())
  }
  let events : Array[VisualEvent] = []
  for event in report.events {
    let ids = event.atomic_difference_ids.copy()
    ids.sort_by(fn(left, right) {
      difference_rank(differences, left) - difference_rank(differences, right)
    })
    events.push({ ..event, atomic_difference_ids: ids })
  }
  { ..report, atomic_differences: differences, events }
}
