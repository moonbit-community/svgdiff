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
fn intersect_bounds(left : CssBounds, right : CssBounds) -> CssBounds? {
  let min_x = left.x.max(right.x)
  let min_y = left.y.max(right.y)
  let max_x = (left.x + left.width).min(right.x + right.width)
  let max_y = (left.y + left.height).min(right.y + right.height)
  if max_x <= min_x || max_y <= min_y {
    None
  } else {
    Some({ x: min_x, y: min_y, width: max_x - min_x, height: max_y - min_y })
  }
}

///|
fn bounds_number(subject : SourceSubject, property : String) -> Double? {
  parse_alignment_number(subject_value(subject, property))
}

///|
fn points_bounds(subject : SourceSubject) -> CssBounds? {
  let (points, complete, odd) = parse_shape_points(
    subject_value(subject, "points").unwrap_or(""),
  )
  if !complete || odd || points.length() < 2 {
    return None
  }
  let mut min_x = points[0]
  let mut max_x = points[0]
  let mut min_y = points[1]
  let mut max_y = points[1]
  let mut index = 2
  while index + 1 < points.length() {
    min_x = min_x.min(points[index])
    max_x = max_x.max(points[index])
    min_y = min_y.min(points[index + 1])
    max_y = max_y.max(points[index + 1])
    index += 2
  }
  Some({ x: min_x, y: min_y, width: max_x - min_x, height: max_y - min_y })
}

///|
fn path_control_hull_bounds(subject : SourceSubject) -> CssBounds? {
  if !subject.path_data_complete || subject.path_segments.is_empty() {
    return None
  }
  let mut min_x = 1.7976931348623157e308
  let mut min_y = 1.7976931348623157e308
  let mut max_x = -1.7976931348623157e308
  let mut max_y = -1.7976931348623157e308
  let mut point_count = 0
  let mut drawable = false
  fn include_point(x : Double, y : Double) -> Unit {
    min_x = min_x.min(x)
    min_y = min_y.min(y)
    max_x = max_x.max(x)
    max_y = max_y.max(y)
    point_count += 1
  }
  for segment in subject.path_segments {
    match segment.normalized {
      MoveTo(x, y) => include_point(x, y)
      LineTo(x, y) => {
        include_point(x, y)
        drawable = true
      }
      CubicTo(x1, y1, x2, y2, x, y) => {
        include_point(x1, y1)
        include_point(x2, y2)
        include_point(x, y)
        drawable = true
      }
      QuadraticTo(x1, y1, x, y) => {
        include_point(x1, y1)
        include_point(x, y)
        drawable = true
      }
      ArcTo(_, _, _, _, _, _, _) => return None
      ClosePath => drawable = true
    }
  }
  if !drawable || point_count == 0 {
    None
  } else {
    Some({ x: min_x, y: min_y, width: max_x - min_x, height: max_y - min_y })
  }
}

///|
fn inflate_bounds(bounds : CssBounds, expansion : Double) -> CssBounds {
  {
    x: bounds.x - expansion,
    y: bounds.y - expansion,
    width: bounds.width + expansion * 2.0,
    height: bounds.height + expansion * 2.0,
  }
}

///|
fn transform_bounds(
  bounds : CssBounds,
  transform : AffineTransform,
) -> CssBounds {
  let points = [
    (bounds.x, bounds.y),
    (bounds.x + bounds.width, bounds.y),
    (bounds.x, bounds.y + bounds.height),
    (bounds.x + bounds.width, bounds.y + bounds.height),
  ]
  let mut min_x = 1.7976931348623157e308
  let mut min_y = 1.7976931348623157e308
  let mut max_x = -1.7976931348623157e308
  let mut max_y = -1.7976931348623157e308
  for point in points {
    let (x, y) = point
    let transformed_x = transform.a * x + transform.c * y + transform.e
    let transformed_y = transform.b * x + transform.d * y + transform.f
    min_x = min_x.min(transformed_x)
    min_y = min_y.min(transformed_y)
    max_x = max_x.max(transformed_x)
    max_y = max_y.max(transformed_y)
  }
  { x: min_x, y: min_y, width: max_x - min_x, height: max_y - min_y }
}

///|
fn source_subject_geometry_bounds(subject : SourceSubject) -> CssBounds? {
  if !subject.renders_geometry {
    if !subject.stroke_active {
      return None
    }
  }
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
    "polyline" | "polygon" => points_bounds(subject)
    "path" => path_control_hull_bounds(subject)
    _ => None
  }
}

///|
fn source_subject_unclipped_bounds(subject : SourceSubject) -> CssBounds? {
  let geometry_bounds = match source_subject_geometry_bounds(subject) {
    Some(bounds) => Some(bounds)
    None => None
  }
  let painted_geometry = match geometry_bounds {
    Some(bounds) if !subject.stroke_active =>
      Some(transform_bounds(bounds, subject.cumulative_transform))
    Some(bounds) if subject.stroke_non_scaling =>
      Some(
        inflate_bounds(
          transform_bounds(bounds, subject.cumulative_transform),
          subject.stroke_conservative_expansion,
        ),
      )
    Some(bounds) =>
      Some(
        transform_bounds(
          inflate_bounds(bounds, subject.stroke_conservative_expansion),
          subject.cumulative_transform,
        ),
      )
    None => None
  }
  union_bounds(painted_geometry, marker_subject_bounds(subject))
}

///|
fn source_subject_bounds(subject : SourceSubject) -> CssBounds? {
  match subject.mask_effect_bounds {
    Some(bounds) => return Some(bounds)
    None if subject.mask_complete && subject.mask_resource_id is Some(_) =>
      return None
    _ => ()
  }
  match subject.clip_effect_bounds {
    Some(bounds) => Some(bounds)
    None if subject.clip_complete && subject.clip_resource_id is Some(_) => None
    None if subject.clip_complete => source_subject_unclipped_bounds(subject)
    None => source_subject_unclipped_bounds(subject)
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
fn embedded_image_alignment_bounds(
  alignment : SubjectAlignment,
  before : Array[EmbeddedImageSubject],
  after : Array[EmbeddedImageSubject],
) -> CssBounds? {
  union_bounds(
    embedded_image_subject_for_reference(before, alignment.before)
    .map(embedded_image_subject_bounds)
    .unwrap_or(None),
    embedded_image_subject_for_reference(after, alignment.after)
    .map(embedded_image_subject_bounds)
    .unwrap_or(None),
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
      if x > 0 && y > 0 {
        neighbors.push(current - width - 1)
      }
      if x + 1 < width && y > 0 {
        neighbors.push(current - width + 1)
      }
      if x > 0 && y + 1 < height {
        neighbors.push(current + width - 1)
      }
      if x + 1 < width && y + 1 < height {
        neighbors.push(current + width + 1)
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
  if event.id.find(":transform") is Some(_) {
    // Transform-aware bounds are a later localization item. Until then the
    // complete scene mask is conservative; clipping to untransformed bounds
    // would silently discard vacated or newly occupied pixels.
    return None
  }
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
fn marker_resource_bounds_for_event(
  event : VisualEvent,
  before : Array[SourceSubject],
  after : Array[SourceSubject],
) -> CssBounds? {
  if !event.id.has_prefix("event:marker-resource:") {
    return None
  }
  let suffix = event.id.view(start_offset="event:marker-resource:".length())
  let resource_id = match suffix.find(":presence") {
    Some(offset) => suffix.view(end_offset=offset).to_owned()
    None => suffix.to_owned()
  }
  let mut bounds : CssBounds? = None
  for subject in before {
    for placement in subject.marker_placements {
      if placement.resource_id == resource_id {
        bounds = union_bounds(bounds, Some(placement.bounds))
      }
    }
  }
  for subject in after {
    for placement in subject.marker_placements {
      if placement.resource_id == resource_id {
        bounds = union_bounds(bounds, Some(placement.bounds))
      }
    }
  }
  bounds
}

///|
fn group_opacity_subject_matches(
  subject : SourceSubject,
  subject_id : String,
) -> Bool {
  if source_subject_id(subject) == subject_id ||
    subject.reference.authored_id == Some(subject_id) {
    return true
  }
  match subject.reference.instance_context {
    Some(context) =>
      context.definition_subject_id == subject_id ||
      context.use_path.contains(subject_id)
    None => false
  }
}

///|
fn group_opacity_event_bounds(
  event : VisualEvent,
  report : StructuredReport,
  before : Array[SourceSubject],
  after : Array[SourceSubject],
) -> CssBounds? {
  let affected_subject_ids : Array[String] = []
  for difference in report.atomic_differences {
    if difference.domain != "compositing.opacity" ||
      !event.atomic_difference_ids.contains(difference.id) {
      continue
    }
    for fact_id in difference.changed_fact_ids {
      for fact in report.changed_facts {
        if fact.id == fact_id {
          for subject_id in fact.affected_subject_ids {
            if !affected_subject_ids.contains(subject_id) {
              affected_subject_ids.push(subject_id)
            }
          }
        }
      }
    }
  }
  if affected_subject_ids.is_empty() {
    return None
  }
  let subjects : Array[SourceSubject] = []
  for subject in before + after {
    if affected_subject_ids.any(subject_id => {
        group_opacity_subject_matches(subject, subject_id)
      }) {
      subjects.push(subject)
    }
  }
  subjects_bounds(subjects)
}

///|
fn clip_resource_event_bounds(
  event : VisualEvent,
  report : StructuredReport,
  before : Array[SourceSubject],
  after : Array[SourceSubject],
) -> CssBounds? {
  let keys : Array[String] = []
  for difference_id in event.atomic_difference_ids {
    for difference in report.atomic_differences {
      if difference.id == difference_id &&
        difference.domain.has_prefix("resource.clip.") {
        push_unique(keys, event.primary_subject_id)
      }
    }
  }
  if keys.is_empty() {
    return None
  }
  let mut bounds : CssBounds? = None
  for subject in before + after {
    match subject.clip_resource_id {
      Some(id) if keys.contains(id) =>
        bounds = union_bounds(
          bounds,
          match subject.clip_effect_bounds {
            Some(bounds) => Some(bounds)
            None if subject.clip_complete => None
            None => source_subject_unclipped_bounds(subject)
          },
        )
      _ => ()
    }
  }
  bounds
}

///|
fn mask_resource_event_bounds(
  event : VisualEvent,
  report : StructuredReport,
  before : Array[SourceSubject],
  after : Array[SourceSubject],
) -> CssBounds? {
  let keys : Array[String] = []
  for difference_id in event.atomic_difference_ids {
    for difference in report.atomic_differences {
      if difference.id == difference_id &&
        difference.domain.has_prefix("resource.mask.") {
        push_unique(keys, event.primary_subject_id)
      }
    }
  }
  if keys.is_empty() {
    return None
  }
  let mut bounds : CssBounds? = None
  for subject in before + after {
    match subject.mask_resource_id {
      Some(id) if keys.contains(id) =>
        bounds = union_bounds(
          bounds,
          match subject.mask_effect_bounds {
            Some(bounds) => Some(bounds)
            None if subject.mask_complete => None
            None => source_subject_bounds(subject)
          },
        )
      _ => ()
    }
  }
  bounds
}

///|
fn mask_host_event_bounds(
  event : VisualEvent,
  before : Array[SourceSubject],
  after : Array[SourceSubject],
) -> CssBounds? {
  if !event.id.has_prefix("event:mask-host:") {
    return None
  }
  let affected_subject_ids : Array[String] = []
  for subject in before + after {
    if subject.mask_owner_id == Some(event.primary_subject_id) {
      push_unique(affected_subject_ids, source_subject_id(subject))
    }
  }
  let mut bounds : CssBounds? = None
  for subject in before + after {
    if affected_subject_ids.contains(source_subject_id(subject)) {
      bounds = union_bounds(bounds, source_subject_bounds(subject))
    }
  }
  bounds
}

///|
fn filter_host_conservative_bounds(host : ResolvedFilterHost) -> CssBounds? {
  let mut bounds = host.effect_bounds
  for primitive in host.primitive_bounds {
    bounds = union_bounds(bounds, primitive)
  }
  bounds
}

///|
fn filter_event_bounds(
  event : VisualEvent,
  before : Array[ResolvedFilterHost],
  after : Array[ResolvedFilterHost],
) -> CssBounds? {
  let mut bounds : CssBounds? = None
  if event.id.has_prefix("event:filter-host:") {
    let owner_id = event.id
      .view(start_offset="event:filter-host:".length())
      .to_owned()
    for host in before + after {
      if host.owner_id == owner_id {
        bounds = union_bounds(bounds, filter_host_conservative_bounds(host))
      }
    }
  } else if event.id.has_prefix("event:filter:") {
    let resource_id = event.id
      .view(start_offset="event:filter:".length())
      .to_owned()
    for host in before + after {
      if host.resource_id == Some(resource_id) {
        bounds = union_bounds(bounds, filter_host_conservative_bounds(host))
      }
    }
  }
  bounds
}

///|
fn escape_xml_attribute(value : String) -> String {
  value
  .replace_all(old="&", new="&amp;")
  .replace_all(old="\"", new="&quot;")
  .replace_all(old="<", new="&lt;")
}

///|
fn isolated_subjects_image(
  subjects : Array[SourceSubject],
  profile : ComparisonProfile,
) -> @svg.Image? {
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
    @svg.parse_svg_document(
      normalize_renderer_input_with_profile(source, profile),
    ) {
    Some(document) => document
    None => return None
  }
  Some(
    render_product_document_to_image(
      document,
      profile.viewport_width,
      profile.viewport_height,
    ),
  )
}

///|
fn isolated_presence_painted_pixels(
  subjects : Array[SourceSubject],
  profile : ComparisonProfile,
) -> Int? {
  let image = match isolated_subjects_image(subjects, profile) {
    Some(image) => image
    None => return None
  }
  let mut painted_pixels = 0
  for pixel in image.pixels {
    if pixel.a > 0 {
      painted_pixels += 1
    }
  }
  Some(painted_pixels)
}

///|
fn painted_boundary_pixel(image : @svg.Image, x : Int, y : Int) -> Bool {
  let index = y * image.width + x
  if image.pixels[index].a == 0 {
    return false
  }
  x == 0 ||
  y == 0 ||
  x + 1 == image.width ||
  y + 1 == image.height ||
  image.pixels[index - 1].a == 0 ||
  image.pixels[index + 1].a == 0 ||
  image.pixels[index - image.width].a == 0 ||
  image.pixels[index + image.width].a == 0
}

///|
fn painted_boundary_count(image : @svg.Image) -> Int {
  let mut count = 0
  for y in 0..<image.height {
    for x in 0..<image.width {
      if painted_boundary_pixel(image, x, y) {
        count += 1
      }
    }
  }
  count
}

///|
fn squared_distance_transform_1d(
  values : Array[Double],
  unreachable_distance : Double,
) -> Array[Double] {
  let length = values.length()
  let result = Array::make(length, unreachable_distance)
  let mut has_feature = false
  for value in values {
    if value < unreachable_distance {
      has_feature = true
      break
    }
  }
  if !has_feature {
    return result
  }
  let sites = Array::make(length, 0)
  let boundaries = Array::make(length + 1, 0.0)
  let mut envelope = 0
  sites[0] = 0
  boundaries[0] = -1.7976931348623157e308
  boundaries[1] = 1.7976931348623157e308
  for candidate in 1..<length {
    let mut site = sites[envelope]
    let mut intersection = (
        values[candidate] +
        candidate.to_double() * candidate.to_double() -
        values[site] -
        site.to_double() * site.to_double()
      ) /
      (2.0 * (candidate - site).to_double())
    while envelope > 0 && intersection <= boundaries[envelope] {
      envelope -= 1
      site = sites[envelope]
      intersection = (
          values[candidate] +
          candidate.to_double() * candidate.to_double() -
          values[site] -
          site.to_double() * site.to_double()
        ) /
        (2.0 * (candidate - site).to_double())
    }
    envelope += 1
    sites[envelope] = candidate
    boundaries[envelope] = intersection
    boundaries[envelope + 1] = 1.7976931348623157e308
  }
  envelope = 0
  for position in 0..<length {
    while boundaries[envelope + 1] < position.to_double() {
      envelope += 1
    }
    let delta = position - sites[envelope]
    result[position] = delta.to_double() * delta.to_double() +
      values[sites[envelope]]
  }
  result
}

///|
fn boundary_squared_distance_transform(image : @svg.Image) -> Array[Double] {
  let unreachable_distance = image.width.to_double() * image.width.to_double() +
    image.height.to_double() * image.height.to_double() +
    1.0
  let distances = Array::make(image.width * image.height, unreachable_distance)
  for y in 0..<image.height {
    let row = Array::make(image.width, unreachable_distance)
    for x in 0..<image.width {
      if painted_boundary_pixel(image, x, y) {
        row[x] = 0.0
      }
    }
    let transformed = squared_distance_transform_1d(row, unreachable_distance)
    for x in 0..<image.width {
      distances[y * image.width + x] = transformed[x]
    }
  }
  for x in 0..<image.width {
    let column = Array::make(image.height, unreachable_distance)
    for y in 0..<image.height {
      column[y] = distances[y * image.width + x]
    }
    let transformed = squared_distance_transform_1d(
      column, unreachable_distance,
    )
    for y in 0..<image.height {
      distances[y * image.width + x] = transformed[y]
    }
  }
  distances
}

///|
fn directional_boundary_distances(
  source : @svg.Image,
  target : @svg.Image,
) -> Array[Double] {
  let distances = boundary_squared_distance_transform(target)
  let samples : Array[Double] = []
  for y in 0..<source.height {
    for x in 0..<source.width {
      if painted_boundary_pixel(source, x, y) {
        samples.push(distances[y * source.width + x].sqrt())
      }
    }
  }
  samples
}

///|
fn painted_boundary_displacement_distribution(
  before : @svg.Image,
  after : @svg.Image,
  comparison_dpr : Double,
) -> PaintedBoundaryDisplacementMagnitude? {
  if before.width != after.width ||
    before.height != after.height ||
    comparison_dpr <= 0.0 ||
    comparison_dpr.is_nan() ||
    comparison_dpr.is_inf() {
    return None
  }
  let before_count = painted_boundary_count(before)
  let after_count = painted_boundary_count(after)
  if before_count == 0 && after_count == 0 {
    return Some({
      method_id: "symmetric_nearest_boundary_pixels/v1",
      before_sample_count: 0,
      after_sample_count: 0,
      mean_css_px: 0.0,
      p95_css_px: 0.0,
      max_css_px: 0.0,
    })
  }
  if before_count == 0 || after_count == 0 {
    return None
  }
  let samples = directional_boundary_distances(before, after) +
    directional_boundary_distances(after, before)
  samples.sort()
  let mut total = 0.0
  for sample in samples {
    total += sample
  }
  let sample_count = samples.length()
  let p95_index = (sample_count.to_double() * 0.95).ceil().to_int() - 1
  Some({
    method_id: "symmetric_nearest_boundary_pixels/v1",
    before_sample_count: before_count,
    after_sample_count: after_count,
    mean_css_px: total / sample_count.to_double() / comparison_dpr,
    p95_css_px: samples[p95_index] / comparison_dpr,
    max_css_px: samples[sample_count - 1] / comparison_dpr,
  })
}

///|
fn painted_coverage_difference(
  before : @svg.Image,
  after : @svg.Image,
  comparison_dpr : Double,
) -> PaintedCoverageDifferenceMagnitude? {
  if before.width != after.width ||
    before.height != after.height ||
    comparison_dpr <= 0.0 ||
    comparison_dpr.is_nan() ||
    comparison_dpr.is_inf() {
    return None
  }
  let mut before_coverage = 0.0
  let mut after_coverage = 0.0
  let mut absolute_difference = 0.0
  let mut union_coverage = 0.0
  for index in 0..<before.pixels.length() {
    let before_alpha = before.pixels[index].a.to_double() / 255.0
    let after_alpha = after.pixels[index].a.to_double() / 255.0
    before_coverage += before_alpha
    after_coverage += after_alpha
    absolute_difference += (before_alpha - after_alpha).abs()
    union_coverage += before_alpha.max(after_alpha)
  }
  let css_pixel_area = comparison_dpr * comparison_dpr
  Some({
    method_id: "symmetric_alpha_coverage_l1_over_union/v1",
    before_coverage_css_px2: before_coverage / css_pixel_area,
    after_coverage_css_px2: after_coverage / css_pixel_area,
    absolute_difference_css_px2: absolute_difference / css_pixel_area,
    union_coverage_css_px2: union_coverage / css_pixel_area,
    fraction: if union_coverage == 0.0 {
      0.0
    } else {
      absolute_difference / union_coverage
    },
  })
}

///|
priv struct IsolatedPaintMeasurements {
  boundary_displacement : PaintedBoundaryDisplacementMagnitude?
  coverage_difference : PaintedCoverageDifferenceMagnitude
}

///|
fn isolated_subjects_painted_measurements(
  before : Array[SourceSubject],
  after : Array[SourceSubject],
  profile : ComparisonProfile,
) -> IsolatedPaintMeasurements? {
  let images = match
    (
      isolated_subjects_image(before, profile),
      isolated_subjects_image(after, profile),
    ) {
    (Some(before_image), Some(after_image)) => (before_image, after_image)
    _ => return None
  }
  let (before_image, after_image) = images
  if before_image.width != after_image.width ||
    before_image.height != after_image.height {
    return None
  }
  guard painted_coverage_difference(
      before_image,
      after_image,
      profile.comparison_dpr,
    )
    is Some(coverage_difference) else {
    return None
  }
  Some({
    boundary_displacement: painted_boundary_displacement_distribution(
      before_image,
      after_image,
      profile.comparison_dpr,
    ),
    coverage_difference,
  })
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
  resources : ComparisonResourceBundles,
  limits : ResourceLimits,
  comparison_guard : ComparisonGuard,
) -> DifferenceRegionAttachment raise ComparisonInterrupted {
  comparison_guard.checkpoint()
  let before = extract_source_subjects_with_profile_or_raise(
    before_svg,
    report.profile,
  ) catch {
    _ => []
  }
  let after = extract_source_subjects_with_profile_or_raise(
    after_svg,
    report.profile,
  ) catch {
    _ => []
  }
  let before_images = extract_embedded_image_subjects_or_raise(
    before_svg,
    report.profile,
    resources.before,
    limits,
  ) catch {
    _ => []
  }
  let after_images = extract_embedded_image_subjects_or_raise(
    after_svg,
    report.profile,
    resources.after,
    limits,
  ) catch {
    _ => []
  }
  let before_filter_hosts = try
    resolve_filter_hosts_or_raise(before_svg, report.profile)
  catch {
    _ => []
  } noraise {
    value => value.1
  }
  let after_filter_hosts = try
    resolve_filter_hosts_or_raise(after_svg, report.profile)
  catch {
    _ => []
  } noraise {
    value => value.1
  }
  let rendered_images = match
    (
      render_product_source_to_image(before_svg, report.profile),
      render_product_source_to_image(after_svg, report.profile),
    ) {
    (Some(before_image), Some(after_image)) => Some((before_image, after_image))
    _ => None
  }
  let pixel_regions = match rendered_images {
    Some((before_image, after_image)) =>
      match
        pixel_difference_regions(before_image, after_image, limits.max_regions) {
        Regions(regions) => regions
        RegionLimitExceeded => return AttachmentRegionLimitExceeded
      }
    None => []
  }
  let events : Array[VisualEvent] = []
  let mut attached_region_count = 0
  let mut perceptual_map_pixels = 0
  let mut perceptual_flip_samples = 0
  for event in report.events {
    comparison_guard.checkpoint()
    let bounds = match
      group_opacity_event_bounds(event, report, before, after) {
      Some(bounds) => Some(bounds)
      None =>
        match clip_resource_event_bounds(event, report, before, after) {
          Some(bounds) => Some(bounds)
          None =>
            match mask_resource_event_bounds(event, report, before, after) {
              Some(bounds) => Some(bounds)
              None =>
                match
                  filter_event_bounds(
                    event, before_filter_hosts, after_filter_hosts,
                  ) {
                  Some(bounds) => Some(bounds)
                  None =>
                    match mask_host_event_bounds(event, before, after) {
                      Some(bounds) => Some(bounds)
                      None =>
                        match
                          marker_resource_bounds_for_event(event, before, after) {
                          Some(bounds) => Some(bounds)
                          None =>
                            match alignment_for_event(event, alignments) {
                              Some(alignment) if alignment.id.has_prefix(
                                  "alignment:image:",
                                ) =>
                                embedded_image_alignment_bounds(
                                  alignment, before_images, after_images,
                                )
                              Some(alignment) =>
                                alignment_bounds(alignment, before, after)
                              None => None
                            }
                        }
                    }
                }
            }
        }
    }
    let regions : Array[DifferenceRegion] = []
    if event.rendered_outcome.status == "computed" {
      match bounds {
        Some(bounds) =>
          for region in pixel_regions {
            if regions_intersect(region, bounds) {
              if attached_region_count >= limits.max_regions {
                return AttachmentRegionLimitExceeded
              }
              regions.push(region)
              attached_region_count += 1
            }
          }
        None =>
          for region in pixel_regions {
            if attached_region_count >= limits.max_regions {
              return AttachmentRegionLimitExceeded
            }
            regions.push(region)
            attached_region_count += 1
          }
      }
    } else {
      match bounds {
        Some(bounds) => {
          if attached_region_count >= limits.max_regions {
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
    let perceptual_color = match report.profile.perceptual_background {
      None =>
        not_computed_perceptual_color_evidence("perceptual_background_absent")
      Some(background) =>
        if rendered_outcome.status != "computed" {
          not_computed_perceptual_color_evidence(
            "rendered_evidence_unavailable",
          )
        } else {
          match rendered_images {
            Some((before_image, after_image)) =>
              event_local_perceptual_color_evidence(
                before_image, after_image, regions, background,
              )
            None =>
              not_computed_perceptual_color_evidence(
                "rendered_evidence_unavailable",
              )
          }
        }
    }
    let perceptual_flip = match report.profile.flip_viewing_conditions {
      None => not_computed_perceptual_flip_evidence("flip_not_requested")
      Some(viewing) =>
        match report.profile.perceptual_background {
          None =>
            not_computed_perceptual_flip_evidence(
              "perceptual_background_absent",
            )
          Some(background) =>
            if rendered_outcome.status != "computed" {
              not_computed_perceptual_flip_evidence(
                "rendered_evidence_unavailable",
              )
            } else {
              match rendered_images {
                Some((before_image, after_image)) => {
                  let computation = event_local_perceptual_flip_evidence(
                    before_image,
                    after_image,
                    regions,
                    background,
                    viewing,
                    report.profile.flip_error_threshold,
                    limits.max_perceptual_map_pixels - perceptual_map_pixels,
                    limits.max_perceptual_flip_samples - perceptual_flip_samples,
                  )
                  perceptual_map_pixels += computation.output_pixels
                  perceptual_flip_samples += computation.convolution_samples
                  computation.evidence
                }
                None =>
                  not_computed_perceptual_flip_evidence(
                    "rendered_evidence_unavailable",
                  )
              }
            }
        }
    }
    events.push({
      ..event,
      rendered_outcome: {
        ..rendered_outcome,
        perceptual_color,
        perceptual_flip,
      },
      difference_regions: regions,
    })
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
