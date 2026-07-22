///|
pub(all) struct MaskSemanticIssue {
  code : String
  subject_id : String
  fact : DeclaredVisualFact?
}

///|
pub(all) struct MaskLength {
  value : Double
  percentage : Bool
}

///|
pub(all) struct MaskRectResource {
  subject_id : String
  authored_id : String?
  presence_fact : DeclaredVisualFact
  mask_units : String
  mask_units_fact : DeclaredVisualFact?
  content_units : String
  content_units_fact : DeclaredVisualFact?
  region_x : MaskLength
  region_y : MaskLength
  region_width : MaskLength
  region_height : MaskLength
  region_facts : Array[DeclaredVisualFact]
  mask_type : String
  mask_type_fact : DeclaredVisualFact?
  color_interpolation : String
  color_interpolation_fact : DeclaredVisualFact?
  mut child_count : Int
  mut rect_source_offset : Int?
  mut rect_facts : Array[DeclaredVisualFact]
  mut rect_transform_fact : DeclaredVisualFact?
  mut rect_transform : AffineTransform
  mut rect_bounds : CssBounds?
  mut color_signature : String
  mut color_red : Int
  mut color_green : Int
  mut color_blue : Int
  mut content_alpha : Double
  mut content_luminance : Double
  mut complete : Bool
}

///|
pub(all) struct MaskSemanticDocument {
  hierarchy : FillHierarchy
  resources : Array[MaskRectResource]
  id_kinds : Array[(String, String)]
  issues : Array[MaskSemanticIssue]
}

///|
pub(all) struct MaskHostAttachment {
  subject_id : String
  mask_fact : DeclaredVisualFact
  mask_value : String
  mode_fact : DeclaredVisualFact?
  mode_value : String
}

///|
pub fn mask_issue(
  document : MaskSemanticDocument,
  code : String,
  subject_id : String,
  fact : DeclaredVisualFact?,
) -> Unit {
  if !document.issues.any(issue => {
      issue.code == code &&
      issue.subject_id == subject_id &&
      issue.fact.map(value => {
        (value.source_span.start_offset, value.source_span.end_offset)
      }) ==
      fact.map(value => {
        (value.source_span.start_offset, value.source_span.end_offset)
      })
    }) {
    document.issues.push({ code, subject_id, fact })
  }
}

///|
pub fn mask_dynamic_kind(kind : String) -> Bool {
  kind == "animate" ||
  kind == "animateTransform" ||
  kind == "animateMotion" ||
  kind == "set"
}

///|
pub fn mask_default_length(property : String) -> MaskLength {
  match property {
    "x" | "y" => { value: -0.1, percentage: true }
    "width" | "height" => { value: 1.2, percentage: true }
    _ => { value: 0.0, percentage: false }
  }
}

///|
pub fn mask_length_from_fact(
  fact : DeclaredVisualFact?,
  property : String,
  units : String,
  profile : ComparisonProfile,
) -> (MaskLength, Bool) {
  guard fact is Some(fact) else { return (mask_default_length(property), true) }
  let source = fact.declared_value.trim().to_owned()
  if source.has_suffix("%") {
    guard parse_shape_number(
        source.view(end_offset=source.length() - 1).to_owned(),
      )
      is Some(value) else {
      return (mask_default_length(property), false)
    }
    return ({ value: value / 100.0, percentage: true }, true)
  }
  if units == "objectBoundingBox" {
    return match parse_shape_number(source) {
      Some(value) => ({ value, percentage: false }, true)
      None => (mask_default_length(property), false)
    }
  }
  match
    parse_svg_length(
      source,
      basic_shape_length_direction(property),
      {
        width: profile.viewport_width.to_double(),
        height: profile.viewport_height.to_double(),
      },
      profile,
    ) {
    Some(value) => ({ value, percentage: false }, true)
    None => (mask_default_length(property), false)
  }
}

///|
pub fn mask_resource_from_element(
  input : String,
  element : @xml.NamespaceElement,
  source_offset : Int,
  source_end_offset : Int,
  hierarchy : FillHierarchy,
  profile : ComparisonProfile,
) -> MaskRectResource {
  let authored_id = authored_subject_id(element)
  let subject_id = authored_id.unwrap_or(
    clip_hierarchy_subject_id_at(hierarchy, source_offset, "mask"),
  )
  let mask_units_fact = clip_attribute(element, "maskUnits").map(attribute => {
    presentation_fact(input, "maskUnits", attribute)
  })
  let mask_units = mask_units_fact
    .map(fact => fact.declared_value.trim().to_owned())
    .unwrap_or("objectBoundingBox")
  let content_units_fact = clip_attribute(element, "maskContentUnits").map(attribute => {
    presentation_fact(input, "maskContentUnits", attribute)
  })
  let content_units = content_units_fact
    .map(fact => fact.declared_value.trim().to_owned())
    .unwrap_or("userSpaceOnUse")
  let region_facts : Array[DeclaredVisualFact] = []
  let lengths : Array[MaskLength] = []
  let mut lengths_complete = true
  for property in ["x", "y", "width", "height"] {
    let fact = clip_attribute(element, property).map(attribute => {
      presentation_fact(input, property, attribute)
    })
    match fact {
      Some(fact) => region_facts.push(fact)
      None => ()
    }
    let parsed = mask_length_from_fact(fact, property, mask_units, profile)
    lengths.push(parsed.0)
    lengths_complete = lengths_complete && parsed.1
  }
  let mask_type_resolution = computed_visual_for_subject(
    hierarchy, subject_id, "mask-type",
  )
  let mask_type = mask_type_resolution
    .map(value => value.reported.resolved_value)
    .unwrap_or("luminance")
  let mask_type_fact = mask_type_resolution.bind(value => {
    value.reported.declaration
  })
  let interpolation_resolution = computed_visual_for_subject(
    hierarchy, subject_id, "color-interpolation",
  )
  let color_interpolation = interpolation_resolution
    .map(value => value.reported.resolved_value)
    .unwrap_or("srgb")
  let color_interpolation_fact = interpolation_resolution.bind(value => {
    value.reported.declaration
  })
  {
    subject_id,
    authored_id,
    presence_fact: clip_source_fact(
      input, "presence", source_offset, source_end_offset,
    ),
    mask_units,
    mask_units_fact,
    content_units,
    content_units_fact,
    region_x: lengths[0],
    region_y: lengths[1],
    region_width: lengths[2],
    region_height: lengths[3],
    region_facts,
    mask_type,
    mask_type_fact,
    color_interpolation,
    color_interpolation_fact,
    child_count: 0,
    rect_source_offset: None,
    rect_facts: [],
    rect_transform_fact: None,
    rect_transform: AffineTransform::identity(),
    rect_bounds: None,
    color_signature: "rgba(0,0,0,0)",
    color_red: 0,
    color_green: 0,
    color_blue: 0,
    content_alpha: 0.0,
    content_luminance: 0.0,
    complete: (
      mask_units == "userSpaceOnUse" || mask_units == "objectBoundingBox"
    ) &&
    (content_units == "userSpaceOnUse" || content_units == "objectBoundingBox") &&
    (mask_type == "alpha" || mask_type == "luminance") &&
    color_interpolation == "srgb" &&
    lengths_complete &&
    fill_source_element(hierarchy, subject_id) is Some(_),
  }
}

///|
pub fn mask_content_number(
  source : String,
  property : String,
  units : String,
  profile : ComparisonProfile,
) -> Double? {
  let value = source.trim().to_owned()
  if units == "objectBoundingBox" {
    if value.has_suffix("%") {
      return parse_shape_number(
        value.view(end_offset=value.length() - 1).to_owned(),
      ).map(number => number / 100.0)
    }
    return parse_shape_number(value)
  }
  parse_svg_length(
    value,
    basic_shape_length_direction(property),
    {
      width: profile.viewport_width.to_double(),
      height: profile.viewport_height.to_double(),
    },
    profile,
  )
}

///|
pub fn mask_content_resolved_number(
  hierarchy : FillHierarchy,
  subject_id : String,
  property : String,
  units : String,
  profile : ComparisonProfile,
) -> (Double, Bool) {
  guard computed_visual_for_subject(hierarchy, subject_id, property)
    is Some(resolution) &&
    resolution.complete else {
    return (0.0, false)
  }
  let source = resolution.reported.resolved_value
  if source == "auto" {
    return (0.0, true)
  }
  match mask_content_number(source, property, units, profile) {
    Some(number) if (property != "width" && property != "height") ||
      number >= 0.0 => (number, true)
    _ => (0.0, false)
  }
}

///|
pub fn mask_record_direct_child(
  input : String,
  element : @xml.NamespaceElement,
  source_offset : Int,
  source_end_offset : Int,
  profile : ComparisonProfile,
  document : MaskSemanticDocument,
  resource_index : Int,
) -> Unit {
  let resource = document.resources[resource_index]
  let kind = element.name.local_name
  if kind == "title" || kind == "desc" || kind == "metadata" {
    return
  }
  resource.child_count += 1
  if kind != "rect" || resource.child_count != 1 {
    resource.complete = false
    mask_issue(
      document,
      if resource.child_count != 1 {
        "mask_content_multiple_unsupported"
      } else {
        "mask_content_unsupported"
      },
      resource.subject_id,
      Some(clip_source_fact(input, "content", source_offset, source_end_offset)),
    )
    return
  }
  let rect_subject_id = authored_subject_id(element).unwrap_or(
    clip_hierarchy_subject_id_at(document.hierarchy, source_offset, "rect"),
  )
  for property in ["clip-path", "mask"] {
    match
      computed_visual_for_subject(document.hierarchy, rect_subject_id, property) {
      Some(resolution) if resolution.reported.resolved_value != "none" => {
        resource.complete = false
        mask_issue(
          document,
          "mask_nested_effect_unsupported",
          resource.subject_id,
          resolution.reported.declaration,
        )
      }
      _ => ()
    }
  }
  match clip_attribute(element, "filter") {
    Some(attribute) if attribute.value.trim().to_lower() != "none" => {
      resource.complete = false
      mask_issue(
        document,
        "mask_nested_effect_unsupported",
        resource.subject_id,
        Some(presentation_fact(input, "filter", attribute)),
      )
    }
    _ => ()
  }
  resource.rect_source_offset = Some(source_offset)
  resource.rect_facts = computed_visual_facts_for_subject(
    document.hierarchy,
    rect_subject_id,
  )
  let transform_fact = clip_attribute(element, "transform").map(attribute => {
    presentation_fact(input, "transform", attribute)
  })
  let transform = clip_transform_from_fact(transform_fact)
  resource.rect_transform_fact = transform_fact
  resource.rect_transform = transform.0
  let x = mask_content_resolved_number(
    document.hierarchy,
    rect_subject_id,
    "x",
    resource.content_units,
    profile,
  )
  let y = mask_content_resolved_number(
    document.hierarchy,
    rect_subject_id,
    "y",
    resource.content_units,
    profile,
  )
  let width = mask_content_resolved_number(
    document.hierarchy,
    rect_subject_id,
    "width",
    resource.content_units,
    profile,
  )
  let height = mask_content_resolved_number(
    document.hierarchy,
    rect_subject_id,
    "height",
    resource.content_units,
    profile,
  )
  let rx = mask_content_resolved_number(
    document.hierarchy,
    rect_subject_id,
    "rx",
    resource.content_units,
    profile,
  )
  let ry = mask_content_resolved_number(
    document.hierarchy,
    rect_subject_id,
    "ry",
    resource.content_units,
    profile,
  )
  resource.rect_bounds = Some({
    x: x.0,
    y: y.0,
    width: width.0,
    height: height.0,
  })
  let fill = computed_visual_for_subject(
    document.hierarchy,
    rect_subject_id,
    "fill",
  )
  let fill_opacity = computed_visual_for_subject(
    document.hierarchy,
    rect_subject_id,
    "fill-opacity",
  )
  let opacity = computed_visual_for_subject(
    document.hierarchy,
    rect_subject_id,
    "opacity",
  )
  let stroke = computed_visual_for_subject(
    document.hierarchy,
    rect_subject_id,
    "stroke",
  )
  let mut paint_complete = false
  guard fill is Some(fill) &&
    fill.complete &&
    fill_opacity is Some(fill_opacity) &&
    fill_opacity.complete &&
    opacity is Some(opacity) &&
    opacity.complete &&
    stroke is Some(stroke) &&
    stroke.complete else {
    resource.complete = false
    mask_issue(document, "mask_paint_unsupported", resource.subject_id, None)
    return
  }
  match @css_color.parse_solid_color(fill.reported.resolved_value) {
    Resolved(color) => {
      let fill_alpha = @css_color.parse_alpha_value(
        fill_opacity.reported.resolved_value,
      ).unwrap_or(0.0)
      let object_alpha = @css_color.parse_alpha_value(
        opacity.reported.resolved_value,
      ).unwrap_or(0.0)
      resource.color_signature = color.signature()
      resource.color_red = color.red
      resource.color_green = color.green
      resource.color_blue = color.blue
      resource.content_alpha = color.alpha * fill_alpha * object_alpha
      resource.content_luminance = (
          0.2126 * color.red.to_double() / 255.0 +
          0.7152 * color.green.to_double() / 255.0 +
          0.0722 * color.blue.to_double() / 255.0
        ) *
        resource.content_alpha
      paint_complete = stroke.reported.resolved_value == "none"
    }
    _ => ()
  }
  let geometry_complete = x.1 &&
    y.1 &&
    width.1 &&
    height.1 &&
    rx.1 &&
    ry.1 &&
    rx.0 == 0.0 &&
    ry.0 == 0.0
  if !geometry_complete || !transform.1 || !paint_complete {
    resource.complete = false
    mask_issue(
      document,
      if !transform.1 {
        "mask_transform_unproven"
      } else if !geometry_complete {
        "mask_geometry_unsupported"
      } else {
        "mask_paint_unsupported"
      },
      resource.subject_id,
      if !transform.1 {
        transform_fact
      } else if !geometry_complete {
        match shape_fact(resource.rect_facts, "rx") {
          Some(fact) => Some(fact)
          None =>
            match shape_fact(resource.rect_facts, "ry") {
              Some(fact) => Some(fact)
              None =>
                match shape_fact(resource.rect_facts, "width") {
                  Some(fact) => Some(fact)
                  None => shape_fact(resource.rect_facts, "height")
                }
            }
        }
      } else {
        match fill.reported.declaration {
          Some(fact) => Some(fact)
          None => stroke.reported.declaration
        }
      },
    )
  }
}

///|
pub fn extract_mask_semantic_document_or_raise(
  input : String,
  profile : ComparisonProfile,
) -> MaskSemanticDocument raise {
  let hierarchy = extract_fill_hierarchy_or_raise(input)
  let document : MaskSemanticDocument = {
    hierarchy,
    resources: [],
    id_kinds: [],
    issues: [],
  }
  let reader = @xml.NamespaceReader::from_string(input)
  let mut active : Int? = None
  let mut depth = 0
  for event in reader.read_events_until_eof() {
    match event.kind {
      Start(element) => {
        match authored_subject_id(element) {
          Some(id) => document.id_kinds.push((id, element.name.local_name))
          None => ()
        }
        match active {
          Some(index) => {
            if mask_dynamic_kind(element.name.local_name) {
              document.resources[index].complete = false
              mask_issue(
                document,
                "mask_dynamic_unsupported",
                document.resources[index].subject_id,
                Some(
                  clip_source_fact(
                    input,
                    "content",
                    event.span.start.offset,
                    event.span.end.offset,
                  ),
                ),
              )
            }
            if depth == 1 {
              mask_record_direct_child(
                input,
                element,
                event.span.start.offset,
                event.span.end.offset,
                profile,
                document,
                index,
              )
            }
            depth += 1
          }
          None if element.name.local_name == "mask" => {
            document.resources.push(
              mask_resource_from_element(
                input,
                element,
                event.span.start.offset,
                event.span.end.offset,
                hierarchy,
                profile,
              ),
            )
            active = Some(document.resources.length() - 1)
            depth = 1
          }
          _ => ()
        }
      }
      Empty(element) => {
        match authored_subject_id(element) {
          Some(id) => document.id_kinds.push((id, element.name.local_name))
          None => ()
        }
        match active {
          Some(index) if mask_dynamic_kind(element.name.local_name) => {
            document.resources[index].complete = false
            mask_issue(
              document,
              "mask_dynamic_unsupported",
              document.resources[index].subject_id,
              Some(
                clip_source_fact(
                  input,
                  "content",
                  event.span.start.offset,
                  event.span.end.offset,
                ),
              ),
            )
          }
          Some(index) if depth == 1 =>
            mask_record_direct_child(
              input,
              element,
              event.span.start.offset,
              event.span.end.offset,
              profile,
              document,
              index,
            )
          _ if element.name.local_name == "mask" =>
            document.resources.push(
              mask_resource_from_element(
                input,
                element,
                event.span.start.offset,
                event.span.end.offset,
                hierarchy,
                profile,
              ),
            )
          _ => ()
        }
      }
      End(_) =>
        match active {
          Some(_) => {
            depth -= 1
            if depth == 0 {
              active = None
            }
          }
          None => ()
        }
      _ => ()
    }
  }
  for resource in document.resources {
    if resource.child_count > 1 {
      resource.complete = false
    }
    if resource.mask_units != "userSpaceOnUse" &&
      resource.mask_units != "objectBoundingBox" {
      resource.complete = false
      mask_issue(
        document,
        "mask_units_invalid",
        resource.subject_id,
        resource.mask_units_fact,
      )
    }
    if resource.content_units != "userSpaceOnUse" &&
      resource.content_units != "objectBoundingBox" {
      resource.complete = false
      mask_issue(
        document,
        "mask_content_units_invalid",
        resource.subject_id,
        resource.content_units_fact,
      )
    }
    if resource.mask_type != "alpha" && resource.mask_type != "luminance" {
      resource.complete = false
      mask_issue(
        document,
        "mask_type_invalid",
        resource.subject_id,
        resource.mask_type_fact,
      )
    }
    if resource.color_interpolation == "linearrgb" {
      resource.complete = false
      mask_issue(
        document,
        "mask_linear_rgb_unsupported",
        resource.subject_id,
        resource.color_interpolation_fact,
      )
    } else if resource.color_interpolation != "srgb" {
      resource.complete = false
      mask_issue(
        document,
        "mask_color_interpolation_invalid",
        resource.subject_id,
        resource.color_interpolation_fact,
      )
    }
  }
  document
}

///|
pub fn source_has_mask_resources(
  input : String,
  profile : ComparisonProfile,
) -> Bool {
  let document = extract_mask_semantic_document_or_raise(input, profile) catch {
    _ => return false
  }
  !document.resources.is_empty()
}

///|
pub fn mask_resource_for_id(
  document : MaskSemanticDocument,
  id : String,
) -> MaskRectResource? {
  for resource in document.resources {
    if resource.authored_id == Some(id) {
      return Some(resource)
    }
  }
  None
}

///|
pub fn mask_target_kind(
  document : MaskSemanticDocument,
  id : String,
) -> String? {
  for entry in document.id_kinds {
    if entry.0 == id {
      return Some(entry.1)
    }
  }
  None
}

///|
pub fn mask_active_resolution_for_subject(
  hierarchy : FillHierarchy,
  subject : SourceSubject,
) -> (String, String, String, ResolvedVisualFact, Int)? {
  let mut index : Int? = None
  for current_index, element in hierarchy.elements {
    if element.source_offset == subject.source_offset {
      index = Some(current_index)
      break
    }
  }
  let mut current = index
  let mut owner_depth = 0
  while current is Some(current_index) {
    let element = hierarchy.elements[current_index]
    match computed_visual_for_subject(hierarchy, element.subject_id, "mask") {
      Some(resolution) if resolution.reported.declaration is Some(_) &&
        resolution.reported.resolved_value != "none" => {
        let mode = computed_visual_for_subject(
            hierarchy,
            element.subject_id,
            "mask-mode",
          )
          .map(value => value.reported.resolved_value)
          .unwrap_or("match-source")
        return Some(
          (
            element.subject_id,
            resolution.reported.resolved_value,
            mode,
            resolution.reported,
            owner_depth,
          ),
        )
      }
      _ => ()
    }
    current = element.parent_index
    owner_depth += 1
  }
  None
}

///|
pub fn mask_owner_has_group_opacity(
  hierarchy : FillHierarchy,
  owner_id : String,
) -> Bool {
  guard fill_source_element(hierarchy, owner_id) is Some((owner_index, _)) else {
    return false
  }
  for index, element in hierarchy.elements {
    if !group_opacity_container(element.kind) {
      continue
    }
    let mut current : Int? = Some(index)
    let mut below_owner = false
    while current is Some(current_index) {
      if current_index == owner_index {
        below_owner = true
        break
      }
      current = hierarchy.elements[current_index].parent_index
    }
    if !below_owner {
      continue
    }
    match
      computed_visual_for_subject(hierarchy, element.subject_id, "opacity") {
      Some(value) if value.complete &&
        @css_color.parse_alpha_value(value.reported.resolved_value)
        .map(alpha => alpha != 1.0)
        .unwrap_or(false) => return true
      _ => ()
    }
  }
  false
}

///|
pub fn resolved_mask_length(
  length : MaskLength,
  origin : Double,
  size : Double,
  coordinate : Bool,
) -> Double {
  if length.percentage {
    if coordinate {
      origin + length.value * size
    } else {
      length.value * size
    }
  } else {
    length.value
  }
}

///|
pub fn mask_region_local_bounds(
  resource : MaskRectResource,
  host : CssBounds,
) -> CssBounds {
  {
    x: resolved_mask_length(resource.region_x, host.x, host.width, true),
    y: resolved_mask_length(resource.region_y, host.y, host.height, true),
    width: resolved_mask_length(resource.region_width, 0.0, host.width, false),
    height: resolved_mask_length(
      resource.region_height,
      0.0,
      host.height,
      false,
    ),
  }
}

///|
pub fn mask_application_bounds(
  subject : SourceSubject,
  owner_depth : Int,
  resource : MaskRectResource,
  effective_mode : String,
) -> (CssBounds?, Bool) {
  guard source_subject_geometry_bounds(subject) is Some(host_local) else {
    return (None, false)
  }
  let owner_transform = clip_owner_transform(subject, owner_depth)
  if !owner_transform.1 {
    return (None, false)
  }
  let host_painted = match subject.clip_effect_bounds {
    Some(bounds) => Some(bounds)
    None if subject.clip_complete && subject.clip_resource_id is Some(_) => None
    _ => source_subject_unclipped_bounds(subject)
  }
  guard host_painted is Some(host_painted) else {
    return (None, subject.clip_complete)
  }
  if (
      resource.mask_units == "objectBoundingBox" ||
      resource.content_units == "objectBoundingBox"
    ) &&
    owner_depth != 0 {
    return (None, false)
  }
  let region_host : CssBounds = if resource.mask_units == "objectBoundingBox" {
    { x: 0.0, y: 0.0, width: 1.0, height: 1.0 }
  } else {
    host_local
  }
  let region_local = mask_region_local_bounds(resource, region_host)
  if region_local.width <= 0.0 || region_local.height <= 0.0 {
    return (None, true)
  }
  let region_matrix = if resource.mask_units == "objectBoundingBox" {
    owner_transform.0
    .multiply(AffineTransform::translate(host_local.x, host_local.y))
    .multiply(AffineTransform::scale(host_local.width, host_local.height))
  } else {
    owner_transform.0
  }
  let region_bounds = transform_bounds(region_local, region_matrix)
  guard resource.rect_bounds is Some(rect) else { return (None, true) }
  let mask_value = if effective_mode == "alpha" {
    resource.content_alpha
  } else {
    resource.content_luminance
  }
  if mask_value <= 0.0 || rect.width <= 0.0 || rect.height <= 0.0 {
    return (None, true)
  }
  let content_matrix = if resource.content_units == "objectBoundingBox" {
    owner_transform.0
    .multiply(AffineTransform::translate(host_local.x, host_local.y))
    .multiply(AffineTransform::scale(host_local.width, host_local.height))
    .multiply(resource.rect_transform)
  } else {
    owner_transform.0.multiply(resource.rect_transform)
  }
  let content_bounds = transform_bounds(rect, content_matrix)
  guard intersect_bounds(region_bounds, content_bounds) is Some(mask_bounds) else {
    return (None, true)
  }
  (intersect_bounds(host_painted, mask_bounds), true)
}

///|
pub fn resolve_mask_subjects_or_raise(
  input : String,
  subjects : Array[SourceSubject],
  profile : ComparisonProfile,
) -> Array[SourceSubject] raise {
  let document = extract_mask_semantic_document_or_raise(input, profile)
  let resolved : Array[SourceSubject] = []
  for subject in subjects {
    match mask_active_resolution_for_subject(document.hierarchy, subject) {
      None => resolved.push(subject)
      Some((owner, source, mode, resolution, owner_depth)) => {
        let codes : Array[String] = []
        let mut resource_id : String? = None
        let mut effect_bounds : CssBounds? = None
        let mut effective_mode : String? = None
        let mut outcome : String? = None
        let mut complete = resolution.declaration is Some(_)
        match parse_mask_reference(source) {
          MaskLocal(id) => {
            resource_id = Some(id)
            match mask_resource_for_id(document, id) {
              Some(resource) => {
                outcome = Some("resolved")
                complete = complete && resource.complete
                let selected_mode = if mode == "match-source" {
                  resource.mask_type
                } else {
                  mode
                }
                effective_mode = Some(selected_mode)
                if selected_mode != "alpha" && selected_mode != "luminance" {
                  complete = false
                  push_unique(codes, "mask_mode_invalid")
                }
                let application = mask_application_bounds(
                  subject, owner_depth, resource, selected_mode,
                )
                effect_bounds = application.0
                if (
                    resource.mask_units == "objectBoundingBox" ||
                    resource.content_units == "objectBoundingBox"
                  ) &&
                  owner_depth != 0 {
                  complete = false
                  push_unique(codes, "mask_object_bbox_container_unsupported")
                } else if resource.complete && !application.1 {
                  complete = false
                  push_unique(codes, "mask_effect_bounds_unavailable")
                }
                if !resource.complete {
                  for issue in document.issues {
                    if issue.subject_id == resource.subject_id {
                      push_unique(codes, issue.code)
                    }
                  }
                }
              }
              None => {
                // CSS Masking defines missing and wrong-kind mask layers as
                // transparent black, so the target is deterministically hidden.
                complete = true
                effect_bounds = None
                effective_mode = Some(
                  if mode == "match-source" {
                    "luminance"
                  } else {
                    mode
                  },
                )
                outcome = Some(
                  match mask_target_kind(document, id) {
                    Some(_) => "transparent_black_wrong_kind"
                    None => "transparent_black_missing"
                  },
                )
              }
            }
          }
          MaskExternal => {
            complete = false
            push_unique(codes, "mask_external_reference_unsupported")
          }
          MaskInvalid => {
            complete = false
            push_unique(codes, "mask_reference_invalid")
          }
          MaskNone => ()
        }
        if subject.reference.instance_context is Some(_) {
          complete = false
          effect_bounds = None
          push_unique(codes, "mask_instance_unsupported")
        }
        if mask_owner_has_group_opacity(document.hierarchy, owner) {
          complete = false
          push_unique(codes, "mask_group_opacity_interaction_unsupported")
        }
        resolved.push({
          ..subject,
          mask_owner_id: Some(owner),
          mask_resource_id: resource_id,
          mask_mode: effective_mode,
          mask_outcome: outcome,
          mask_complete: complete,
          mask_effect_bounds: effect_bounds,
          mask_issue_codes: codes,
        })
      }
    }
  }
  for index, subject in resolved {
    guard subject.mask_resource_id is Some(resource_id) &&
      subject.mask_mode is Some(mode) else {
      continue
    }
    let conflict = resolved.any(other => {
      other.mask_resource_id == Some(resource_id) &&
      other.mask_mode is Some(other_mode) &&
      other_mode != mode
    })
    if conflict {
      let codes = subject.mask_issue_codes.copy()
      push_unique(codes, "mask_shared_mode_override_unsupported")
      resolved[index] = {
        ..subject,
        mask_complete: false,
        mask_effect_bounds: None,
        mask_issue_codes: codes,
      }
    }
  }
  resolved
}

///|
pub fn append_mask_diagnostics(
  input : String,
  profile : ComparisonProfile,
  source_role : String,
  diagnostics : Array[Diagnostic],
) -> Unit raise {
  let document = extract_mask_semantic_document_or_raise(input, profile)
  for issue in document.issues {
    merge_diagnostic_into(diagnostics, {
      id: "diagnostic:\{issue.code}:\{issue.subject_id}",
      code: issue.code,
      subject_id: issue.subject_id,
      affected_evidence_layers: ["computed_appearance", "rendered_evidence"],
      source_locations: issue.fact
      .map(fact => [diagnostic_location(source_role, fact.source_span)])
      .unwrap_or([]),
    })
  }
  let subjects = resolve_mask_subjects_or_raise(
    input,
    resolve_clip_subjects_or_raise(
      input,
      extract_source_subjects_without_clip_or_raise(input, profile),
      profile,
    ),
    profile,
  )
  for subject in subjects {
    let fact = mask_active_resolution_for_subject(document.hierarchy, subject).bind(entry => {
        entry.3.declaration
      },
    )
    for code in subject.mask_issue_codes {
      merge_diagnostic_into(diagnostics, {
        id: "diagnostic:\{code}:\{source_subject_id(subject)}",
        code,
        subject_id: source_subject_id(subject),
        affected_evidence_layers: ["computed_appearance", "rendered_evidence"],
        source_locations: fact
        .map(value => [diagnostic_location(source_role, value.source_span)])
        .unwrap_or([]),
      })
    }
  }
  for element in document.hierarchy.elements {
    if element.kind != "use" {
      continue
    }
    match
      computed_visual_for_subject(
        document.hierarchy,
        element.subject_id,
        "mask",
      ) {
      Some(resolution) if resolution.reported.resolved_value != "none" =>
        merge_diagnostic_into(diagnostics, {
          id: "diagnostic:mask_instance_unsupported:\{element.subject_id}",
          code: "mask_instance_unsupported",
          subject_id: element.subject_id,
          affected_evidence_layers: ["computed_appearance", "rendered_evidence"],
          source_locations: resolution.reported.declaration
          .map(value => [diagnostic_location(source_role, value.source_span)])
          .unwrap_or([]),
        })
      _ => ()
    }
  }
}

///|
