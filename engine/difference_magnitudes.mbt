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
fn symmetric_relative_delta(before : Double, after : Double) -> Double {
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
fn difference_magnitude(
  report : StructuredReport,
  difference : AtomicDifference,
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
  let positional_geometry = difference.domain == "geometry.position" ||
    difference.domain == "geometry.size"
  let transform_translation = transform_translation_displacement(
    difference.magnitude.transform_effect,
  )
  let viewport_diagonal = (report.profile.viewport_width.to_double() *
  report.profile.viewport_width.to_double() +
  report.profile.viewport_height.to_double() *
  report.profile.viewport_height.to_double()).sqrt()
  let rendered = rendered_magnitude_for_difference(report, difference.id)
  {
    parameter_abs_user_units: parameter_abs,
    parameter_signed_user_units: parameter_delta,
    symmetric_relative,
    geometry_displacement_css_px: if transform_translation is Some(_) {
      transform_translation
    } else if path_geometry {
      difference.magnitude.geometry_displacement_css_px
    } else if difference.magnitude.geometry_displacement_css_px is Some(_) {
      difference.magnitude.geometry_displacement_css_px
    } else if positional_geometry {
      parameter_abs
    } else {
      None
    },
    geometry_viewport_fraction: if geometry {
      let displacement = if transform_translation is Some(_) {
        transform_translation
      } else if path_geometry {
        difference.magnitude.geometry_displacement_css_px
      } else if difference.magnitude.geometry_displacement_css_px is Some(_) {
        difference.magnitude.geometry_displacement_css_px
      } else if positional_geometry {
        parameter_abs
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
fn attach_difference_magnitudes(report : StructuredReport) -> StructuredReport {
  let measured : Array[AtomicDifference] = []
  let domain_order : Array[String] = []
  for difference in report.atomic_differences {
    if !domain_order.contains(difference.domain) {
      domain_order.push(difference.domain)
    }
    let magnitude = difference_magnitude(report, difference)
    measured.push({
      ..difference,
      magnitude,
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
