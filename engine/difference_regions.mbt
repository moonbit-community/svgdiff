///|
priv struct CssBounds {
  x : Double
  y : Double
  width : Double
  height : Double
}

///|
priv enum DifferenceRegionExtraction {
  Regions(Array[DifferenceRegion])
  RegionLimitExceeded
}

///|
priv enum DifferenceRegionAttachment {
  RegionsAttached(StructuredReport)
  AttachmentRegionLimitExceeded
}

///|
fn union_bounds(left : CssBounds?, right : CssBounds?) -> CssBounds? {
  match (left, right) {
    (None, None) => None
    (Some(bounds), None) | (None, Some(bounds)) => Some(bounds)
    (Some(left), Some(right)) => {
      let min_x = left.x.min(right.x)
      let min_y = left.y.min(right.y)
      let max_x = (left.x + left.width).max(right.x + right.width)
      let max_y = (left.y + left.height).max(right.y + right.height)
      Some({ x: min_x, y: min_y, width: max_x - min_x, height: max_y - min_y })
    }
  }
}

///|
fn bounds_number(subject : SourceSubject, property : String) -> Double? {
  parse_alignment_number(subject_value(subject, property))
}

///|
fn source_subject_bounds(subject : SourceSubject) -> CssBounds? {
  match subject.kind {
    "rect" =>
      match
        (bounds_number(subject, "width"), bounds_number(subject, "height")) {
        (Some(width), Some(height)) =>
          Some({
            x: bounds_number(subject, "x").unwrap_or(0.0),
            y: bounds_number(subject, "y").unwrap_or(0.0),
            width,
            height,
          })
        _ => None
      }
    "circle" =>
      match bounds_number(subject, "r") {
        Some(radius) => {
          let cx = bounds_number(subject, "cx").unwrap_or(0.0)
          let cy = bounds_number(subject, "cy").unwrap_or(0.0)
          Some({
            x: cx - radius,
            y: cy - radius,
            width: radius * 2.0,
            height: radius * 2.0,
          })
        }
        _ => None
      }
    "ellipse" =>
      match (bounds_number(subject, "rx"), bounds_number(subject, "ry")) {
        (Some(rx), Some(ry)) => {
          let cx = bounds_number(subject, "cx").unwrap_or(0.0)
          let cy = bounds_number(subject, "cy").unwrap_or(0.0)
          Some({ x: cx - rx, y: cy - ry, width: rx * 2.0, height: ry * 2.0 })
        }
        _ => None
      }
    "line" => {
      let x1 = bounds_number(subject, "x1").unwrap_or(0.0)
      let y1 = bounds_number(subject, "y1").unwrap_or(0.0)
      let x2 = bounds_number(subject, "x2").unwrap_or(0.0)
      let y2 = bounds_number(subject, "y2").unwrap_or(0.0)
      Some({
        x: x1.min(x2),
        y: y1.min(y2),
        width: (x2 - x1).abs(),
        height: (y2 - y1).abs(),
      })
    }
    _ => None
  }
}

///|
fn subjects_bounds(subjects : Array[SourceSubject]) -> CssBounds? {
  let mut bounds : CssBounds? = None
  for subject in subjects {
    bounds = union_bounds(bounds, source_subject_bounds(subject))
  }
  bounds
}

///|
fn alignment_bounds(
  alignment : SubjectAlignment,
  before : Array[SourceSubject],
  after : Array[SourceSubject],
) -> CssBounds? {
  union_bounds(
    subjects_bounds(subjects_for_references(before, alignment.before)),
    subjects_bounds(subjects_for_references(after, alignment.after)),
  )
}

///|
fn pixels_differ(before : @svg.Image, after : @svg.Image, index : Int) -> Bool {
  let left = before.pixels[index]
  let right = after.pixels[index]
  left.r != right.r ||
  left.g != right.g ||
  left.b != right.b ||
  left.a != right.a
}

///|
fn pixel_difference_regions(
  before : @svg.Image,
  after : @svg.Image,
  max_regions : Int,
) -> DifferenceRegionExtraction {
  let width = before.width
  let height = before.height
  if width != after.width || height != after.height {
    return Regions([])
  }
  let visited = Array::make(width * height, false)
  let regions : Array[DifferenceRegion] = []
  for start in 0..<(width * height) {
    if visited[start] || !pixels_differ(before, after, start) {
      continue
    }
    let queue : Array[Int] = [start]
    visited[start] = true
    let mut cursor = 0
    let mut min_x = start % width
    let mut max_x = min_x
    let mut min_y = start / width
    let mut max_y = min_y
    let mut changed_pixels = 0
    while cursor < queue.length() {
      let current = queue[cursor]
      cursor += 1
      changed_pixels += 1
      let x = current % width
      let y = current / width
      min_x = min_x.min(x)
      max_x = max_x.max(x)
      min_y = min_y.min(y)
      max_y = max_y.max(y)
      let neighbors : Array[Int] = []
      if x > 0 {
        neighbors.push(current - 1)
      }
      if x + 1 < width {
        neighbors.push(current + 1)
      }
      if y > 0 {
        neighbors.push(current - width)
      }
      if y + 1 < height {
        neighbors.push(current + width)
      }
      for neighbor in neighbors {
        if !visited[neighbor] && pixels_differ(before, after, neighbor) {
          visited[neighbor] = true
          queue.push(neighbor)
        }
      }
    }
    if regions.length() >= max_regions {
      return RegionLimitExceeded
    }
    regions.push({
      id: "region:pixel:\{regions.length()}",
      source: "pixel_mask",
      pixel_x: min_x,
      pixel_y: min_y,
      pixel_width: max_x - min_x + 1,
      pixel_height: max_y - min_y + 1,
      css_x: min_x.to_double(),
      css_y: min_y.to_double(),
      css_width: (max_x - min_x + 1).to_double(),
      css_height: (max_y - min_y + 1).to_double(),
      changed_pixels,
      viewport_fraction: changed_pixels.to_double() /
      (width * height).to_double(),
      cause_envelope: {
        guarantee: "not_established",
        coverage: "pending",
        fallback_scope: "comparison",
        candidate_changed_fact_ids: [],
        diagnostic_ids: [],
      },
    })
  }
  Regions(regions)
}

///|
fn pixel_in_regions(
  x : Int,
  y : Int,
  regions : Array[DifferenceRegion],
) -> Bool {
  regions.any(region => {
    x >= region.pixel_x &&
    x < region.pixel_x + region.pixel_width &&
    y >= region.pixel_y &&
    y < region.pixel_y + region.pixel_height
  })
}

///|
fn rendered_magnitude_for_regions(
  before : @svg.Image,
  after : @svg.Image,
  regions : Array[DifferenceRegion],
) -> RenderedMagnitude {
  let mut changed_pixels = 0
  let mut squared_error = 0.0
  let mut linear_squared_error = 0.0
  // The full-image membership test accepts exactly this rectangle when there
  // is one region, so restricting iteration preserves the selected pixels.
  let single_region = match regions {
    [region] => Some(region)
    _ => None
  }
  let start_x = match single_region {
    Some(region) => region.pixel_x.max(0)
    None => 0
  }
  let start_y = match single_region {
    Some(region) => region.pixel_y.max(0)
    None => 0
  }
  let end_x = match single_region {
    Some(region) => (region.pixel_x + region.pixel_width).min(before.width)
    None => before.width
  }
  let end_y = match single_region {
    Some(region) => (region.pixel_y + region.pixel_height).min(before.height)
    None => before.height
  }
  for y in start_y..<end_y {
    for x in start_x..<end_x {
      let index = y * before.width + x
      if (single_region is None && !pixel_in_regions(x, y, regions)) ||
        !pixels_differ(before, after, index) {
        continue
      }
      changed_pixels += 1
      let left = before.pixels[index]
      let right = after.pixels[index]
      squared_error += raw_rgba8_squared_error(left, right)
      linear_squared_error += linear_premultiplied_rgba_squared_error(
        left, right,
      )
    }
  }
  let total_pixels = before.pixels.length()
  {
    changed_pixels,
    changed_pixel_fraction: changed_pixels.to_double() /
    total_pixels.to_double(),
    rgba8_rmse: (squared_error / (total_pixels * 4).to_double()).sqrt(),
    linear_premultiplied_rgba_rmse: (linear_squared_error /
    (total_pixels * 4).to_double()).sqrt(),
  }
}

///|
fn regions_intersect(region : DifferenceRegion, bounds : CssBounds) -> Bool {
  region.css_x < bounds.x + bounds.width &&
  region.css_x + region.css_width > bounds.x &&
  region.css_y < bounds.y + bounds.height &&
  region.css_y + region.css_height > bounds.y
}

///|
fn computed_bounds_region(
  id : String,
  bounds : CssBounds,
  profile : ComparisonProfile,
) -> DifferenceRegion {
  let viewport_area = profile.viewport_width.to_double() *
    profile.viewport_height.to_double()
  {
    id,
    source: "computed_bounds",
    pixel_x: bounds.x.to_int(),
    pixel_y: bounds.y.to_int(),
    pixel_width: bounds.width.to_int(),
    pixel_height: bounds.height.to_int(),
    css_x: bounds.x,
    css_y: bounds.y,
    css_width: bounds.width,
    css_height: bounds.height,
    changed_pixels: 0,
    viewport_fraction: bounds.width * bounds.height / viewport_area,
    cause_envelope: {
      guarantee: "not_established",
      coverage: "pending",
      fallback_scope: "comparison",
      candidate_changed_fact_ids: [],
      diagnostic_ids: [],
    },
  }
}

///|
fn alignment_for_event(
  event : VisualEvent,
  alignments : Array[SubjectAlignment],
) -> SubjectAlignment? {
  for alignment in alignments {
    if event.primary_subject_id == alignment.id {
      return Some(alignment)
    }
    let matches_before = alignment.before.any(reference => {
      reference.authored_id == Some(event.primary_subject_id) ||
      "\{reference.kind}:\{reference.source_index}" == event.primary_subject_id
    })
    let matches_after = alignment.after.any(reference => {
      reference.authored_id == Some(event.primary_subject_id) ||
      "\{reference.kind}:\{reference.source_index}" == event.primary_subject_id
    })
    if matches_before || matches_after {
      return Some(alignment)
    }
  }
  None
}

///|
fn escape_xml_attribute(value : String) -> String {
  value
  .replace_all(old="&", new="&amp;")
  .replace_all(old="\"", new="&quot;")
  .replace_all(old="<", new="&lt;")
}

///|
fn isolated_presence_painted_pixels(
  subjects : Array[SourceSubject],
  profile : ComparisonProfile,
) -> Int? {
  if subjects.is_empty() {
    return None
  }
  let mut body = ""
  for subject in subjects {
    body += "<\{subject.kind}"
    for item in subject.values {
      let (property, value) = item
      body += " \{property}=\"\{escape_xml_attribute(value)}\""
    }
    body += "/>"
  }
  let source = "<svg width='\{profile.viewport_width}' height='\{profile.viewport_height}'>\{body}</svg>"
  let document = match
    @svg.parse_svg_document(normalize_renderer_style_precedence(source)) {
    Some(document) => document
    None => return None
  }
  let image = @svg.render_svg_document_to_image(
    document,
    profile.viewport_width,
    profile.viewport_height,
  )
  let mut painted_pixels = 0
  for pixel in image.pixels {
    if pixel.a > 0 {
      painted_pixels += 1
    }
  }
  Some(painted_pixels)
}

///|
fn generic_presence_magnitude_for_difference(
  difference : AtomicDifference,
  alignments : Array[SubjectAlignment],
  before : Array[SourceSubject],
  after : Array[SourceSubject],
  profile : ComparisonProfile,
) -> PresenceMagnitude? {
  if difference.domain.find("presence.") != Some(0) {
    return difference.presence_magnitude
  }
  let alignment_id = match difference.subject_alignment_id {
    Some(id) => id
    None => return difference.presence_magnitude
  }
  let mut alignment : SubjectAlignment? = None
  for candidate in alignments {
    if candidate.id == alignment_id {
      alignment = Some(candidate)
      break
    }
  }
  let bounds = match alignment {
    Some(alignment) =>
      match alignment_bounds(alignment, before, after) {
        Some(bounds) => bounds
        None => return difference.presence_magnitude
      }
    None => return difference.presence_magnitude
  }
  let viewport_area = profile.viewport_width.to_double() *
    profile.viewport_height.to_double()
  let entity_count = match alignment {
    Some(alignment) =>
      if difference.domain == "presence.insertion" {
        alignment.after.length()
      } else {
        alignment.before.length()
      }
    None => 0
  }
  let bounds_area = bounds.width * bounds.height
  let presence_subjects = match alignment {
    Some(alignment) =>
      if difference.domain == "presence.insertion" {
        subjects_for_references(after, alignment.after)
      } else {
        subjects_for_references(before, alignment.before)
      }
    None => return difference.presence_magnitude
  }
  let painted_pixels = match
    isolated_presence_painted_pixels(presence_subjects, profile) {
    Some(pixels) => pixels
    None => return difference.presence_magnitude
  }
  let painted_area = painted_pixels.to_double() /
    (profile.comparison_dpr * profile.comparison_dpr)
  Some({
    affected_entity_count: entity_count,
    bounds_area_css_px2: bounds_area,
    bounds_viewport_fraction: bounds_area / viewport_area,
    painted_area_css_px2: painted_area,
    painted_viewport_fraction: painted_area / viewport_area,
  })
}

///|
fn attach_difference_regions(
  report : StructuredReport,
  before_svg : String,
  after_svg : String,
  alignments : Array[SubjectAlignment],
  max_regions : Int,
  comparison_guard : ComparisonGuard,
) -> DifferenceRegionAttachment raise ComparisonInterrupted {
  comparison_guard.checkpoint()
  let before = extract_source_subjects_or_raise(before_svg) catch { _ => [] }
  let after = extract_source_subjects_or_raise(after_svg) catch { _ => [] }
  let rendered_images = match
    (
      @svg.parse_svg_document(normalize_renderer_style_precedence(before_svg)),
      @svg.parse_svg_document(normalize_renderer_style_precedence(after_svg)),
    ) {
    (Some(before_document), Some(after_document)) =>
      Some(
        (
          @svg.render_svg_document_to_image(
            before_document,
            report.profile.viewport_width,
            report.profile.viewport_height,
          ),
          @svg.render_svg_document_to_image(
            after_document,
            report.profile.viewport_width,
            report.profile.viewport_height,
          ),
        ),
      )
    _ => None
  }
  let pixel_regions = match rendered_images {
    Some((before_image, after_image)) =>
      match pixel_difference_regions(before_image, after_image, max_regions) {
        Regions(regions) => regions
        RegionLimitExceeded => return AttachmentRegionLimitExceeded
      }
    None => []
  }
  let events : Array[VisualEvent] = []
  let mut attached_region_count = 0
  for event in report.events {
    comparison_guard.checkpoint()
    let bounds = match alignment_for_event(event, alignments) {
      Some(alignment) => alignment_bounds(alignment, before, after)
      None => None
    }
    let regions : Array[DifferenceRegion] = []
    if event.rendered_outcome.status == "computed" {
      match bounds {
        Some(bounds) =>
          for region in pixel_regions {
            if regions_intersect(region, bounds) {
              if attached_region_count >= max_regions {
                return AttachmentRegionLimitExceeded
              }
              regions.push(region)
              attached_region_count += 1
            }
          }
        None =>
          for region in pixel_regions {
            if attached_region_count >= max_regions {
              return AttachmentRegionLimitExceeded
            }
            regions.push(region)
            attached_region_count += 1
          }
      }
    } else {
      match bounds {
        Some(bounds) => {
          if attached_region_count >= max_regions {
            return AttachmentRegionLimitExceeded
          }
          regions.push(
            computed_bounds_region(
              "region:bounds:\{event.id}",
              bounds,
              report.profile,
            ),
          )
          attached_region_count += 1
        }
        None => ()
      }
    }
    let rendered_outcome = if event.rendered_outcome.status == "computed" {
      match rendered_images {
        Some((before_image, after_image)) =>
          computed_rendered_evidence(
            rendered_magnitude_for_regions(before_image, after_image, regions),
          )
        None => event.rendered_outcome
      }
    } else {
      event.rendered_outcome
    }
    events.push({ ..event, rendered_outcome, difference_regions: regions })
  }
  let differences : Array[AtomicDifference] = []
  for difference in report.atomic_differences {
    comparison_guard.checkpoint()
    differences.push({
      ..difference,
      presence_magnitude: generic_presence_magnitude_for_difference(
        difference,
        alignments,
        before,
        after,
        report.profile,
      ),
    })
  }
  comparison_guard.checkpoint()
  RegionsAttached({ ..report, atomic_differences: differences, events })
}
