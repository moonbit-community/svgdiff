///|
pub(all) struct MarkerAttachmentResolution {
  values : Array[(String, String)]
  effective_facts : Array[DeclaredVisualFact]
  invalid_facts : Array[DeclaredVisualFact]
  complete : Bool
}

///|
pub(all) struct MarkerResource {
  node_index : Int
  subject_id : String
  authored_id : String?
  facts : Array[DeclaredVisualFact]
  invalid_facts : Array[DeclaredVisualFact]
  complete : Bool
  marker_units : String
  marker_width : Double
  marker_height : Double
  ref_x : Double
  ref_y : Double
  orient_kind : String
  orient_angle : Double
  view_box : ViewBoxValue?
  preserve_aspect_ratio : PreserveAspectRatioValue
  viewport_matrix : AffineTransform
  overflow : String
  mut content_fact : DeclaredVisualFact
}

///|
pub(all) struct MarkerSegment {
  end_x : Double
  end_y : Double
  start_angle : Double?
  end_angle : Double?
}

///|
pub(all) struct MarkerSubpath {
  start_x : Double
  start_y : Double
  segments : Array[MarkerSegment]
}

///|
pub(all) struct MarkerVertex {
  x : Double
  y : Double
  auto_angle : Double
}

///|
pub fn resolve_marker_attachments(
  facts : Array[DeclaredVisualFact],
  inherited_facts : Array[DeclaredVisualFact],
) -> MarkerAttachmentResolution {
  let invalid_facts : Array[DeclaredVisualFact] = []
  let shorthand_fact = shape_fact(facts, "marker")
  let shorthand = match shorthand_fact {
    Some(fact) =>
      match canonical_marker_reference(fact.declared_value) {
        Some(value) => value
        None => {
          push_invalid_stroke_fact(invalid_facts, Some(fact))
          "none"
        }
      }
    None => "none"
  }
  let effective_facts : Array[DeclaredVisualFact] = []
  for fact in inherited_facts {
    upsert_declared_fact(effective_facts, fact)
  }
  match shorthand_fact {
    Some(fact) =>
      for property in ["marker-start", "marker-mid", "marker-end"] {
        upsert_declared_fact(effective_facts, { ..fact, property, })
      }
    None => ()
  }
  for property in ["marker-start", "marker-mid", "marker-end"] {
    match shape_fact(facts, property) {
      Some(fact) => upsert_declared_fact(effective_facts, fact)
      None => ()
    }
  }
  let values : Array[(String, String)] = [("marker", shorthand)]
  for property in ["marker-start", "marker-mid", "marker-end"] {
    let value = match shape_fact(effective_facts, property) {
      Some(fact) =>
        match canonical_marker_reference(fact.declared_value) {
          Some(value) => value
          None => {
            push_invalid_stroke_fact(invalid_facts, Some(fact))
            "none"
          }
        }
      None => "none"
    }
    values.push((property, value))
  }
  { values, effective_facts, invalid_facts, complete: invalid_facts.is_empty() }
}

///|
pub fn marker_inherited_facts_for_element(
  input : String,
  element : @xml.NamespaceElement,
  stylesheet_match : CssStylesheetMatch,
  inherited : Array[DeclaredVisualFact],
) -> Array[DeclaredVisualFact] {
  let effective = inherited.copy()
  let candidates : Array[CssCascadeCandidate] = []
  let mut style : @xml.NamespaceAttribute? = None
  for attribute in element.attributes {
    let property = attribute.name.local_name
    if property == "style" {
      style = Some(attribute)
    } else if marker_attachment_property(property) {
      candidates.push(
        presentation_cascade_candidate(
          presentation_fact(input, property, attribute),
          attribute.span.start.offset,
        ),
      )
    }
  }
  match style {
    Some(attribute) =>
      for candidate in inline_style_facts(input, attribute).candidates {
        if marker_attachment_property(candidate.declaration.property) {
          candidates.push(candidate)
        }
      }
    None => ()
  }
  for candidate in stylesheet_match.candidates {
    if marker_attachment_property(candidate.declaration.property) {
      candidates.push(candidate)
    }
  }
  let declarations = cascade_visual_declarations(candidates)
  match shape_fact(declarations, "marker") {
    Some(fact) =>
      for property in ["marker-start", "marker-mid", "marker-end"] {
        upsert_declared_fact(effective, { ..fact, property, })
      }
    None => ()
  }
  for property in ["marker-start", "marker-mid", "marker-end"] {
    match shape_fact(declarations, property) {
      Some(fact) => upsert_declared_fact(effective, fact)
      None => ()
    }
  }
  effective
}

///|
pub fn marker_fact(
  input : String,
  property : String,
  attribute : @xml.NamespaceAttribute,
) -> DeclaredVisualFact {
  presentation_fact(input, property, attribute)
}

///|
pub fn marker_attribute(
  element : @xml.NamespaceElement,
  property : String,
) -> @xml.NamespaceAttribute? {
  for attribute in element.attributes {
    if attribute.name.local_name == property {
      return Some(attribute)
    }
  }
  None
}

///|
pub fn marker_empty_content_fact(offset : Int) -> DeclaredVisualFact {
  {
    property: "content",
    authored_value: "",
    declared_value: "",
    origin: "resource_content",
    source_span: { start_offset: offset, end_offset: offset },
  }
}

///|
pub fn marker_angle_degrees(source : String) -> Double? {
  let value = source.trim().to_owned().to_lower()
  if value == "" {
    return None
  }
  let mut number = value.view()
  let mut multiplier = 1.0
  if value.has_suffix("deg") {
    number = value.view(end_offset=value.length() - 3)
  } else if value.has_suffix("grad") {
    number = value.view(end_offset=value.length() - 4)
    multiplier = 0.9
  } else if value.has_suffix("rad") {
    number = value.view(end_offset=value.length() - 3)
    multiplier = 180.0 / 3.141592653589793
  } else if value.has_suffix("turn") {
    number = value.view(end_offset=value.length() - 4)
    multiplier = 360.0
  }
  match parse_shape_number(number.to_owned()) {
    Some(parsed) => Some(normalized_transform_component(parsed * multiplier))
    None => None
  }
}

///|
pub fn marker_reference_coordinate(
  source : String,
  axis : String,
  view_box : ViewBoxValue?,
  viewport : ViewportContext,
  profile : ComparisonProfile,
) -> Double? {
  let value = source.trim().to_owned().to_lower()
  let keyword_percentage = match (axis, value) {
    ("x", "left") | ("y", "top") => Some(0.0)
    ("x" | "y", "center") => Some(0.5)
    ("x", "right") | ("y", "bottom") => Some(1.0)
    _ => None
  }
  match keyword_percentage {
    Some(percentage) =>
      match view_box {
        Some(box) =>
          if axis == "x" {
            Some(box.min_x + box.width * percentage)
          } else {
            Some(box.min_y + box.height * percentage)
          }
        None => None
      }
    None =>
      if value.has_suffix("%") {
        match view_box {
          Some(box) =>
            match
              parse_shape_number(
                value.view(end_offset=value.length() - 1).to_owned(),
              ) {
              Some(percentage) =>
                if axis == "x" {
                  Some(box.min_x + box.width * percentage / 100.0)
                } else {
                  Some(box.min_y + box.height * percentage / 100.0)
                }
              None => None
            }
          None => None
        }
      } else {
        parse_svg_length(
          value,
          if axis == "x" {
            Horizontal
          } else {
            Vertical
          },
          viewport,
          profile,
        )
      }
  }
}

///|
pub fn marker_resource_from_element(
  input : String,
  element : @xml.NamespaceElement,
  node_index : Int,
  content_offset : Int,
  viewport : ViewportContext,
  profile : ComparisonProfile,
) -> MarkerResource {
  let authored_id = authored_subject_id(element)
  let subject_id = authored_id.unwrap_or(
    generated_subject_id("marker", node_index),
  )
  let facts : Array[DeclaredVisualFact] = []
  let invalid_facts : Array[DeclaredVisualFact] = []
  let mut complete = true
  fn invalid(attribute : @xml.NamespaceAttribute, property : String) -> Unit {
    complete = false
    let fact = marker_fact(input, property, attribute)
    facts.push(fact)
    invalid_facts.push(fact)
  }
  let view_box = match marker_attribute(element, "viewBox") {
    Some(attribute) =>
      match parse_view_box_value(attribute.value) {
        Some(value) => {
          facts.push(
            normalized_viewport_fact(
              input,
              "viewBox",
              attribute,
              normalized_view_box_signature(value),
            ),
          )
          Some(value)
        }
        None => {
          invalid(attribute, "viewBox")
          None
        }
      }
    None => None
  }
  let preserve = match marker_attribute(element, "preserveAspectRatio") {
    Some(attribute) =>
      match parse_preserve_aspect_ratio_value(attribute.value) {
        Some(value) => {
          facts.push(
            normalized_viewport_fact(
              input,
              "preserveAspectRatio",
              attribute,
              preserve_aspect_ratio_signature(value),
            ),
          )
          value
        }
        None => {
          invalid(attribute, "preserveAspectRatio")
          default_preserve_aspect_ratio()
        }
      }
    None => default_preserve_aspect_ratio()
  }
  fn length_attribute(
    property : String,
    direction : SvgLengthDirection,
    default_value : Double,
  ) -> Double {
    match marker_attribute(element, property) {
      Some(attribute) =>
        match parse_svg_length(attribute.value, direction, viewport, profile) {
          Some(value) => {
            facts.push({
              ..marker_fact(input, property, attribute),
              declared_value: canonical_shape_number(value),
            })
            value
          }
          None => {
            invalid(attribute, property)
            default_value
          }
        }
      None => default_value
    }
  }
  let marker_width = length_attribute("markerWidth", Horizontal, 3.0)
  let marker_height = length_attribute("markerHeight", Vertical, 3.0)
  if marker_width < 0.0 {
    match marker_attribute(element, "markerWidth") {
      Some(attribute) => invalid(attribute, "markerWidth")
      None => ()
    }
  }
  if marker_height < 0.0 {
    match marker_attribute(element, "markerHeight") {
      Some(attribute) => invalid(attribute, "markerHeight")
      None => ()
    }
  }
  let marker_units = match marker_attribute(element, "markerUnits") {
    Some(attribute) =>
      match attribute.value.trim().to_owned().to_lower() {
        "strokewidth" => {
          facts.push({
            ..marker_fact(input, "markerUnits", attribute),
            declared_value: "strokeWidth",
          })
          "strokeWidth"
        }
        "userspaceonuse" => {
          facts.push({
            ..marker_fact(input, "markerUnits", attribute),
            declared_value: "userSpaceOnUse",
          })
          "userSpaceOnUse"
        }
        _ => {
          invalid(attribute, "markerUnits")
          "strokeWidth"
        }
      }
    None => "strokeWidth"
  }
  let (orient_kind, orient_angle) = match marker_attribute(element, "orient") {
    Some(attribute) =>
      match attribute.value.trim().to_owned().to_lower() {
        "auto" => {
          facts.push({
            ..marker_fact(input, "orient", attribute),
            declared_value: "auto",
          })
          ("auto", 0.0)
        }
        "auto-start-reverse" => {
          facts.push({
            ..marker_fact(input, "orient", attribute),
            declared_value: "auto-start-reverse",
          })
          ("auto-start-reverse", 0.0)
        }
        source =>
          match marker_angle_degrees(source) {
            Some(angle) => {
              facts.push({
                ..marker_fact(input, "orient", attribute),
                declared_value: canonical_shape_number(angle),
              })
              ("angle", angle)
            }
            None => {
              invalid(attribute, "orient")
              ("angle", 0.0)
            }
          }
      }
    None => ("angle", 0.0)
  }
  let ref_x = match marker_attribute(element, "refX") {
    Some(attribute) =>
      match
        marker_reference_coordinate(
          attribute.value,
          "x",
          view_box,
          viewport,
          profile,
        ) {
        Some(value) => {
          facts.push({
            ..marker_fact(input, "refX", attribute),
            declared_value: canonical_shape_number(value),
          })
          value
        }
        None => {
          invalid(attribute, "refX")
          0.0
        }
      }
    None => 0.0
  }
  let ref_y = match marker_attribute(element, "refY") {
    Some(attribute) =>
      match
        marker_reference_coordinate(
          attribute.value,
          "y",
          view_box,
          viewport,
          profile,
        ) {
        Some(value) => {
          facts.push({
            ..marker_fact(input, "refY", attribute),
            declared_value: canonical_shape_number(value),
          })
          value
        }
        None => {
          invalid(attribute, "refY")
          0.0
        }
      }
    None => 0.0
  }
  let overflow = match marker_attribute(element, "overflow") {
    Some(attribute) =>
      if attribute.value.trim().to_owned().to_lower() == "hidden" {
        facts.push({
          ..marker_fact(input, "overflow", attribute),
          declared_value: "hidden",
        })
        "hidden"
      } else {
        invalid(attribute, "overflow")
        "hidden"
      }
    None => "hidden"
  }
  facts.sort_by(fn(left, right) { left.property.compare(right.property) })
  let viewport_matrix = match view_box {
    Some(box) if marker_width >= 0.0 && marker_height >= 0.0 =>
      equivalent_viewport_transform(
        box, 0.0, 0.0, marker_width, marker_height, preserve,
      )
    _ => AffineTransform::identity()
  }
  {
    node_index,
    subject_id,
    authored_id,
    facts,
    invalid_facts,
    complete,
    marker_units,
    marker_width: marker_width.max(0.0),
    marker_height: marker_height.max(0.0),
    ref_x,
    ref_y,
    orient_kind,
    orient_angle,
    view_box,
    preserve_aspect_ratio: preserve,
    viewport_matrix,
    overflow,
    content_fact: marker_empty_content_fact(content_offset),
  }
}

///|
pub fn extract_marker_resources_or_raise(
  input : String,
  profile : ComparisonProfile,
) -> Array[MarkerResource] raise {
  let resources : Array[MarkerResource] = []
  let resource_stack : Array[(Int, Int)] = []
  let viewport_contexts : Array[ViewportContext] = []
  let mut node_index = 0
  let reader = @xml.NamespaceReader::from_string(input)
  for event in reader.read_events_until_eof() {
    match event.kind {
      Start(element) => {
        if element.name.local_name == "svg" {
          let (_, child_viewport) = source_transform_site_with_viewport(
            input,
            element,
            node_index,
            profile,
            viewport_contexts.last(),
          )
          match child_viewport {
            Some(context) => viewport_contexts.push(context)
            None => ()
          }
        }
        if element.name.local_name == "marker" {
          let index = resources.length()
          resources.push(
            marker_resource_from_element(
              input,
              element,
              node_index,
              event.span.end.offset,
              viewport_contexts
              .last()
              .unwrap_or({
                width: profile.viewport_width.to_double(),
                height: profile.viewport_height.to_double(),
              }),
              profile,
            ),
          )
          resource_stack.push((index, event.span.end.offset))
        }
        node_index += 1
      }
      Empty(element) => {
        if element.name.local_name == "marker" {
          resources.push(
            marker_resource_from_element(
              input,
              element,
              node_index,
              event.span.end.offset,
              viewport_contexts
              .last()
              .unwrap_or({
                width: profile.viewport_width.to_double(),
                height: profile.viewport_height.to_double(),
              }),
              profile,
            ),
          )
        }
        node_index += 1
      }
      End(name) => {
        if name.local_name == "marker" {
          match resource_stack.pop() {
            Some((index, start_offset)) => {
              let end_offset = event.span.start.offset
              let content = source_range_slice(input, start_offset, end_offset)
              resources[index].content_fact = {
                property: "content",
                authored_value: content,
                declared_value: content,
                origin: "resource_content",
                source_span: { start_offset, end_offset },
              }
            }
            None => ()
          }
        }
        if name.local_name == "svg" {
          ignore(viewport_contexts.pop())
        }
      }
      _ => ()
    }
  }
  resources
}

///|
pub fn marker_resource(
  resources : Array[MarkerResource],
  id : String,
) -> MarkerResource? {
  for resource in resources {
    if resource.subject_id == id {
      return Some(resource)
    }
  }
  None
}

///|
pub fn marker_line_segment(
  start_x : Double,
  start_y : Double,
  end_x : Double,
  end_y : Double,
) -> MarkerSegment {
  let angle = if start_x == end_x && start_y == end_y {
    None
  } else {
    Some(
      @math.atan2(end_y - start_y, end_x - start_x) * 180.0 / 3.141592653589793,
    )
  }
  { end_x, end_y, start_angle: angle, end_angle: angle }
}

///|
pub fn marker_curve_angle(points : Array[(Double, Double)]) -> Double? {
  guard points is [(start_x, start_y), .. rest] else { return None }
  for point in rest {
    if point.0 != start_x || point.1 != start_y {
      return Some(
        @math.atan2(point.1 - start_y, point.0 - start_x) *
        180.0 /
        3.141592653589793,
      )
    }
  }
  None
}

///|
pub fn marker_cubic_segment(
  start_x : Double,
  start_y : Double,
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
  end_x : Double,
  end_y : Double,
) -> MarkerSegment {
  {
    end_x,
    end_y,
    start_angle: marker_curve_angle([
      (start_x, start_y),
      (x1, y1),
      (x2, y2),
      (end_x, end_y),
    ]),
    end_angle: marker_curve_angle([
      (end_x, end_y),
      (x2, y2),
      (x1, y1),
      (start_x, start_y),
    ]).map(angle => angle + 180.0),
  }
}

///|
pub fn marker_quadratic_segment(
  start_x : Double,
  start_y : Double,
  x1 : Double,
  y1 : Double,
  end_x : Double,
  end_y : Double,
) -> MarkerSegment {
  {
    end_x,
    end_y,
    start_angle: marker_curve_angle([
      (start_x, start_y),
      (x1, y1),
      (end_x, end_y),
    ]),
    end_angle: marker_curve_angle([(end_x, end_y), (x1, y1), (start_x, start_y)]).map(angle => {
        angle + 180.0
      },
    ),
  }
}

///|
pub fn marker_arc_endpoint_angles(
  start_x : Double,
  start_y : Double,
  raw_rx : Double,
  raw_ry : Double,
  rotation : Double,
  large : Bool,
  sweep : Bool,
  end_x : Double,
  end_y : Double,
) -> (Double, Double)? {
  if start_x == end_x && start_y == end_y {
    return None
  }
  let rx = raw_rx.abs()
  let ry = raw_ry.abs()
  if rx == 0.0 || ry == 0.0 {
    let angle = @math.atan2(end_y - start_y, end_x - start_x) *
      180.0 /
      3.141592653589793
    return Some((angle, angle))
  }
  @arc_geometry.svg_arc_center_parameters(
    start_x, start_y, rx, ry, rotation, large, sweep, end_x, end_y,
  ).map(arc => {
    (
      arc.tangent_angle_degrees(arc.start_theta),
      arc.tangent_angle_degrees(arc.start_theta + arc.sweep_theta),
    )
  })
}

///|
pub fn marker_arc_segment(
  start_x : Double,
  start_y : Double,
  rx : Double,
  ry : Double,
  rotation : Double,
  large : Bool,
  sweep : Bool,
  end_x : Double,
  end_y : Double,
) -> MarkerSegment? {
  match
    marker_arc_endpoint_angles(
      start_x, start_y, rx, ry, rotation, large, sweep, end_x, end_y,
    ) {
    Some((start_angle, end_angle)) =>
      Some({
        end_x,
        end_y,
        start_angle: Some(start_angle),
        end_angle: Some(end_angle),
      })
    None => None
  }
}

///|
pub fn marker_subpaths_for_path(
  segments : Array[PathSegmentEvidence],
) -> Array[MarkerSubpath] {
  let subpaths : Array[MarkerSubpath] = []
  let mut current_x = 0.0
  let mut current_y = 0.0
  for evidence in segments {
    match evidence.normalized {
      MoveTo(x, y) => {
        subpaths.push({ start_x: x, start_y: y, segments: [] })
        current_x = x
        current_y = y
      }
      LineTo(x, y) => {
        if subpaths.is_empty() {
          subpaths.push({ start_x: current_x, start_y: current_y, segments: [] })
        }
        subpaths[subpaths.length() - 1].segments.push(
          marker_line_segment(current_x, current_y, x, y),
        )
        current_x = x
        current_y = y
      }
      CubicTo(x1, y1, x2, y2, x, y) => {
        if subpaths.is_empty() {
          subpaths.push({ start_x: current_x, start_y: current_y, segments: [] })
        }
        subpaths[subpaths.length() - 1].segments.push(
          marker_cubic_segment(current_x, current_y, x1, y1, x2, y2, x, y),
        )
        current_x = x
        current_y = y
      }
      QuadraticTo(x1, y1, x, y) => {
        if subpaths.is_empty() {
          subpaths.push({ start_x: current_x, start_y: current_y, segments: [] })
        }
        subpaths[subpaths.length() - 1].segments.push(
          marker_quadratic_segment(current_x, current_y, x1, y1, x, y),
        )
        current_x = x
        current_y = y
      }
      ArcTo(rx, ry, rotation, large, sweep, x, y) => {
        if subpaths.is_empty() {
          subpaths.push({ start_x: current_x, start_y: current_y, segments: [] })
        }
        match
          marker_arc_segment(
            current_x, current_y, rx, ry, rotation, large, sweep, x, y,
          ) {
          Some(segment) =>
            subpaths[subpaths.length() - 1].segments.push(segment)
          None => ()
        }
        current_x = x
        current_y = y
      }
      ClosePath =>
        if !subpaths.is_empty() {
          let subpath = subpaths[subpaths.length() - 1]
          subpath.segments.push(
            marker_line_segment(
              current_x,
              current_y,
              subpath.start_x,
              subpath.start_y,
            ),
          )
          current_x = subpath.start_x
          current_y = subpath.start_y
        }
    }
  }
  subpaths
}

///|
pub fn marker_closed_polyline_subpath(
  points : Array[(Double, Double)],
  closed : Bool,
) -> MarkerSubpath? {
  guard points is [first, .. rest] else { return None }
  let subpath : MarkerSubpath = {
    start_x: first.0,
    start_y: first.1,
    segments: [],
  }
  let mut previous = first
  for point in rest {
    subpath.segments.push(
      marker_line_segment(previous.0, previous.1, point.0, point.1),
    )
    previous = point
  }
  if closed {
    subpath.segments.push(
      marker_line_segment(previous.0, previous.1, first.0, first.1),
    )
  }
  Some(subpath)
}

///|
pub fn marker_rounded_rect_subpath(
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  rx : Double,
  ry : Double,
) -> MarkerSubpath {
  let start_x = x + rx
  let start_y = y
  let segments : Array[MarkerSegment] = [
    marker_line_segment(start_x, start_y, x + width - rx, y),
  ]
  for
    segment in [
      marker_arc_segment(
        x + width - rx,
        y,
        rx,
        ry,
        0.0,
        false,
        true,
        x + width,
        y + ry,
      ),
      Some(marker_line_segment(x + width, y + ry, x + width, y + height - ry)),
      marker_arc_segment(
        x + width,
        y + height - ry,
        rx,
        ry,
        0.0,
        false,
        true,
        x + width - rx,
        y + height,
      ),
      Some(marker_line_segment(x + width - rx, y + height, x + rx, y + height)),
      marker_arc_segment(
        x + rx,
        y + height,
        rx,
        ry,
        0.0,
        false,
        true,
        x,
        y + height - ry,
      ),
      Some(marker_line_segment(x, y + height - ry, x, y + ry)),
      marker_arc_segment(x, y + ry, rx, ry, 0.0, false, true, start_x, start_y),
    ] {
    match segment {
      Some(segment) => segments.push(segment)
      None => ()
    }
  }
  { start_x, start_y, segments }
}

///|
pub fn marker_ellipse_subpath(
  cx : Double,
  cy : Double,
  rx : Double,
  ry : Double,
) -> MarkerSubpath {
  let start_x = cx + rx
  let start_y = cy
  let segments : Array[MarkerSegment] = []
  let mut previous_x = start_x
  let mut previous_y = start_y
  for point in [(cx, cy + ry), (cx - rx, cy), (cx, cy - ry), (start_x, start_y)] {
    match
      marker_arc_segment(
        previous_x,
        previous_y,
        rx,
        ry,
        0.0,
        false,
        true,
        point.0,
        point.1,
      ) {
      Some(segment) => segments.push(segment)
      None => ()
    }
    previous_x = point.0
    previous_y = point.1
  }
  { start_x, start_y, segments }
}

///|
pub fn marker_subpaths_for_subject(
  subject : SourceSubject,
) -> Array[MarkerSubpath] {
  match subject.kind {
    "path" => marker_subpaths_for_path(subject.path_segments)
    "line" => {
      let x1 = bounds_number(subject, "x1").unwrap_or(0.0)
      let y1 = bounds_number(subject, "y1").unwrap_or(0.0)
      let x2 = bounds_number(subject, "x2").unwrap_or(0.0)
      let y2 = bounds_number(subject, "y2").unwrap_or(0.0)
      [
        {
          start_x: x1,
          start_y: y1,
          segments: [marker_line_segment(x1, y1, x2, y2)],
        },
      ]
    }
    "polyline" | "polygon" => {
      let (raw, complete, odd) = parse_shape_points(
        subject_value(subject, "points").unwrap_or(""),
      )
      if !complete || odd || raw.length() < 2 {
        return []
      }
      let points : Array[(Double, Double)] = []
      let mut index = 0
      while index + 1 < raw.length() {
        points.push((raw[index], raw[index + 1]))
        index += 2
      }
      match marker_closed_polyline_subpath(points, subject.kind == "polygon") {
        Some(subpath) => [subpath]
        None => []
      }
    }
    "rect" if subject.renders_geometry => {
      let x = bounds_number(subject, "x").unwrap_or(0.0)
      let y = bounds_number(subject, "y").unwrap_or(0.0)
      let width = bounds_number(subject, "width").unwrap_or(0.0)
      let height = bounds_number(subject, "height").unwrap_or(0.0)
      let rx = bounds_number(subject, "rx").unwrap_or(0.0)
      let ry = bounds_number(subject, "ry").unwrap_or(0.0)
      if rx == 0.0 || ry == 0.0 {
        match
          marker_closed_polyline_subpath(
            [(x, y), (x + width, y), (x + width, y + height), (x, y + height)],
            true,
          ) {
          Some(subpath) => [subpath]
          None => []
        }
      } else {
        [marker_rounded_rect_subpath(x, y, width, height, rx, ry)]
      }
    }
    "circle" | "ellipse" if subject.renders_geometry => {
      let cx = bounds_number(subject, "cx").unwrap_or(0.0)
      let cy = bounds_number(subject, "cy").unwrap_or(0.0)
      let rx = if subject.kind == "circle" {
        bounds_number(subject, "r").unwrap_or(0.0)
      } else {
        bounds_number(subject, "rx").unwrap_or(0.0)
      }
      let ry = if subject.kind == "circle" {
        rx
      } else {
        bounds_number(subject, "ry").unwrap_or(0.0)
      }
      [marker_ellipse_subpath(cx, cy, rx, ry)]
    }
    _ => []
  }
}

///|
pub fn marker_effective_start_angle(
  segments : Array[MarkerSegment],
  index : Int,
) -> Double {
  match segments[index].start_angle {
    Some(angle) => return angle
    None => ()
  }
  let mut previous = index - 1
  while previous >= 0 {
    match segments[previous].end_angle {
      Some(angle) => return angle
      None => previous -= 1
    }
  }
  let mut following = index + 1
  while following < segments.length() {
    match segments[following].start_angle {
      Some(angle) => return angle
      None => following += 1
    }
  }
  0.0
}

///|
pub fn marker_effective_end_angle(
  segments : Array[MarkerSegment],
  index : Int,
) -> Double {
  match segments[index].end_angle {
    Some(angle) => return angle
    None => ()
  }
  let mut following = index + 1
  while following < segments.length() {
    match segments[following].start_angle {
      Some(angle) => return angle
      None => following += 1
    }
  }
  let mut previous = index - 1
  while previous >= 0 {
    match segments[previous].end_angle {
      Some(angle) => return angle
      None => previous -= 1
    }
  }
  0.0
}

///|
pub fn marker_midpoint_angle(incoming : Double, outgoing : Double) -> Double {
  let mut delta = outgoing - incoming
  while delta > 180.0 {
    delta -= 360.0
  }
  while delta < -180.0 {
    delta += 360.0
  }
  normalized_transform_component(incoming + delta / 2.0)
}

///|
pub fn marker_vertices_for_subject(
  subject : SourceSubject,
) -> Array[MarkerVertex] {
  let vertices : Array[MarkerVertex] = []
  for subpath in marker_subpaths_for_subject(subject) {
    if subpath.segments.is_empty() {
      vertices.push({ x: subpath.start_x, y: subpath.start_y, auto_angle: 0.0 })
      continue
    }
    let first_outgoing = marker_effective_start_angle(subpath.segments, 0)
    let first_angle = first_outgoing
    vertices.push({
      x: subpath.start_x,
      y: subpath.start_y,
      auto_angle: first_angle,
    })
    for index, segment in subpath.segments {
      let incoming = marker_effective_end_angle(subpath.segments, index)
      let angle = if index + 1 < subpath.segments.length() {
        marker_midpoint_angle(
          incoming,
          marker_effective_start_angle(subpath.segments, index + 1),
        )
      } else {
        incoming
      }
      vertices.push({ x: segment.end_x, y: segment.end_y, auto_angle: angle })
    }
  }
  vertices
}

///|
pub fn marker_reference_id(value : String?) -> String? {
  match value {
    Some(value) =>
      match parse_marker_reference(value) {
        LocalMarker(id) => Some(id)
        _ => None
      }
    None => None
  }
}

///|
pub fn subject_references_marker(
  subject : SourceSubject,
  resource_id : String?,
) -> Bool {
  for property in ["marker-start", "marker-mid", "marker-end"] {
    match marker_reference_id(subject_value(subject, property)) {
      Some(id) if resource_id is None || resource_id == Some(id) => return true
      _ => ()
    }
  }
  false
}

///|
pub fn marker_placement_bounds(
  transform : AffineTransform,
  width : Double,
  height : Double,
) -> CssBounds {
  transform_bounds({ x: 0.0, y: 0.0, width, height }, transform)
}

///|
pub fn marker_placements_for_subject(
  subject : SourceSubject,
  resources : Array[MarkerResource],
) -> Array[MarkerPlacement] {
  let placements : Array[MarkerPlacement] = []
  let vertices = marker_vertices_for_subject(subject)
  for index, vertex in vertices {
    let properties : Array[String] = []
    if index == 0 {
      properties.push("marker-start")
    }
    if index > 0 && index + 1 < vertices.length() {
      properties.push("marker-mid")
    }
    if index + 1 == vertices.length() {
      properties.push("marker-end")
    }
    for property in properties {
      guard marker_reference_id(subject_value(subject, property)) is Some(id) else {
        continue
      }
      guard marker_resource(resources, id) is Some(resource) else { continue }
      if !resource.complete ||
        resource.marker_width == 0.0 ||
        resource.marker_height == 0.0 {
        continue
      }
      let mut angle = if resource.orient_kind == "angle" {
        resource.orient_angle
      } else {
        vertex.auto_angle
      }
      if resource.orient_kind == "auto-start-reverse" &&
        property == "marker-start" {
        angle += 180.0
      }
      let unit_scale = if resource.marker_units == "strokeWidth" {
        stroke_subject_width(subject)
      } else {
        1.0
      }
      let (mapped_ref_x, mapped_ref_y) = resource.viewport_matrix.apply_point(
        resource.ref_x,
        resource.ref_y,
      )
      let marker_local = AffineTransform::translate(vertex.x, vertex.y)
        .multiply(AffineTransform::rotate(angle))
        .multiply(AffineTransform::scale(unit_scale, unit_scale))
        .multiply(AffineTransform::translate(-mapped_ref_x, -mapped_ref_y))
      let transform = if subject.stroke_non_scaling &&
        resource.marker_units == "strokeWidth" {
        let position = subject.cumulative_transform.apply_point(
          vertex.x,
          vertex.y,
        )
        angle = subject.cumulative_transform.apply_direction_angle(angle)
        AffineTransform::translate(position.0, position.1)
        .multiply(AffineTransform::rotate(angle))
        .multiply(AffineTransform::scale(unit_scale, unit_scale))
        .multiply(AffineTransform::translate(-mapped_ref_x, -mapped_ref_y))
      } else {
        subject.cumulative_transform.multiply(marker_local)
      }
      placements.push({
        resource_id: id,
        bounds: marker_placement_bounds(
          transform,
          resource.marker_width,
          resource.marker_height,
        ),
      })
    }
  }
  placements
}

///|
pub fn marker_fact_for_property(
  subject : SourceSubject,
  property : String,
) -> DeclaredVisualFact? {
  match shape_fact(subject.marker_effective_facts, property) {
    Some(fact) => Some(fact)
    None => shape_fact(subject.facts, "marker")
  }
}

///|
pub fn resolve_marker_subjects_or_raise(
  input : String,
  subjects : Array[SourceSubject],
  profile : ComparisonProfile,
) -> Array[SourceSubject] raise {
  let resources = extract_marker_resources_or_raise(input, profile)
  let resolved : Array[SourceSubject] = []
  for subject in subjects {
    let invalid_facts = subject.marker_invalid_facts.copy()
    let mut complete = subject.marker_complete
    for property in ["marker-start", "marker-mid", "marker-end"] {
      match marker_reference_id(subject_value(subject, property)) {
        Some(id) =>
          match marker_resource(resources, id) {
            Some(resource) if resource.complete => ()
            _ => {
              complete = false
              push_invalid_stroke_fact(
                invalid_facts,
                marker_fact_for_property(subject, property),
              )
            }
          }
        None => ()
      }
    }
    let placements = if complete {
      marker_placements_for_subject(subject, resources)
    } else {
      []
    }
    resolved.push({
      ..subject,
      marker_invalid_facts: invalid_facts,
      marker_complete: complete,
      marker_active: complete && subject_references_marker(subject, None),
      marker_placements: placements,
    })
  }
  resolved
}

///|
pub fn append_marker_geometry_diagnostics(
  subjects : Array[SourceSubject],
  source_role : String,
  diagnostics : Array[Diagnostic],
) -> Unit {
  for subject in subjects {
    let subject_id = source_subject_id(subject)
    if !subject.marker_complete {
      merge_diagnostic_into(diagnostics, {
        ..unlocated_diagnostic(
          "diagnostic:marker-semantics-unsupported:\{subject_id}",
          "marker_semantics_unsupported",
          subject_id,
          ["source_semantics", "computed_appearance", "rendered_evidence"],
        ),
        source_locations: subject.marker_invalid_facts.map(fn(fact) {
          diagnostic_location(source_role, fact.source_span)
        }),
      })
    }
    if subject.marker_active {
      let locations : Array[DiagnosticSourceLocation] = []
      for property in ["marker-start", "marker-mid", "marker-end"] {
        match shape_fact(subject.marker_effective_facts, property) {
          Some(fact) =>
            locations.push(diagnostic_location(source_role, fact.source_span))
          None => ()
        }
      }
      merge_diagnostic_into(diagnostics, {
        ..unlocated_diagnostic(
          "diagnostic:marker-content-semantics-unsupported:\{subject_id}",
          "marker_content_semantics_unsupported",
          subject_id,
          ["computed_appearance", "rendered_evidence"],
        ),
        source_locations: locations,
      })
      merge_diagnostic_into(diagnostics, {
        ..unlocated_diagnostic(
          "diagnostic:renderer-marker-raster-unproven:\{subject_id}",
          "renderer_marker_raster_unproven",
          subject_id,
          ["rendered_evidence"],
        ),
        source_locations: locations,
      })
    }
  }
}

///|
pub fn marker_subject_bounds(subject : SourceSubject) -> CssBounds? {
  let mut bounds : CssBounds? = None
  for placement in subject.marker_placements {
    bounds = union_bounds(bounds, Some(placement.bounds))
  }
  bounds
}

///|
pub fn source_subject_unclipped_bounds(subject : SourceSubject) -> CssBounds? {
  let geometry_bounds = source_subject_geometry_bounds(subject)
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
pub fn source_subject_bounds(subject : SourceSubject) -> CssBounds? {
  match subject.mask_effect_bounds {
    Some(bounds) => return Some(bounds)
    None if subject.mask_complete && subject.mask_resource_id is Some(_) =>
      return None
    _ => ()
  }
  match subject.clip_effect_bounds {
    Some(bounds) => Some(bounds)
    None if subject.clip_complete && subject.clip_resource_id is Some(_) => None
    None => source_subject_unclipped_bounds(subject)
  }
}
