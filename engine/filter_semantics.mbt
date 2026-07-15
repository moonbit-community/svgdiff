///|
priv enum FilterReference {
  FilterNone
  FilterLocal(String)
  FilterExternal
  FilterInvalid
}

///|
priv struct FilterLength {
  value : Double
  percentage : Bool
}

///|
priv struct FilterOffsetPrimitive {
  index : Int
  subject_id : String
  presence_fact : DeclaredVisualFact
  input : String
  input_fact : DeclaredVisualFact?
  result : String?
  result_fact : DeclaredVisualFact?
  dx : Double
  dx_fact : DeclaredVisualFact?
  dy : Double
  dy_fact : DeclaredVisualFact?
  region_fact : DeclaredVisualFact?
  complete : Bool
}

///|
priv struct FilterResource {
  subject_id : String
  authored_id : String?
  presence_fact : DeclaredVisualFact
  filter_units : String
  filter_units_fact : DeclaredVisualFact?
  primitive_units : String
  primitive_units_fact : DeclaredVisualFact?
  template_fact : DeclaredVisualFact?
  region_x : FilterLength
  region_y : FilterLength
  region_width : FilterLength
  region_height : FilterLength
  region_facts : Array[DeclaredVisualFact]
  primitives : Array[FilterOffsetPrimitive]
  mut complete : Bool
}

///|
priv struct FilterSemanticIssue {
  code : String
  subject_id : String
  fact : DeclaredVisualFact?
}

///|
priv struct FilterSemanticDocument {
  hierarchy : FillHierarchy
  resources : Array[FilterResource]
  id_kinds : Array[(String, String)]
  issues : Array[FilterSemanticIssue]
}

///|
priv struct ResolvedFilterHost {
  owner_id : String
  filter_fact : DeclaredVisualFact
  resource_id : String?
  resource : FilterResource?
  target_bounds : CssBounds?
  filter_region : CssBounds?
  primitive_offsets : Array[(Int, Int)]
  primitive_bounds : Array[CssBounds?]
  effect_bounds : CssBounds?
  complete : Bool
  issue_codes : Array[String]
}

///|
priv struct FilterHostAttachment {
  owner_id : String
  fact : DeclaredVisualFact
  value : String
}

///|
fn parse_filter_reference(source : String) -> FilterReference {
  let value = source.trim().to_owned()
  if value.to_lower() == "none" {
    return FilterNone
  }
  if value.length() < 6 ||
    !value.to_lower().has_prefix("url(") ||
    !value.has_suffix(")") {
    return FilterInvalid
  }
  let mut locator = value
    .view(start_offset=4, end_offset=value.length() - 1)
    .to_owned()
    .trim()
    .to_owned()
  if locator.length() >= 2 &&
    (
      (locator.has_prefix("'") && locator.has_suffix("'")) ||
      (locator.has_prefix("\"") && locator.has_suffix("\""))
    ) {
    locator = locator
      .view(start_offset=1, end_offset=locator.length() - 1)
      .to_owned()
      .trim()
      .to_owned()
  }
  if locator.length() > 1 && locator.has_prefix("#") {
    let id = decode_local_fragment(locator.view(start_offset=1).to_owned())
    if id != "" &&
      id.find("#") is None &&
      id.find(" ") is None &&
      id.find("\t") is None &&
      id.find("\n") is None &&
      id.find("\r") is None {
      return FilterLocal(id)
    }
    return FilterInvalid
  }
  if locator == "" {
    FilterInvalid
  } else {
    FilterExternal
  }
}

///|
fn filter_issue(
  document : FilterSemanticDocument,
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
fn filter_default_length(property : String) -> FilterLength {
  match property {
    "x" | "y" => { value: -0.1, percentage: true }
    "width" | "height" => { value: 1.2, percentage: true }
    _ => { value: 0.0, percentage: false }
  }
}

///|
fn filter_length_from_fact(
  fact : DeclaredVisualFact?,
  property : String,
  units : String,
  profile : ComparisonProfile,
) -> (FilterLength, Bool) {
  guard fact is Some(fact) else {
    return (filter_default_length(property), true)
  }
  let source = fact.declared_value.trim().to_owned()
  if source.has_suffix("%") {
    guard parse_shape_number(
        source.view(end_offset=source.length() - 1).to_owned(),
      )
      is Some(value) else {
      return (filter_default_length(property), false)
    }
    return ({ value: value / 100.0, percentage: true }, true)
  }
  if units == "objectBoundingBox" {
    return match parse_shape_number(source) {
      Some(value) => ({ value, percentage: false }, true)
      None => (filter_default_length(property), false)
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
    None => (filter_default_length(property), false)
  }
}

///|
fn filter_resource_from_element(
  input : String,
  element : @xml.NamespaceElement,
  start_offset : Int,
  end_offset : Int,
  hierarchy : FillHierarchy,
  profile : ComparisonProfile,
) -> FilterResource {
  let authored_id = authored_subject_id(element)
  let subject_id = authored_id.unwrap_or(
    clip_hierarchy_subject_id_at(hierarchy, start_offset, "filter"),
  )
  let filter_units_fact = clip_attribute(element, "filterUnits").map(attribute => {
    presentation_fact(input, "filterUnits", attribute)
  })
  let filter_units = filter_units_fact
    .map(fact => fact.declared_value.trim().to_owned())
    .unwrap_or("objectBoundingBox")
  let primitive_units_fact = clip_attribute(element, "primitiveUnits").map(attribute => {
    presentation_fact(input, "primitiveUnits", attribute)
  })
  let primitive_units = primitive_units_fact
    .map(fact => fact.declared_value.trim().to_owned())
    .unwrap_or("userSpaceOnUse")
  let region_facts : Array[DeclaredVisualFact] = []
  let template_fact = match clip_attribute(element, "href") {
    Some(attribute) => Some(presentation_fact(input, "href", attribute))
    None =>
      clip_attribute(element, "xlink:href").map(attribute => {
        presentation_fact(input, "href", attribute)
      })
  }
  let lengths : Array[FilterLength] = []
  let mut complete = (
      filter_units == "userSpaceOnUse" || filter_units == "objectBoundingBox"
    ) &&
    (
      primitive_units == "userSpaceOnUse" ||
      primitive_units == "objectBoundingBox"
    )
  for property in ["x", "y", "width", "height"] {
    let fact = clip_attribute(element, property).map(attribute => {
      presentation_fact(input, property, attribute)
    })
    match fact {
      Some(fact) => region_facts.push(fact)
      None => ()
    }
    let parsed = filter_length_from_fact(fact, property, filter_units, profile)
    lengths.push(parsed.0)
    complete = complete && parsed.1
  }
  {
    subject_id,
    authored_id,
    presence_fact: clip_source_fact(input, "presence", start_offset, end_offset),
    filter_units,
    filter_units_fact,
    primitive_units,
    primitive_units_fact,
    template_fact,
    region_x: lengths[0],
    region_y: lengths[1],
    region_width: lengths[2],
    region_height: lengths[3],
    region_facts,
    primitives: [],
    complete,
  }
}

///|
fn filter_offset_from_element(
  input : String,
  element : @xml.NamespaceElement,
  start_offset : Int,
  end_offset : Int,
  resource : FilterResource,
) -> FilterOffsetPrimitive {
  let index = resource.primitives.length()
  let input_fact = clip_attribute(element, "in").map(attribute => {
    presentation_fact(input, "in", attribute)
  })
  let result_fact = clip_attribute(element, "result").map(attribute => {
    presentation_fact(input, "result", attribute)
  })
  let dx_fact = clip_attribute(element, "dx").map(attribute => {
    presentation_fact(input, "dx", attribute)
  })
  let dy_fact = clip_attribute(element, "dy").map(attribute => {
    presentation_fact(input, "dy", attribute)
  })
  let dx = dx_fact
    .bind(fact => parse_shape_number(fact.declared_value))
    .unwrap_or(0.0)
  let dy = dy_fact
    .bind(fact => parse_shape_number(fact.declared_value))
    .unwrap_or(0.0)
  let input_name = input_fact
    .map(fact => fact.declared_value.trim().to_owned())
    .unwrap_or(if index == 0 { "SourceGraphic" } else { "__previous__" })
  let result = result_fact.map(fact => fact.declared_value.trim().to_owned())
  let mut region_fact : DeclaredVisualFact? = None
  for property in ["x", "y", "width", "height"] {
    match clip_attribute(element, property) {
      Some(attribute) if region_fact is None =>
        region_fact = Some(presentation_fact(input, property, attribute))
      _ => ()
    }
  }
  let result_valid = result.map(filter_result_name_admitted).unwrap_or(true)
  let explicit_internal_input = input_fact
    .map(fact => fact.declared_value.trim() == "__previous__")
    .unwrap_or(false)
  {
    index,
    subject_id: "\{resource.subject_id}:feOffset:\{index}",
    presence_fact: clip_source_fact(input, "presence", start_offset, end_offset),
    input: input_name,
    input_fact,
    result,
    result_fact,
    dx,
    dx_fact,
    dy,
    dy_fact,
    region_fact,
    complete: dx_fact
    .map(fact => parse_shape_number(fact.declared_value) is Some(_))
    .unwrap_or(true) &&
    dy_fact
    .map(fact => parse_shape_number(fact.declared_value) is Some(_))
    .unwrap_or(true) &&
    result_valid &&
    !explicit_internal_input &&
    region_fact is None,
  }
}

///|
fn filter_result_name_admitted(value : String) -> Bool {
  if value == "" ||
    value == "__previous__" ||
    [
      "SourceGraphic", "SourceAlpha", "BackgroundImage", "BackgroundAlpha", "FillPaint",
      "StrokePaint", "initial", "inherit", "unset", "revert", "default",
    ].contains(value) {
    return false
  }
  for index, character in value {
    let code = character.to_int()
    let letter = (code >= 0x41 && code <= 0x5a) ||
      (code >= 0x61 && code <= 0x7a)
    let digit = code >= 0x30 && code <= 0x39
    let invalid = if index == 0 {
      !letter && code != 0x5f
    } else {
      !letter && !digit && code != 0x5f && code != 0x2d
    }
    if invalid {
      return false
    }
  }
  true
}

///|
fn filter_input_available(
  primitives : Array[FilterOffsetPrimitive],
  index : Int,
  input : String,
) -> Bool {
  if input == "SourceGraphic" ||
    input == "SourceAlpha" ||
    input == "__previous__" {
    return input != "__previous__" || index > 0
  }
  for previous in 0..<index {
    if primitives[previous].result == Some(input) {
      return true
    }
  }
  false
}

///|
fn extract_filter_semantic_document_or_raise(
  input : String,
  profile : ComparisonProfile,
) -> FilterSemanticDocument raise {
  let hierarchy = extract_fill_hierarchy_or_raise(input)
  let document : FilterSemanticDocument = {
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
            if depth == 1 {
              if element.name.local_name == "feOffset" {
                let primitive = filter_offset_from_element(
                  input,
                  element,
                  event.span.start.offset,
                  event.span.end.offset,
                  document.resources[index],
                )
                document.resources[index].primitives.push(primitive)
              } else if element.name.local_name != "title" &&
                element.name.local_name != "desc" &&
                element.name.local_name != "metadata" {
                document.resources[index].complete = false
                filter_issue(
                  document,
                  "filter_primitive_unsupported",
                  document.resources[index].subject_id,
                  Some(
                    clip_source_fact(
                      input,
                      "primitive",
                      event.span.start.offset,
                      event.span.end.offset,
                    ),
                  ),
                )
              }
            } else if element.name.local_name == "animate" ||
              element.name.local_name == "set" ||
              element.name.local_name == "animateTransform" {
              document.resources[index].complete = false
              filter_issue(
                document,
                "filter_dynamic_unsupported",
                document.resources[index].subject_id,
                Some(
                  clip_source_fact(
                    input,
                    "animation",
                    event.span.start.offset,
                    event.span.end.offset,
                  ),
                ),
              )
            }
            depth += 1
          }
          None if element.name.local_name == "filter" => {
            document.resources.push(
              filter_resource_from_element(
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
          Some(index) if element.name.local_name == "animate" ||
            element.name.local_name == "set" ||
            element.name.local_name == "animateTransform" => {
            document.resources[index].complete = false
            filter_issue(
              document,
              "filter_dynamic_unsupported",
              document.resources[index].subject_id,
              Some(
                clip_source_fact(
                  input,
                  "animation",
                  event.span.start.offset,
                  event.span.end.offset,
                ),
              ),
            )
          }
          Some(index) if depth == 1 && element.name.local_name == "feOffset" => {
            let primitive = filter_offset_from_element(
              input,
              element,
              event.span.start.offset,
              event.span.end.offset,
              document.resources[index],
            )
            document.resources[index].primitives.push(primitive)
          }
          Some(index) if depth == 1 &&
            element.name.local_name != "title" &&
            element.name.local_name != "desc" &&
            element.name.local_name != "metadata" => {
            document.resources[index].complete = false
            filter_issue(
              document,
              "filter_primitive_unsupported",
              document.resources[index].subject_id,
              Some(
                clip_source_fact(
                  input,
                  "primitive",
                  event.span.start.offset,
                  event.span.end.offset,
                ),
              ),
            )
          }
          _ if element.name.local_name == "filter" =>
            document.resources.push(
              filter_resource_from_element(
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
    match resource.template_fact {
      Some(fact) => {
        resource.complete = false
        filter_issue(
          document,
          "filter_template_unsupported",
          resource.subject_id,
          Some(fact),
        )
      }
      None => ()
    }
    if resource.authored_id is Some(id) &&
      document.resources.filter(value => value.authored_id == Some(id)).length() >
      1 {
      resource.complete = false
      filter_issue(
        document,
        "filter_duplicate_id_unsupported",
        resource.subject_id,
        Some(resource.presence_fact),
      )
    }
    if resource.filter_units != "userSpaceOnUse" &&
      resource.filter_units != "objectBoundingBox" {
      resource.complete = false
      filter_issue(
        document,
        "filter_units_invalid",
        resource.subject_id,
        resource.filter_units_fact,
      )
    }
    if resource.primitive_units != "userSpaceOnUse" &&
      resource.primitive_units != "objectBoundingBox" {
      resource.complete = false
      filter_issue(
        document,
        "filter_primitive_units_invalid",
        resource.subject_id,
        resource.primitive_units_fact,
      )
    }
    for primitive in resource.primitives {
      if !primitive.complete {
        resource.complete = false
        filter_issue(
          document,
          if primitive.region_fact is Some(_) {
            "filter_primitive_region_unsupported"
          } else {
            "filter_primitive_value_unsupported"
          },
          primitive.subject_id,
          match primitive.region_fact {
            Some(fact) => Some(fact)
            None =>
              match primitive.dx_fact {
                Some(fact) if parse_shape_number(fact.declared_value) is None =>
                  Some(fact)
                _ =>
                  match primitive.dy_fact {
                    Some(fact) if parse_shape_number(fact.declared_value)
                      is None => Some(fact)
                    _ =>
                      match primitive.result_fact {
                        Some(fact) => Some(fact)
                        None => primitive.input_fact
                      }
                  }
              }
          },
        )
      }
      if ["BackgroundImage", "BackgroundAlpha", "FillPaint", "StrokePaint"].contains(
          primitive.input,
        ) {
        resource.complete = false
        filter_issue(
          document,
          "filter_input_unsupported",
          primitive.subject_id,
          primitive.input_fact,
        )
      } else if !filter_input_available(
          resource.primitives,
          primitive.index,
          primitive.input,
        ) {
        resource.complete = false
        filter_issue(
          document,
          "filter_input_unresolved",
          primitive.subject_id,
          primitive.input_fact,
        )
      }
    }
  }
  document
}

///|
fn filter_resource_for_id(
  document : FilterSemanticDocument,
  id : String,
) -> FilterResource? {
  for resource in document.resources {
    if resource.authored_id == Some(id) {
      return Some(resource)
    }
  }
  None
}

///|
fn filter_id_kind(document : FilterSemanticDocument, id : String) -> String? {
  for pair in document.id_kinds {
    if pair.0 == id {
      return Some(pair.1)
    }
  }
  None
}

///|
fn max_filter_primitives_per_graph() -> Int {
  256
}

///|
fn max_filter_surface_work_pixels_per_source() -> Int {
  16_777_216
}

///|
fn filter_resolved_length(
  length : FilterLength,
  origin : Double,
  extent : Double,
  viewport_extent : Double,
  units : String,
  coordinate : Bool,
) -> Double {
  if units == "objectBoundingBox" {
    let value = length.value * extent
    if coordinate {
      origin + value
    } else {
      value
    }
  } else if length.percentage {
    let value = length.value * viewport_extent
    if coordinate {
      value
    } else {
      value
    }
  } else {
    length.value
  }
}

///|
fn filter_region_for_bounds(
  resource : FilterResource,
  bounds : CssBounds,
  profile : ComparisonProfile,
) -> CssBounds? {
  let x = filter_resolved_length(
    resource.region_x,
    bounds.x,
    bounds.width,
    profile.viewport_width.to_double(),
    resource.filter_units,
    true,
  )
  let y = filter_resolved_length(
    resource.region_y,
    bounds.y,
    bounds.height,
    profile.viewport_height.to_double(),
    resource.filter_units,
    true,
  )
  let width = filter_resolved_length(
    resource.region_width,
    0.0,
    bounds.width,
    profile.viewport_width.to_double(),
    resource.filter_units,
    false,
  )
  let height = filter_resolved_length(
    resource.region_height,
    0.0,
    bounds.height,
    profile.viewport_height.to_double(),
    resource.filter_units,
    false,
  )
  if width <= 0.0 || height <= 0.0 {
    None
  } else {
    Some({ x, y, width, height })
  }
}

///|
fn filter_translate_bounds(bounds : CssBounds, dx : Int, dy : Int) -> CssBounds {
  {
    x: bounds.x + dx.to_double(),
    y: bounds.y + dy.to_double(),
    width: bounds.width,
    height: bounds.height,
  }
}

///|
fn filter_source_subject(
  subjects : Array[SourceSubject],
  owner_id : String,
) -> SourceSubject? {
  for subject in subjects {
    if source_subject_id(subject) == owner_id {
      return Some(subject)
    }
  }
  None
}

///|
fn resolve_filter_hosts_or_raise(
  input : String,
  profile : ComparisonProfile,
) -> (FilterSemanticDocument, Array[ResolvedFilterHost]) raise {
  let document = extract_filter_semantic_document_or_raise(input, profile)
  let subjects = extract_source_subjects_with_profile_or_raise(input, profile)
  let hosts : Array[ResolvedFilterHost] = []
  let mut filter_surface_work_pixels = 0
  for element in document.hierarchy.elements {
    guard computed_visual_for_subject(
        document.hierarchy,
        element.subject_id,
        "filter",
      )
      is Some(resolution) &&
      resolution.reported.declaration is Some(filter_fact) &&
      resolution.reported.resolved_value != "none" else {
      continue
    }
    let issues : Array[String] = []
    let mut resource_id : String? = None
    let mut resource : FilterResource? = None
    let mut deterministic_no_filter = false
    match parse_filter_reference(resolution.reported.resolved_value) {
      FilterLocal(id) => {
        resource_id = Some(id)
        match filter_id_kind(document, id) {
          Some("filter") => resource = filter_resource_for_id(document, id)
          Some(_) | None => deterministic_no_filter = true
        }
      }
      FilterExternal =>
        push_unique(issues, "filter_external_reference_unsupported")
      FilterInvalid => push_unique(issues, "filter_reference_invalid")
      FilterNone => ()
    }
    let subject = filter_source_subject(subjects, element.subject_id)
    let target_bounds = subject.bind(source_subject_bounds)
    let instance_host = element.kind == "use" ||
      subject
      .map(value => value.reference.instance_context is Some(_))
      .unwrap_or(false)
    if instance_host {
      push_unique(issues, "filter_instance_unsupported")
    } else if subject is None ||
      subject.bind(value => value.reference.authored_id) is None ||
      !visual_subject_kind(element.kind) {
      push_unique(issues, "filter_host_unsupported")
    }
    match subject {
      Some(subject) => {
        if !subject.transform_complete ||
          subject.cumulative_transform.signature() !=
          AffineTransform::identity().signature() {
          push_unique(issues, "filter_transform_unproven")
        }
        for property in ["clip-path", "mask", "opacity"] {
          match
            computed_visual_for_subject(
              document.hierarchy,
              element.subject_id,
              property,
            ) {
            Some(value) if (
                property == "opacity" && value.reported.resolved_value != "1"
              ) ||
              (property != "opacity" && value.reported.resolved_value != "none") =>
              push_unique(issues, "filter_effect_interaction_unsupported")
            _ => ()
          }
        }
      }
      None => ()
    }
    let mut region : CssBounds? = None
    let offsets : Array[(Int, Int)] = []
    let primitive_bounds : Array[CssBounds?] = []
    match (resource, target_bounds) {
      (Some(resource), Some(bounds)) => {
        let surface_pixels = profile.viewport_width * profile.viewport_height
        let primitive_count = resource.primitives.length()
        let remaining_work = max_filter_surface_work_pixels_per_source() -
          filter_surface_work_pixels
        if primitive_count > max_filter_primitives_per_graph() ||
          surface_pixels <= 0 ||
          primitive_count > remaining_work / surface_pixels {
          push_unique(issues, "filter_graph_budget_exceeded")
        } else {
          filter_surface_work_pixels += primitive_count * surface_pixels
        }
        region = filter_region_for_bounds(resource, bounds, profile)
        let named_bounds : Map[String, CssBounds?] = Map([])
        let mut previous : CssBounds? = None
        for primitive in resource.primitives {
          let scale_x = if resource.primitive_units == "objectBoundingBox" {
            bounds.width
          } else {
            1.0
          }
          let scale_y = if resource.primitive_units == "objectBoundingBox" {
            bounds.height
          } else {
            1.0
          }
          let dx = primitive.dx * scale_x
          let dy = primitive.dy * scale_y
          let dx_int = dx.round().to_int()
          let dy_int = dy.round().to_int()
          if dx != dx_int.to_double() || dy != dy_int.to_double() {
            push_unique(issues, "filter_fractional_offset_unproven")
          }
          offsets.push((dx_int, dy_int))
          let input_bounds = match primitive.input {
            "SourceGraphic" | "SourceAlpha" => Some(bounds)
            "__previous__" => previous
            name => named_bounds.get(name).bind(value => value)
          }
          let output_bounds = match (input_bounds, region) {
            (Some(input_bounds), Some(region)) =>
              intersect_bounds(
                filter_translate_bounds(input_bounds, dx_int, dy_int),
                region,
              )
            _ => None
          }
          primitive_bounds.push(output_bounds)
          previous = output_bounds
          match primitive.result {
            Some(name) => named_bounds[name] = output_bounds
            None => ()
          }
        }
      }
      _ => ()
    }
    let resource_complete = resource
      .map(value => value.complete)
      .unwrap_or(deterministic_no_filter)
    for issue in document.issues {
      if issue.subject_id == resource_id.unwrap_or("") ||
        issue.subject_id.has_prefix("\{resource_id.unwrap_or("")}:") {
        push_unique(issues, issue.code)
      }
    }
    hosts.push({
      owner_id: element.subject_id,
      filter_fact,
      resource_id,
      resource,
      target_bounds,
      filter_region: region,
      primitive_offsets: offsets,
      primitive_bounds,
      effect_bounds: primitive_bounds.last().unwrap_or(None),
      complete: resolution.complete && resource_complete && issues.is_empty(),
      issue_codes: issues,
    })
  }
  (document, hosts)
}

///|
fn append_filter_diagnostics(
  input : String,
  profile : ComparisonProfile,
  source_role : String,
  diagnostics : Array[Diagnostic],
) -> Unit raise {
  let (document, hosts) = resolve_filter_hosts_or_raise(input, profile)
  for issue in document.issues {
    merge_diagnostic_into(diagnostics, {
      ..unlocated_diagnostic(
        "diagnostic:\{issue.code}:\{issue.subject_id}",
        issue.code,
        issue.subject_id,
        ["computed_appearance", "rendered_evidence"],
      ),
      source_locations: match issue.fact {
        Some(fact) => [diagnostic_location(source_role, fact.source_span)]
        None => []
      },
    })
  }
  for host in hosts {
    for code in host.issue_codes {
      merge_diagnostic_into(diagnostics, {
        ..unlocated_diagnostic(
          "diagnostic:\{code}:\{host.owner_id}",
          code,
          host.owner_id,
          ["computed_appearance", "rendered_evidence"],
        ),
        source_locations: [
          diagnostic_location(source_role, host.filter_fact.source_span),
        ],
      })
    }
    if host.target_bounds is None {
      merge_diagnostic_into(diagnostics, {
        ..unlocated_diagnostic(
          "diagnostic:filter_effect_bounds_unavailable:\{host.owner_id}",
          "filter_effect_bounds_unavailable",
          host.owner_id,
          ["computed_appearance", "rendered_evidence"],
        ),
        source_locations: [
          diagnostic_location(source_role, host.filter_fact.source_span),
        ],
      })
    }
  }
}

///|
fn filter_host_for_node(
  hosts : Array[ResolvedFilterHost],
  node : @svg.SVGNode,
) -> ResolvedFilterHost? {
  if node.id == "" {
    return None
  }
  for host in hosts {
    if host.owner_id == node.id && host.complete && host.resource is Some(_) {
      return Some(host)
    }
  }
  None
}

///|
fn filter_subtree_active(
  hosts : Array[ResolvedFilterHost],
  node : @svg.SVGNode,
) -> Bool {
  filter_host_for_node(hosts, node) is Some(_) ||
  node.children.any(child => filter_subtree_active(hosts, child))
}

///|
fn filter_clip_image(image : @svg.Image, region : CssBounds?) -> Unit {
  match region {
    Some(region) =>
      group_compositor_clear_outside_bounds(image, {
        min_x: region.x,
        min_y: region.y,
        max_x: region.x + region.width,
        max_y: region.y + region.height,
      })
    None =>
      for index in 0..<image.pixels.length() {
        image.pixels[index] = @svg.Color::transparent()
      }
  }
}

///|
fn filter_source_alpha(image : @svg.Image) -> @svg.Image {
  let output = image.clone()
  for index, pixel in image.pixels {
    output.pixels[index] = @svg.Color::rgba(0, 0, 0, pixel.a)
  }
  output
}

///|
fn filter_offset_image(image : @svg.Image, dx : Int, dy : Int) -> @svg.Image {
  let output = @svg.Image::new(image.width, image.height)
  for y in 0..<image.height {
    for x in 0..<image.width {
      let target_x = x + dx
      let target_y = y + dy
      if target_x >= 0 &&
        target_x < image.width &&
        target_y >= 0 &&
        target_y < image.height {
        output.pixels[target_y * image.width + target_x] = image.pixels[y *
          image.width +
          x]
      }
    }
  }
  output
}

///|
fn filter_input_image(
  name : String,
  source_graphic : @svg.Image,
  source_alpha : @svg.Image,
  previous : @svg.Image?,
  named : Map[String, @svg.Image],
) -> @svg.Image? {
  match name {
    "SourceGraphic" => Some(source_graphic)
    "SourceAlpha" => Some(source_alpha)
    "__previous__" => previous
    name => named.get(name)
  }
}

///|
fn filter_evaluate_host(
  source_graphic : @svg.Image,
  host : ResolvedFilterHost,
) -> @svg.Image {
  guard host.resource is Some(resource) else { return source_graphic.clone() }
  let source_graphic = source_graphic.clone()
  filter_clip_image(source_graphic, host.filter_region)
  let source_alpha = filter_source_alpha(source_graphic)
  let named : Map[String, @svg.Image] = Map([])
  let mut previous : @svg.Image? = None
  for primitive in resource.primitives {
    guard filter_input_image(
        primitive.input,
        source_graphic,
        source_alpha,
        previous,
        named,
      )
      is Some(input) else {
      return @svg.Image::new(source_graphic.width, source_graphic.height)
    }
    let offset = host.primitive_offsets[primitive.index]
    let output = filter_offset_image(input, offset.0, offset.1)
    filter_clip_image(output, host.filter_region)
    previous = Some(output)
    match primitive.result {
      Some(name) => named[name] = output
      None => ()
    }
  }
  previous.unwrap_or(
    @svg.Image::new(source_graphic.width, source_graphic.height),
  )
}

///|
fn filter_render_leaf(
  document : @svg.SVGDocument,
  hosts : Array[ResolvedFilterHost],
  ancestors : Array[@svg.SVGNode],
  leaf : @svg.SVGNode,
  width : Int,
  height : Int,
) -> @svg.Image {
  let source = group_compositor_render_leaf(
    document, ancestors, leaf, width, height,
  )
  match filter_host_for_node(hosts, leaf) {
    Some(host) => filter_evaluate_host(source, host)
    None => source
  }
}

///|
fn filter_render_container(
  document : @svg.SVGDocument,
  hosts : Array[ResolvedFilterHost],
  ancestors : Array[@svg.SVGNode],
  container : @svg.SVGNode,
  width : Int,
  height : Int,
) -> @svg.Image {
  let output = @svg.Image::new(width, height)
  let child_ancestors = ancestors.copy()
  child_ancestors.push(container)
  for child in group_compositor_children(container) {
    let child_image = if !filter_subtree_active(hosts, child) {
      if group_compositor_atomic_container(child) {
        group_compositor_render_masked_container(
          document, child_ancestors, child, width, height,
        )
      } else if group_compositor_container(child) {
        group_compositor_render_container(
          document, child_ancestors, child, width, height,
        )
      } else {
        group_compositor_render_leaf(
          document, child_ancestors, child, width, height,
        )
      }
    } else if group_compositor_container(child) {
      filter_render_container(
        document, hosts, child_ancestors, child, width, height,
      )
    } else {
      filter_render_leaf(document, hosts, child_ancestors, child, width, height)
    }
    group_compositor_over_image(output, child_image)
  }
  group_compositor_apply_opacity(output, container.opacity)
  output
}

///|
fn render_product_source_to_image(
  source : String,
  profile : ComparisonProfile,
) -> @svg.Image? {
  let hosts = try resolve_filter_hosts_or_raise(source, profile) catch {
    _ => return None
  } noraise {
    value => value.1
  }
  guard @svg.parse_svg_document(
      normalize_renderer_input_with_profile(source, profile),
    )
    is Some(document) else {
    return None
  }
  let complete_hosts = hosts.filter(host => host.complete)
  if complete_hosts.is_empty() {
    return Some(
      render_product_document_to_image(
        document,
        profile.viewport_width,
        profile.viewport_height,
      ),
    )
  }
  if group_compositor_container(document.root) {
    Some(
      filter_render_container(
        document,
        complete_hosts,
        [],
        document.root,
        profile.viewport_width,
        profile.viewport_height,
      ),
    )
  } else {
    Some(
      filter_render_leaf(
        document,
        complete_hosts,
        [],
        document.root,
        profile.viewport_width,
        profile.viewport_height,
      ),
    )
  }
}

///|
fn filter_host_attachments(
  document : FilterSemanticDocument,
) -> Array[FilterHostAttachment] {
  let attachments : Array[FilterHostAttachment] = []
  for element in document.hierarchy.elements {
    match
      computed_visual_for_subject(
        document.hierarchy,
        element.subject_id,
        "filter",
      ) {
      Some(resolution) if resolution.reported.declaration is Some(fact) =>
        attachments.push({
          owner_id: element.subject_id,
          fact,
          value: resolution.reported.resolved_value,
        })
      _ => ()
    }
  }
  attachments
}

///|
fn filter_attachment_for_owner(
  attachments : Array[FilterHostAttachment],
  owner_id : String,
) -> FilterHostAttachment? {
  for attachment in attachments {
    if attachment.owner_id == owner_id {
      return Some(attachment)
    }
  }
  None
}

///|
fn filter_attachment_effect_value(
  attachment : FilterHostAttachment?,
  hosts : Array[ResolvedFilterHost],
) -> String {
  guard attachment is Some(attachment) else { return "none" }
  if parse_filter_reference(attachment.value) is FilterNone {
    return "none"
  }
  for host in hosts {
    if host.owner_id == attachment.owner_id && host.complete {
      return match host.resource {
        Some(_) => {
          let id = host.resource_id.unwrap_or("")
          "resource:\{id}"
        }
        None => "none"
      }
    }
  }
  attachment.value
}

///|
fn filter_resource_keys(
  before : FilterSemanticDocument,
  after : FilterSemanticDocument,
) -> Array[String] {
  let keys : Array[String] = []
  for resource in before.resources + after.resources {
    push_unique(keys, resource.authored_id.unwrap_or(resource.subject_id))
  }
  keys.sort()
  keys
}

///|
fn filter_resource_for_key(
  document : FilterSemanticDocument,
  key : String,
) -> FilterResource? {
  for resource in document.resources {
    if resource.authored_id.unwrap_or(resource.subject_id) == key {
      return Some(resource)
    }
  }
  None
}

///|
fn filter_affected_hosts(
  before : Array[ResolvedFilterHost],
  after : Array[ResolvedFilterHost],
  resource_id : String,
) -> Array[String] {
  let ids : Array[String] = []
  for host in before + after {
    if host.resource_id == Some(resource_id) {
      push_unique(ids, host.owner_id)
    }
  }
  ids.sort()
  ids
}

///|
fn filter_region_fact(
  resource : FilterResource,
  property : String,
) -> DeclaredVisualFact? {
  let source_property = match property {
    "region-x" => "x"
    "region-y" => "y"
    "region-width" => "width"
    "region-height" => "height"
    _ => property
  }
  shape_fact(resource.region_facts, source_property)
}

///|
fn filter_length_signature(length : FilterLength, units : String) -> String {
  if length.percentage || units == "objectBoundingBox" {
    "\{length.value * 100.0}%"
  } else {
    length.value.to_string()
  }
}

///|
fn filter_resource_property_fact(
  resource : FilterResource,
  property : String,
) -> DeclaredVisualFact? {
  match property {
    "filterUnits" => resource.filter_units_fact
    "primitiveUnits" => resource.primitive_units_fact
    "region-x" | "region-y" | "region-width" | "region-height" =>
      filter_region_fact(resource, property)
    _ => None
  }
}

///|
fn filter_resource_property_value(
  resource : FilterResource,
  property : String,
) -> String {
  match property {
    "filterUnits" => resource.filter_units
    "primitiveUnits" => resource.primitive_units
    "region-x" =>
      filter_length_signature(resource.region_x, resource.filter_units)
    "region-y" =>
      filter_length_signature(resource.region_y, resource.filter_units)
    "region-width" =>
      filter_length_signature(resource.region_width, resource.filter_units)
    "region-height" =>
      filter_length_signature(resource.region_height, resource.filter_units)
    _ => ""
  }
}

///|
fn filter_resource_property_number(
  resource : FilterResource,
  property : String,
) -> Double? {
  match property {
    "region-x" => Some(resource.region_x.value)
    "region-y" => Some(resource.region_y.value)
    "region-width" => Some(resource.region_width.value)
    "region-height" => Some(resource.region_height.value)
    _ => None
  }
}

///|
fn filter_primitive_fact(
  primitive : FilterOffsetPrimitive,
  property : String,
) -> DeclaredVisualFact? {
  match property {
    "in" => primitive.input_fact
    "result" => primitive.result_fact
    "dx" => primitive.dx_fact
    "dy" => primitive.dy_fact
    _ => None
  }
}

///|
fn filter_primitive_value(
  primitive : FilterOffsetPrimitive,
  property : String,
) -> String {
  match property {
    "in" => primitive.input
    "result" => primitive.result.unwrap_or("")
    "dx" => primitive.dx.to_string()
    "dy" => primitive.dy.to_string()
    _ => ""
  }
}

///|
fn filter_report_diagnostic_ids(
  report : StructuredReport,
  subjects : Array[String],
) -> Array[String] {
  let ids : Array[String] = []
  for diagnostic in report.diagnostics {
    if diagnostic.code.has_prefix("filter_") &&
      subjects.any(subject => {
        diagnostic.subject_id == subject ||
        diagnostic.subject_id.has_prefix("\{subject}:")
      }) {
      push_unique(ids, diagnostic.id)
    }
  }
  ids.sort()
  ids
}

///|
fn filter_rendered_evidence(
  before_svg : String,
  after_svg : String,
  profile : ComparisonProfile,
) -> RenderedEvidence {
  match
    (
      render_product_source_to_image(before_svg, profile),
      render_product_source_to_image(after_svg, profile),
    ) {
    (Some(before), Some(after)) =>
      computed_rendered_evidence(rendered_image_difference(before, after))
    _ => not_computed_rendered_evidence("filter_renderer_unavailable")
  }
}

///|
fn filter_resource_event_complete(
  before_resource : FilterResource?,
  after_resource : FilterResource?,
  before_hosts : Array[ResolvedFilterHost],
  after_hosts : Array[ResolvedFilterHost],
  resource_id : String,
  diagnostic_ids : Array[String],
) -> Bool {
  if !diagnostic_ids.is_empty() ||
    before_resource.map(value => !value.complete).unwrap_or(false) ||
    after_resource.map(value => !value.complete).unwrap_or(false) {
    return false
  }
  for host in before_hosts + after_hosts {
    if host.resource_id == Some(resource_id) && !host.complete {
      return false
    }
  }
  true
}

///|
fn filter_owner_event_complete(
  before_hosts : Array[ResolvedFilterHost],
  after_hosts : Array[ResolvedFilterHost],
  owner_id : String,
  diagnostic_ids : Array[String],
) -> Bool {
  if !diagnostic_ids.is_empty() {
    return false
  }
  for host in before_hosts + after_hosts {
    if host.owner_id == owner_id && !host.complete {
      return false
    }
  }
  true
}

///|
fn append_filter_report_difference(
  changed_facts : Array[ChangedFact],
  differences : Array[AtomicDifference],
  difference_ids : Array[String],
  fact_id : String,
  difference_id : String,
  subject_id : String,
  subject_role : String,
  property : String,
  domain : String,
  before_fact : DeclaredVisualFact?,
  after_fact : DeclaredVisualFact?,
  before_value : String,
  after_value : String,
  affected_subject_ids : Array[String],
  diagnostic_ids : Array[String],
  number_before : Double?,
  number_after : Double?,
) -> Unit {
  let complete = diagnostic_ids.is_empty()
  changed_facts.push({
    id: fact_id,
    subject_id,
    property,
    before: before_fact,
    after: after_fact,
    affected_subject_ids,
  })
  let magnitude = match (number_before, number_after) {
    (Some(before), Some(after)) => {
      let delta = after - before
      {
        ..empty_difference_magnitude(),
        parameter_abs_user_units: Some(delta.abs()),
        parameter_signed_user_units: Some(delta),
        symmetric_relative: Some(symmetric_relative_delta(before, after)),
      }
    }
    _ => empty_difference_magnitude()
  }
  differences.push({
    id: difference_id,
    subject_role,
    subject_alignment_id: None,
    domain,
    source_before: declared_value_or_empty(before_fact),
    source_after: declared_value_or_empty(after_fact),
    source_fact_before: before_fact,
    source_fact_after: after_fact,
    changed_fact_ids: [fact_id],
    evidence_layers: if complete && before_value != after_value {
      ["source_semantics", "computed_appearance"]
    } else {
      ["source_semantics"]
    },
    computed_relation: if complete {
      {
        status: if before_value == after_value {
          "equivalent"
        } else {
          "different"
        },
        reason_code: if before_value == after_value {
          "same_resolved_filter_fact"
        } else {
          "resolved_filter_facts_differ"
        },
        missing_side: match (before_fact, after_fact) {
          (None, Some(_)) => Some("before")
          (Some(_), None) => Some("after")
          _ => None
        },
        diagnostic_ids: [],
      }
    } else {
      {
        status: "indeterminate",
        reason_code: "filter_coverage_partial",
        missing_side: None,
        diagnostic_ids,
      }
    },
    parameter_delta_css_px: None,
    presence_magnitude: None,
    magnitude,
    domain_ordering: empty_domain_ordering(),
  })
  difference_ids.push(difference_id)
}

///|
fn attach_filter_differences(
  report : StructuredReport,
  before_svg : String,
  after_svg : String,
) -> StructuredReport {
  let before = try
    resolve_filter_hosts_or_raise(before_svg, report.profile)
  catch {
    _ => return report
  } noraise {
    value => value
  }
  let after = try
    resolve_filter_hosts_or_raise(after_svg, report.profile)
  catch {
    _ => return report
  } noraise {
    value => value
  }
  if before.0.resources.is_empty() &&
    after.0.resources.is_empty() &&
    filter_host_attachments(before.0).is_empty() &&
    filter_host_attachments(after.0).is_empty() {
    return report
  }
  let changed_facts = report.changed_facts.copy()
  let differences = report.atomic_differences.copy()
  let events = report.events.copy()
  let rendered = filter_rendered_evidence(before_svg, after_svg, report.profile)
  for key in filter_resource_keys(before.0, after.0) {
    let before_resource = filter_resource_for_key(before.0, key)
    let after_resource = filter_resource_for_key(after.0, key)
    let affected = filter_affected_hosts(before.1, after.1, key)
    let event_diagnostics = filter_report_diagnostic_ids(
      report,
      [
        before_resource.map(value => value.subject_id).unwrap_or(key),
        after_resource.map(value => value.subject_id).unwrap_or(key),
        ..affected,
      ],
    )
    let difference_ids : Array[String] = []
    match (before_resource, after_resource) {
      (Some(left), Some(right)) => {
        let diagnostics = filter_report_diagnostic_ids(
          report,
          [left.subject_id, right.subject_id, ..affected],
        )
        for
          property in [
            "filterUnits", "primitiveUnits", "region-x", "region-y", "region-width",
            "region-height",
          ] {
          let left_fact = filter_resource_property_fact(left, property)
          let right_fact = filter_resource_property_fact(right, property)
          if declared_fact_changed(left_fact, right_fact) {
            append_filter_report_difference(
              changed_facts,
              differences,
              difference_ids,
              "fact:filter:\{key}:\{property}",
              "diff:filter:\{key}:\{property}",
              left.subject_id,
              "resource",
              property,
              if property == "filterUnits" || property == "primitiveUnits" {
                "resource.filter.units"
              } else {
                "resource.filter.region"
              },
              left_fact,
              right_fact,
              filter_resource_property_value(left, property),
              filter_resource_property_value(right, property),
              affected,
              diagnostics,
              filter_resource_property_number(left, property),
              filter_resource_property_number(right, property),
            )
          }
        }
        let primitive_count = left.primitives
          .length()
          .max(right.primitives.length())
        for index in 0..<primitive_count {
          match (left.primitives.get(index), right.primitives.get(index)) {
            (Some(left_primitive), Some(right_primitive)) =>
              for property in ["in", "result", "dx", "dy"] {
                let left_fact = filter_primitive_fact(left_primitive, property)
                let right_fact = filter_primitive_fact(
                  right_primitive, property,
                )
                if declared_fact_changed(left_fact, right_fact) {
                  append_filter_report_difference(
                    changed_facts,
                    differences,
                    difference_ids,
                    "fact:filter:\{key}:primitive:\{index}:\{property}",
                    "diff:filter:\{key}:primitive:\{index}:\{property}",
                    left_primitive.subject_id,
                    "resource",
                    property,
                    if property == "dx" || property == "dy" {
                      "resource.filter.primitive.offset"
                    } else {
                      "resource.filter.primitive.graph"
                    },
                    left_fact,
                    right_fact,
                    filter_primitive_value(left_primitive, property),
                    filter_primitive_value(right_primitive, property),
                    affected,
                    diagnostics,
                    if property == "dx" {
                      Some(left_primitive.dx)
                    } else if property == "dy" {
                      Some(left_primitive.dy)
                    } else {
                      None
                    },
                    if property == "dx" {
                      Some(right_primitive.dx)
                    } else if property == "dy" {
                      Some(right_primitive.dy)
                    } else {
                      None
                    },
                  )
                }
              }
            (left_primitive, right_primitive) => {
              let primitive = match (left_primitive, right_primitive) {
                (Some(value), _) | (_, Some(value)) => value
                _ => abort("unreachable empty filter primitive pair")
              }
              append_filter_report_difference(
                changed_facts,
                differences,
                difference_ids,
                "fact:filter:\{key}:primitive:\{index}:presence",
                "diff:filter:\{key}:primitive:\{index}:presence",
                primitive.subject_id,
                "resource",
                "presence",
                "resource.filter.primitive.presence",
                left_primitive.map(value => value.presence_fact),
                right_primitive.map(value => value.presence_fact),
                if left_primitive is Some(_) {
                  "feOffset"
                } else {
                  ""
                },
                if right_primitive is Some(_) {
                  "feOffset"
                } else {
                  ""
                },
                affected,
                diagnostics,
                None,
                None,
              )
            }
          }
        }
      }
      (left, right) => {
        let resource = match (left, right) {
          (Some(value), _) | (_, Some(value)) => value
          _ => abort("unreachable empty filter resource pair")
        }
        append_filter_report_difference(
          changed_facts,
          differences,
          difference_ids,
          "fact:filter:\{key}:presence",
          "diff:filter:\{key}:presence",
          resource.subject_id,
          "resource",
          "presence",
          "resource.filter.presence",
          left.map(value => value.presence_fact),
          right.map(value => value.presence_fact),
          if left is Some(_) {
            "filter"
          } else {
            ""
          },
          if right is Some(_) {
            "filter"
          } else {
            ""
          },
          affected,
          filter_report_diagnostic_ids(
            report,
            [resource.subject_id, ..affected],
          ),
          None,
          None,
        )
      }
    }
    if !difference_ids.is_empty() {
      events.push({
        id: "event:filter:\{key}",
        primary_subject_id: key,
        atomic_difference_ids: difference_ids,
        rendered_outcome: if filter_resource_event_complete(
            before_resource,
            after_resource,
            before.1,
            after.1,
            key,
            event_diagnostics,
          ) {
          rendered
        } else {
          not_computed_rendered_evidence(
            "filter_resource_rendered_evidence_unavailable",
          )
        },
        difference_regions: [],
      })
    }
  }
  let before_attachments = filter_host_attachments(before.0)
  let after_attachments = filter_host_attachments(after.0)
  let owner_ids : Array[String] = []
  for attachment in before_attachments + after_attachments {
    push_unique(owner_ids, attachment.owner_id)
  }
  owner_ids.sort()
  for owner_id in owner_ids {
    let left = filter_attachment_for_owner(before_attachments, owner_id)
    let right = filter_attachment_for_owner(after_attachments, owner_id)
    let left_fact = left.map(value => value.fact)
    let right_fact = right.map(value => value.fact)
    if !declared_fact_changed(left_fact, right_fact) {
      continue
    }
    let difference_ids : Array[String] = []
    let owner_diagnostics = filter_report_diagnostic_ids(report, [owner_id])
    append_filter_report_difference(
      changed_facts,
      differences,
      difference_ids,
      "fact:filter-host:\{owner_id}:filter",
      "diff:filter-host:\{owner_id}:filter",
      owner_id,
      "entity",
      "filter",
      "filtering.attachment",
      left_fact,
      right_fact,
      filter_attachment_effect_value(left, before.1),
      filter_attachment_effect_value(right, after.1),
      [owner_id],
      owner_diagnostics,
      None,
      None,
    )
    events.push({
      id: "event:filter-host:\{owner_id}",
      primary_subject_id: owner_id,
      atomic_difference_ids: difference_ids,
      rendered_outcome: if filter_owner_event_complete(
          before.1,
          after.1,
          owner_id,
          owner_diagnostics,
        ) {
        rendered
      } else {
        not_computed_rendered_evidence(
          "filter_host_rendered_evidence_unavailable",
        )
      },
      difference_regions: [],
    })
  }
  { ..report, changed_facts, atomic_differences: differences, events }
}
