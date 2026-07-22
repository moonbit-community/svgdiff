///|
pub(all) struct FilterLength {
  value : Double
  percentage : Bool
}

///|
pub(all) struct FilterOffsetPrimitive {
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
pub(all) struct FilterPrimitiveSource {
  position : Int
  kind : String
  subject_id : String
  start_offset : Int
  end_offset : Int
  offset_index : Int?
}

///|
priv struct PendingFilterPrimitiveSource {
  resource_index : Int
  position : Int
  kind : String
  subject_id : String
  start_offset : Int
  offset_index : Int?
}

///|
pub(all) struct FilterResource {
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
  primitive_sources : Array[FilterPrimitiveSource]
  mut complete : Bool
}

///|
pub(all) struct FilterSemanticIssue {
  code : String
  subject_id : String
  fact : DeclaredVisualFact?
}

///|
pub(all) struct FilterSemanticDocument {
  hierarchy : FillHierarchy
  resources : Array[FilterResource]
  id_kinds : Array[(String, String)]
  issues : Array[FilterSemanticIssue]
}

///|
pub(all) struct ResolvedFilterHost {
  owner_id : String
  owner_authored_id : String?
  owner_render_index : Int?
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
pub(all) struct FilterHostAttachment {
  owner_id : String
  fact : DeclaredVisualFact
  value : String
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
    primitive_sources: [],
    complete,
  }
}

///|
fn filter_pending_primitive_source(
  resource_index : Int,
  resource : FilterResource,
  kind : String,
  start_offset : Int,
  offset_index : Int?,
) -> PendingFilterPrimitiveSource {
  let position = resource.primitive_sources.length()
  {
    resource_index,
    position,
    kind,
    subject_id: "\{resource.subject_id}:primitive:\{position}",
    start_offset,
    offset_index,
  }
}

///|
fn filter_finish_primitive_source(
  resource : FilterResource,
  pending : PendingFilterPrimitiveSource,
  end_offset : Int,
) -> FilterPrimitiveSource {
  let source = {
    position: pending.position,
    kind: pending.kind,
    subject_id: pending.subject_id,
    start_offset: pending.start_offset,
    end_offset,
    offset_index: pending.offset_index,
  }
  resource.primitive_sources.push(source)
  source
}

///|
fn filter_metadata_child(kind : String) -> Bool {
  kind == "title" || kind == "desc" || kind == "metadata"
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
pub fn extract_filter_semantic_document_or_raise(
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
  let mut pending_primitive : PendingFilterPrimitiveSource? = None
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
                pending_primitive = Some(
                  filter_pending_primitive_source(
                    index,
                    document.resources[index],
                    element.name.local_name,
                    event.span.start.offset,
                    Some(primitive.index),
                  ),
                )
              } else if !filter_metadata_child(element.name.local_name) {
                document.resources[index].complete = false
                pending_primitive = Some(
                  filter_pending_primitive_source(
                    index,
                    document.resources[index],
                    element.name.local_name,
                    event.span.start.offset,
                    None,
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
            let pending = filter_pending_primitive_source(
              index,
              document.resources[index],
              element.name.local_name,
              event.span.start.offset,
              Some(primitive.index),
            )
            let _ = filter_finish_primitive_source(
              document.resources[index],
              pending,
              event.span.end.offset,
            )
          }
          Some(index) if depth == 1 &&
            !filter_metadata_child(element.name.local_name) => {
            document.resources[index].complete = false
            let pending = filter_pending_primitive_source(
              index,
              document.resources[index],
              element.name.local_name,
              event.span.start.offset,
              None,
            )
            let source = filter_finish_primitive_source(
              document.resources[index],
              pending,
              event.span.end.offset,
            )
            filter_issue(
              document,
              "filter_primitive_unsupported",
              source.subject_id,
              Some(
                clip_source_fact(
                  input,
                  "primitive-source",
                  source.start_offset,
                  source.end_offset,
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
          Some(index) => {
            if depth == 2 {
              match pending_primitive {
                Some(pending) if pending.resource_index == index => {
                  let source = filter_finish_primitive_source(
                    document.resources[index],
                    pending,
                    event.span.end.offset,
                  )
                  if source.offset_index is None {
                    filter_issue(
                      document,
                      "filter_primitive_unsupported",
                      source.subject_id,
                      Some(
                        clip_source_fact(
                          input,
                          "primitive-source",
                          source.start_offset,
                          source.end_offset,
                        ),
                      ),
                    )
                  }
                  pending_primitive = None
                }
                _ => ()
              }
            }
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
  source_offset : Int,
) -> SourceSubject? {
  for subject in subjects {
    if subject.source_offset == source_offset &&
      subject.reference.instance_context is None {
      return Some(subject)
    }
  }
  None
}

///|
pub fn resolve_filter_hosts_or_raise(
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
    let subject = filter_source_subject(subjects, element.source_offset)
    let target_bounds = subject.bind(source_subject_bounds)
    let instance_host = element.kind == "use" ||
      subject
      .map(value => value.reference.instance_context is Some(_))
      .unwrap_or(false)
    if instance_host {
      push_unique(issues, "filter_instance_unsupported")
    } else if subject is None || !visual_subject_kind(element.kind) {
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
      owner_authored_id: subject.bind(value => value.reference.authored_id),
      owner_render_index: subject.map(value => value.reference.source_index),
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
pub fn append_filter_diagnostics(
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
