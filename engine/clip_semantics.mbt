///|
priv enum ClipPathReference {
  ClipNone
  ClipLocal(String)
  ClipExternal
  ClipInvalid
}

///|
priv struct ClipSemanticIssue {
  code : String
  subject_id : String
  fact : DeclaredVisualFact?
}

///|
priv struct ClipRectResource {
  subject_id : String
  authored_id : String?
  presence_fact : DeclaredVisualFact
  units : String
  units_fact : DeclaredVisualFact?
  transform_fact : DeclaredVisualFact?
  transform : AffineTransform
  transform_complete : Bool
  mut child_count : Int
  mut rect_source_offset : Int?
  mut rect_facts : Array[DeclaredVisualFact]
  mut rect_transform_fact : DeclaredVisualFact?
  mut rect_transform : AffineTransform
  mut rect_bounds : CssBounds?
  mut complete : Bool
}

///|
priv struct ClipSemanticDocument {
  hierarchy : FillHierarchy
  resources : Array[ClipRectResource]
  id_kinds : Array[(String, String)]
  issues : Array[ClipSemanticIssue]
}

///|
fn parse_clip_path_reference(source : String) -> ClipPathReference {
  let value = source.trim().to_owned()
  if value.to_lower() == "none" {
    return ClipNone
  }
  if value.length() < 6 ||
    !value.to_lower().has_prefix("url(") ||
    !value.has_suffix(")") {
    return ClipInvalid
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
      return ClipLocal(id)
    }
    return ClipInvalid
  }
  if locator == "" {
    ClipInvalid
  } else {
    ClipExternal
  }
}

///|
fn canonical_clip_path_reference(source : String) -> String? {
  match parse_clip_path_reference(source) {
    ClipNone => Some("none")
    ClipLocal(id) => Some("url(#\{id})")
    _ => None
  }
}

///|
fn clip_attribute(
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
fn clip_source_fact(
  input : String,
  property : String,
  start_offset : Int,
  end_offset : Int,
) -> DeclaredVisualFact {
  let source = source_range_slice(input, start_offset, end_offset)
  {
    property,
    authored_value: source,
    declared_value: source,
    origin: "resource_content",
    source_span: { start_offset, end_offset },
  }
}

///|
fn clip_issue(
  document : ClipSemanticDocument,
  code : String,
  subject_id : String,
  fact : DeclaredVisualFact?,
) -> Unit {
  if !document.issues.any(issue => {
      issue.code == code &&
      issue.subject_id == subject_id &&
      issue.fact.map(fact => {
        (fact.source_span.start_offset, fact.source_span.end_offset)
      }) ==
      fact.map(fact => {
        (fact.source_span.start_offset, fact.source_span.end_offset)
      })
    }) {
    document.issues.push({ code, subject_id, fact })
  }
}

///|
fn clip_transform_from_fact(
  fact : DeclaredVisualFact?,
) -> (AffineTransform, Bool) {
  match fact {
    None => (AffineTransform::identity(), true)
    Some(fact) =>
      match parse_transform_list(fact.declared_value) {
        ValidTransformList(value) =>
          (value.matrix, value.matrix.has_proven_renderer_conformance())
        InvalidTransformList => (AffineTransform::identity(), false)
      }
  }
}

///|
fn clip_hierarchy_subject_id_at(
  hierarchy : FillHierarchy,
  source_offset : Int,
  fallback_kind : String,
) -> String {
  for element in hierarchy.elements {
    if element.source_offset == source_offset {
      return element.subject_id
    }
  }
  generated_subject_id(fallback_kind, source_offset)
}

///|
fn clip_resource_from_element(
  input : String,
  element : @xml.NamespaceElement,
  source_offset : Int,
  source_end_offset : Int,
  hierarchy : FillHierarchy,
) -> ClipRectResource {
  let authored_id = authored_subject_id(element)
  let subject_id = authored_id.unwrap_or(
    clip_hierarchy_subject_id_at(hierarchy, source_offset, "clipPath"),
  )
  let units_fact = clip_attribute(element, "clipPathUnits").map(attribute => {
    presentation_fact(input, "clipPathUnits", attribute)
  })
  let units = units_fact
    .map(fact => fact.declared_value.trim().to_owned())
    .unwrap_or("userSpaceOnUse")
  let transform_fact = clip_attribute(element, "transform").map(attribute => {
    presentation_fact(input, "transform", attribute)
  })
  let parsed_transform = clip_transform_from_fact(transform_fact)
  {
    subject_id,
    authored_id,
    presence_fact: clip_source_fact(
      input, "presence", source_offset, source_end_offset,
    ),
    units,
    units_fact,
    transform_fact,
    transform: parsed_transform.0,
    transform_complete: parsed_transform.1,
    child_count: 0,
    rect_source_offset: None,
    rect_facts: [],
    rect_transform_fact: None,
    rect_transform: AffineTransform::identity(),
    rect_bounds: None,
    complete: (units == "userSpaceOnUse" || units == "objectBoundingBox") &&
    parsed_transform.1 &&
    fill_source_element(hierarchy, subject_id) is Some(_),
  }
}

///|
fn clip_bbox_number(source : String) -> Double? {
  let value = source.trim().to_owned()
  if value.has_suffix("%") {
    None
  } else {
    parse_shape_number(value)
  }
}

///|
fn clip_resolved_number(
  hierarchy : FillHierarchy,
  subject_id : String,
  property : String,
  units : String,
  profile : ComparisonProfile,
) -> (Double, Bool) {
  let default = if property == "x" || property == "y" { 0.0 } else { 0.0 }
  guard computed_visual_for_subject(hierarchy, subject_id, property)
    is Some(resolution) &&
    resolution.complete else {
    return (default, false)
  }
  let source = resolution.reported.resolved_value
  let value = if source == "auto" {
    Some(0.0)
  } else if units == "objectBoundingBox" {
    clip_bbox_number(source)
  } else {
    parse_svg_length(
      source,
      basic_shape_length_direction(property),
      {
        width: profile.viewport_width.to_double(),
        height: profile.viewport_height.to_double(),
      },
      profile,
    )
  }
  match value {
    Some(number) if (property != "width" && property != "height") ||
      number >= 0.0 => (number, true)
    _ => (default, false)
  }
}

///|
fn clip_record_direct_child(
  input : String,
  element : @xml.NamespaceElement,
  source_offset : Int,
  source_end_offset : Int,
  profile : ComparisonProfile,
  document : ClipSemanticDocument,
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
    clip_issue(
      document,
      "clip_path_content_unsupported",
      resource.subject_id,
      Some(clip_source_fact(input, "content", source_offset, source_end_offset)),
    )
    return
  }
  let rect_subject_id = authored_subject_id(element).unwrap_or(
    clip_hierarchy_subject_id_at(document.hierarchy, source_offset, "rect"),
  )
  resource.rect_source_offset = Some(source_offset)
  let facts = computed_visual_facts_for_subject(
    document.hierarchy,
    rect_subject_id,
  )
  resource.rect_facts = facts
  let transform_fact = clip_attribute(element, "transform").map(attribute => {
    presentation_fact(input, "transform", attribute)
  })
  let parsed_transform = clip_transform_from_fact(transform_fact)
  resource.rect_transform_fact = transform_fact
  resource.rect_transform = parsed_transform.0
  let x = clip_resolved_number(
    document.hierarchy,
    rect_subject_id,
    "x",
    resource.units,
    profile,
  )
  let y = clip_resolved_number(
    document.hierarchy,
    rect_subject_id,
    "y",
    resource.units,
    profile,
  )
  let width = clip_resolved_number(
    document.hierarchy,
    rect_subject_id,
    "width",
    resource.units,
    profile,
  )
  let height = clip_resolved_number(
    document.hierarchy,
    rect_subject_id,
    "height",
    resource.units,
    profile,
  )
  let rx = clip_resolved_number(
    document.hierarchy,
    rect_subject_id,
    "rx",
    resource.units,
    profile,
  )
  let ry = clip_resolved_number(
    document.hierarchy,
    rect_subject_id,
    "ry",
    resource.units,
    profile,
  )
  let geometry_complete = x.1 &&
    y.1 &&
    width.1 &&
    height.1 &&
    rx.1 &&
    ry.1 &&
    rx.0 == 0.0 &&
    ry.0 == 0.0
  resource.rect_bounds = Some({
    x: x.0,
    y: y.0,
    width: width.0,
    height: height.0,
  })
  if !geometry_complete || !parsed_transform.1 {
    resource.complete = false
    clip_issue(
      document,
      if !parsed_transform.1 {
        "clip_path_transform_unproven"
      } else {
        "clip_path_geometry_unsupported"
      },
      resource.subject_id,
      if !parsed_transform.1 {
        transform_fact
      } else {
        None
      },
    )
  }
}

///|
fn extract_clip_semantic_document_or_raise(
  input : String,
  profile : ComparisonProfile,
) -> ClipSemanticDocument raise {
  let hierarchy = extract_fill_hierarchy_or_raise(input)
  let document : ClipSemanticDocument = {
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
            if element.name.local_name == "animate" ||
              element.name.local_name == "animateTransform" ||
              element.name.local_name == "animateMotion" ||
              element.name.local_name == "set" {
              document.resources[index].complete = false
              clip_issue(
                document,
                "clip_path_dynamic_unsupported",
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
              clip_record_direct_child(
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
          None if element.name.local_name == "clipPath" => {
            let resource = clip_resource_from_element(
              input,
              element,
              event.span.start.offset,
              event.span.end.offset,
              hierarchy,
            )
            if clip_attribute(element, "href") is Some(_) {
              resource.complete = false
              clip_issue(
                document,
                "clip_path_nested_reference_unsupported",
                resource.subject_id,
                Some(resource.presence_fact),
              )
            }
            document.resources.push(resource)
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
          Some(index) => {
            if element.name.local_name == "animate" ||
              element.name.local_name == "animateTransform" ||
              element.name.local_name == "animateMotion" ||
              element.name.local_name == "set" {
              document.resources[index].complete = false
              clip_issue(
                document,
                "clip_path_dynamic_unsupported",
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
              clip_record_direct_child(
                input,
                element,
                event.span.start.offset,
                event.span.end.offset,
                profile,
                document,
                index,
              )
            }
          }
          _ if element.name.local_name == "clipPath" => {
            let resource = clip_resource_from_element(
              input,
              element,
              event.span.start.offset,
              event.span.end.offset,
              hierarchy,
            )
            resource.complete = false
            if clip_attribute(element, "href") is Some(_) {
              clip_issue(
                document,
                "clip_path_nested_reference_unsupported",
                resource.subject_id,
                Some(resource.presence_fact),
              )
            }
            document.resources.push(resource)
            clip_issue(
              document,
              "clip_path_content_unsupported",
              resource.subject_id,
              Some(resource.presence_fact),
            )
          }
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
    if resource.child_count != 1 || resource.rect_bounds is None {
      resource.complete = false
      clip_issue(
        document,
        "clip_path_content_unsupported",
        resource.subject_id,
        Some(resource.presence_fact),
      )
    }
    if resource.units != "userSpaceOnUse" &&
      resource.units != "objectBoundingBox" {
      clip_issue(
        document,
        "clip_path_units_invalid",
        resource.subject_id,
        resource.units_fact,
      )
    }
    if !resource.transform_complete {
      clip_issue(
        document,
        "clip_path_transform_unproven",
        resource.subject_id,
        resource.transform_fact,
      )
    }
  }
  document
}

///|
fn source_has_clip_resources(
  input : String,
  profile : ComparisonProfile,
) -> Bool {
  let document = extract_clip_semantic_document_or_raise(input, profile) catch {
    _ => return false
  }
  !document.resources.is_empty()
}

///|
fn clip_resource_for_id(
  document : ClipSemanticDocument,
  id : String,
) -> ClipRectResource? {
  for resource in document.resources {
    if resource.authored_id == Some(id) {
      return Some(resource)
    }
  }
  None
}

///|
fn clip_target_kind(document : ClipSemanticDocument, id : String) -> String? {
  for entry in document.id_kinds {
    if entry.0 == id {
      return Some(entry.1)
    }
  }
  None
}

///|
fn clip_active_resolution_for_subject(
  hierarchy : FillHierarchy,
  subject : SourceSubject,
) -> (String, String, ResolvedVisualFact, Int)? {
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
    match
      computed_visual_for_subject(hierarchy, element.subject_id, "clip-path") {
      Some(resolution) if resolution.reported.declaration is Some(_) &&
        resolution.reported.resolved_value != "none" =>
        return Some(
          (
            element.subject_id,
            resolution.reported.resolved_value,
            resolution.reported,
            owner_depth,
          ),
        )
      _ => ()
    }
    current = element.parent_index
    owner_depth += 1
  }
  None
}

///|
fn clip_owner_transform(
  subject : SourceSubject,
  owner_depth : Int,
) -> (AffineTransform, Bool) {
  if owner_depth >= subject.transform_chain.length() {
    return (subject.cumulative_transform, false)
  }
  let owner_index = subject.transform_chain.length() - owner_depth - 1
  let mut matrix = AffineTransform::identity()
  let mut complete = true
  for index, site in subject.transform_chain {
    matrix = matrix.multiply(site.matrix).multiply(site.viewport_matrix)
    complete = complete && site.complete && site.viewport_complete
    if index == owner_index {
      return (matrix, complete)
    }
  }
  (subject.cumulative_transform, subject.transform_complete)
}

///|
fn clip_application_bounds(
  subject : SourceSubject,
  owner_depth : Int,
  resource : ClipRectResource,
) -> (CssBounds?, Bool) {
  guard resource.rect_bounds is Some(rect) else { return (None, false) }
  let owner_transform = clip_owner_transform(subject, owner_depth)
  if !owner_transform.1 {
    return (None, false)
  }
  let matrix = if resource.units == "objectBoundingBox" {
    if owner_depth != 0 {
      return (None, false)
    }
    guard source_subject_geometry_bounds(subject) is Some(host) else {
      return (None, false)
    }
    owner_transform.0
    .multiply(AffineTransform::translate(host.x, host.y))
    .multiply(AffineTransform::scale(host.width, host.height))
    .multiply(resource.transform)
    .multiply(resource.rect_transform)
  } else {
    owner_transform.0
    .multiply(resource.transform)
    .multiply(resource.rect_transform)
  }
  let clip_bounds = transform_bounds(rect, matrix)
  guard source_subject_unclipped_bounds(subject) is Some(host) else {
    return (None, false)
  }
  (intersect_bounds(host, clip_bounds), true)
}

///|
fn resolve_clip_subjects_or_raise(
  input : String,
  subjects : Array[SourceSubject],
  profile : ComparisonProfile,
) -> Array[SourceSubject] raise {
  let document = extract_clip_semantic_document_or_raise(input, profile)
  let resolved : Array[SourceSubject] = []
  for subject in subjects {
    match subject.clip_path_owner_id {
      Some(owner) =>
        match clip_resource_for_id(document, owner) {
          Some(resource) => {
            let codes : Array[String] = []
            for issue in document.issues {
              if issue.subject_id == resource.subject_id {
                push_unique(codes, issue.code)
              }
            }
            resolved.push({
              ..subject,
              clip_resource_id: Some(owner),
              clip_complete: resource.complete,
              clip_issue_codes: codes,
            })
            continue
          }
          None => ()
        }
      None => ()
    }
    match clip_active_resolution_for_subject(document.hierarchy, subject) {
      None => resolved.push(subject)
      Some((_, source, resolution, owner_depth)) => {
        let codes : Array[String] = []
        let mut resource_id : String? = None
        let mut effect_bounds : CssBounds? = None
        let mut complete = resolution.declaration is Some(_)
        match parse_clip_path_reference(source) {
          ClipLocal(id) => {
            resource_id = Some(id)
            match clip_resource_for_id(document, id) {
              Some(resource) => {
                complete = complete && resource.complete
                let application = clip_application_bounds(
                  subject, owner_depth, resource,
                )
                effect_bounds = application.0
                if resource.units == "objectBoundingBox" && owner_depth != 0 {
                  complete = false
                  push_unique(
                    codes, "clip_path_object_bbox_container_unsupported",
                  )
                } else if resource.complete && !application.1 {
                  complete = false
                  push_unique(codes, "clip_path_effect_bounds_unavailable")
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
                complete = false
                push_unique(
                  codes,
                  match clip_target_kind(document, id) {
                    Some(_) => "clip_path_target_kind_unsupported"
                    None => "clip_path_target_missing"
                  },
                )
              }
            }
          }
          ClipExternal => {
            complete = false
            push_unique(codes, "clip_path_external_reference_unsupported")
          }
          ClipInvalid => {
            complete = false
            push_unique(codes, "clip_path_reference_invalid")
          }
          ClipNone => ()
        }
        if subject.reference.instance_context is Some(_) {
          complete = false
          effect_bounds = None
          push_unique(codes, "clip_path_instance_unsupported")
        }
        resolved.push({
          ..subject,
          clip_resource_id: resource_id,
          clip_complete: complete,
          clip_effect_bounds: effect_bounds,
          clip_issue_codes: codes,
        })
      }
    }
  }
  resolved
}

///|
fn append_clip_path_diagnostics(
  input : String,
  profile : ComparisonProfile,
  source_role : String,
  diagnostics : Array[Diagnostic],
) -> Unit raise {
  let document = extract_clip_semantic_document_or_raise(input, profile)
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
  for element in document.hierarchy.elements {
    if element.kind != "use" {
      continue
    }
    match
      computed_visual_for_subject(
        document.hierarchy,
        element.subject_id,
        "clip-path",
      ) {
      Some(resolution) if resolution.reported.resolved_value != "none" =>
        merge_diagnostic_into(diagnostics, {
          id: "diagnostic:clip_path_instance_unsupported:\{element.subject_id}",
          code: "clip_path_instance_unsupported",
          subject_id: element.subject_id,
          affected_evidence_layers: ["computed_appearance", "rendered_evidence"],
          source_locations: resolution.reported.declaration
          .map(fact => [diagnostic_location(source_role, fact.source_span)])
          .unwrap_or([]),
        })
      _ => ()
    }
  }
  let subjects = resolve_clip_subjects_or_raise(
    input,
    extract_source_subjects_without_clip_or_raise(input, profile),
    profile,
  )
  for subject in subjects {
    let fact = clip_active_resolution_for_subject(document.hierarchy, subject).bind(entry => {
        entry.2.declaration
      },
    )
    for code in subject.clip_issue_codes {
      merge_diagnostic_into(diagnostics, {
        id: "diagnostic:\{code}:\{source_subject_id(subject)}",
        code,
        subject_id: source_subject_id(subject),
        affected_evidence_layers: ["computed_appearance", "rendered_evidence"],
        source_locations: fact
        .map(fact => [diagnostic_location(source_role, fact.source_span)])
        .unwrap_or([]),
      })
    }
  }
}

///|
fn clip_resource_pair_keys(
  before : ClipSemanticDocument,
  after : ClipSemanticDocument,
) -> Array[String] {
  let keys : Array[String] = []
  for resource in before.resources + after.resources {
    push_unique(keys, resource.authored_id.unwrap_or(resource.subject_id))
  }
  keys.sort()
  keys
}

///|
fn clip_resource_for_key(
  document : ClipSemanticDocument,
  key : String,
) -> ClipRectResource? {
  for resource in document.resources {
    if resource.authored_id.unwrap_or(resource.subject_id) == key {
      return Some(resource)
    }
  }
  None
}

///|
fn clip_resource_fact(
  resource : ClipRectResource,
  property : String,
) -> DeclaredVisualFact? {
  match property {
    "clipPathUnits" => resource.units_fact
    "transform" => resource.transform_fact
    "child-transform" => resource.rect_transform_fact
    _ => shape_fact(resource.rect_facts, property)
  }
}

///|
fn clip_resource_computed(
  resource : ClipRectResource,
  property : String,
) -> String {
  match property {
    "clipPathUnits" => resource.units
    "transform" => resource.transform.signature()
    "child-transform" => resource.rect_transform.signature()
    "clip-rule" => "simple-rect"
    "x" =>
      resource.rect_bounds.map(bounds => bounds.x.to_string()).unwrap_or("")
    "y" =>
      resource.rect_bounds.map(bounds => bounds.y.to_string()).unwrap_or("")
    "width" =>
      resource.rect_bounds.map(bounds => bounds.width.to_string()).unwrap_or("")
    "height" =>
      resource.rect_bounds
      .map(bounds => bounds.height.to_string())
      .unwrap_or("")
    "rx" | "ry" => "0"
    _ => ""
  }
}

///|
fn clip_resource_number(
  resource : ClipRectResource,
  property : String,
) -> Double? {
  guard resource.rect_bounds is Some(bounds) else { return None }
  match property {
    "x" => Some(bounds.x)
    "y" => Some(bounds.y)
    "width" => Some(bounds.width)
    "height" => Some(bounds.height)
    "rx" | "ry" => Some(0.0)
    _ => None
  }
}

///|
fn clip_resource_magnitude(
  before : ClipRectResource,
  after : ClipRectResource,
  property : String,
) -> DifferenceMagnitude {
  match
    (
      clip_resource_number(before, property),
      clip_resource_number(after, property),
    ) {
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
}

///|
fn clip_resource_affected_subjects(
  before : Array[SourceSubject],
  after : Array[SourceSubject],
  key : String,
) -> Array[String] {
  let ids : Array[String] = []
  for subject in before + after {
    if subject.clip_resource_id == Some(key) {
      push_unique(ids, source_subject_id(subject))
    }
  }
  ids.sort()
  ids
}

///|
fn clip_rendered_evidence(
  before_svg : String,
  after_svg : String,
  profile : ComparisonProfile,
) -> RenderedEvidence {
  match
    (
      @svg.parse_svg_document(
        normalize_renderer_input_with_profile(before_svg, profile),
      ),
      @svg.parse_svg_document(
        normalize_renderer_input_with_profile(after_svg, profile),
      ),
    ) {
    (Some(before), Some(after)) =>
      computed_rendered_evidence(rendered_difference(before, after, profile))
    _ => not_computed_rendered_evidence("clip_path_renderer_unavailable")
  }
}

///|
fn clip_resource_diagnostic_ids(
  report : StructuredReport,
  subject_ids : Array[String],
) -> Array[String] {
  let ids : Array[String] = []
  for diagnostic in report.diagnostics {
    if subject_ids.contains(diagnostic.subject_id) &&
      diagnostic.code.has_prefix("clip_path_") {
      push_unique(ids, diagnostic.id)
    }
  }
  ids.sort()
  ids
}

///|
fn attach_clip_path_differences(
  report : StructuredReport,
  before_svg : String,
  after_svg : String,
) -> StructuredReport {
  let before_document = extract_clip_semantic_document_or_raise(
    before_svg,
    report.profile,
  ) catch {
    _ => return report
  }
  let after_document = extract_clip_semantic_document_or_raise(
    after_svg,
    report.profile,
  ) catch {
    _ => return report
  }
  if before_document.resources.is_empty() && after_document.resources.is_empty() {
    return report
  }
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
  let changed_facts = report.changed_facts.copy()
  let differences = report.atomic_differences.copy()
  let events = report.events.copy()
  let rendered = clip_rendered_evidence(before_svg, after_svg, report.profile)
  for key in clip_resource_pair_keys(before_document, after_document) {
    match
      (
        clip_resource_for_key(before_document, key),
        clip_resource_for_key(after_document, key),
      ) {
      (Some(before), Some(after)) => {
        let difference_ids : Array[String] = []
        let affected_subject_ids = clip_resource_affected_subjects(
          before_subjects, after_subjects, key,
        )
        for
          property in [
            "clipPathUnits", "transform", "x", "y", "width", "height", "rx", "ry",
            "child-transform", "clip-rule",
          ] {
          let before_fact = clip_resource_fact(before, property)
          let after_fact = clip_resource_fact(after, property)
          if !declared_fact_changed(before_fact, after_fact) {
            continue
          }
          let fact_id = "fact:clip:\{key}:\{property}"
          let difference_id = "diff:clip:\{key}:\{property}"
          let computed_before = clip_resource_computed(before, property)
          let computed_after = clip_resource_computed(after, property)
          let diagnostic_ids = clip_resource_diagnostic_ids(report, [
            before.subject_id,
            after.subject_id,
          ])
          let complete = before.complete &&
            after.complete &&
            diagnostic_ids.is_empty()
          changed_facts.push({
            id: fact_id,
            subject_id: before.subject_id,
            property,
            before: before_fact,
            after: after_fact,
            affected_subject_ids,
          })
          differences.push({
            id: difference_id,
            subject_role: "resource",
            subject_alignment_id: None,
            domain: match property {
              "clipPathUnits" => "resource.clip.units"
              "transform" | "child-transform" => "resource.clip.transform"
              "clip-rule" => "resource.clip.rule"
              _ => "resource.clip.geometry"
            },
            source_before: declared_value_or_empty(before_fact),
            source_after: declared_value_or_empty(after_fact),
            source_fact_before: before_fact,
            source_fact_after: after_fact,
            changed_fact_ids: [fact_id],
            evidence_layers: if complete && computed_before != computed_after {
              ["source_semantics", "computed_appearance"]
            } else {
              ["source_semantics"]
            },
            computed_relation: if complete {
              {
                status: if computed_before == computed_after {
                  "equivalent"
                } else {
                  "different"
                },
                reason_code: if computed_before == computed_after {
                  "same_resolved_clip_resource"
                } else {
                  "different_resolved_clip_resource"
                },
                missing_side: None,
                diagnostic_ids: [],
              }
            } else {
              {
                status: "indeterminate",
                reason_code: "clip_resource_coverage_partial",
                missing_side: None,
                diagnostic_ids,
              }
            },
            parameter_delta_css_px: None,
            presence_magnitude: None,
            magnitude: clip_resource_magnitude(before, after, property),
            domain_ordering: empty_domain_ordering(),
          })
          difference_ids.push(difference_id)
        }
        if !difference_ids.is_empty() {
          events.push({
            id: "event:clip:\{key}",
            primary_subject_id: key,
            atomic_difference_ids: difference_ids,
            rendered_outcome: if before.complete && after.complete {
              rendered
            } else {
              not_computed_rendered_evidence(
                "clip_resource_rendered_evidence_unavailable",
              )
            },
            difference_regions: [],
          })
        }
      }
      (before, after) => {
        let insertion = before is None
        let resource = match after {
          Some(resource) => resource
          None => before.unwrap()
        }
        let affected_subject_ids = clip_resource_affected_subjects(
          before_subjects, after_subjects, key,
        )
        let fact_id = "fact:clip:\{key}:presence"
        let difference_id = "diff:clip:\{key}:presence"
        let before_fact = before.map(resource => resource.presence_fact)
        let after_fact = after.map(resource => resource.presence_fact)
        let diagnostic_ids = clip_resource_diagnostic_ids(
          report,
          [resource.subject_id, ..affected_subject_ids],
        )
        changed_facts.push({
          id: fact_id,
          subject_id: resource.subject_id,
          property: "presence",
          before: before_fact,
          after: after_fact,
          affected_subject_ids,
        })
        differences.push({
          id: difference_id,
          subject_role: "resource",
          subject_alignment_id: None,
          domain: "resource.clip.presence",
          source_before: if insertion {
            ""
          } else {
            "present"
          },
          source_after: if insertion {
            "present"
          } else {
            ""
          },
          source_fact_before: before_fact,
          source_fact_after: after_fact,
          changed_fact_ids: [fact_id],
          evidence_layers: if affected_subject_ids.is_empty() {
            ["source_semantics"]
          } else {
            ["source_semantics", "computed_appearance"]
          },
          computed_relation: {
            status: if affected_subject_ids.is_empty() {
              "equivalent"
            } else {
              "not_applicable"
            },
            reason_code: if affected_subject_ids.is_empty() {
              "unreferenced_clip_resource"
            } else if insertion {
              "before_resource_absent"
            } else {
              "after_resource_absent"
            },
            missing_side: Some(if insertion { "before" } else { "after" }),
            diagnostic_ids,
          },
          parameter_delta_css_px: None,
          presence_magnitude: None,
          magnitude: empty_difference_magnitude(),
          domain_ordering: empty_domain_ordering(),
        })
        events.push({
          id: "event:clip:\{key}",
          primary_subject_id: key,
          atomic_difference_ids: [difference_id],
          rendered_outcome: if resource.complete {
            rendered
          } else {
            not_computed_rendered_evidence(
              "clip_resource_rendered_evidence_unavailable",
            )
          },
          difference_regions: [],
        })
      }
    }
  }
  { ..report, changed_facts, atomic_differences: differences, events }
}
