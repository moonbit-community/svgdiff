///|
fn visual_subject_kind(kind : String) -> Bool {
  match kind {
    "rect" | "circle" | "ellipse" | "line" | "polyline" | "polygon" | "path" =>
      true
    _ => false
  }
}

///|
fn structural_alignment_kind(kind : String) -> Bool {
  match kind {
    "g"
    | "text"
    | "use"
    | "symbol"
    | "linearGradient"
    | "radialGradient"
    | "pattern"
    | "marker"
    | "clipPath"
    | "mask"
    | "filter" => true
    _ => false
  }
}

///|
fn source_structural_alignment_basis(basis : String) -> Bool {
  basis == "structural_semantic_signature" ||
  basis == "resource_semantic_signature" ||
  basis == "structural_authored_id" ||
  basis == "resource_authored_id" ||
  basis == "structural_path" ||
  basis == "resource_path" ||
  basis == "stable_kind_order" ||
  basis == "resource_stable_kind_order" ||
  basis == "resource_unique_authored_id" ||
  basis == "resource_stable_image_source_order" ||
  basis == "unmatched_structural_subject" ||
  basis == "unmatched_visual_resource" ||
  basis == "unmatched_image_resource"
}

///|
fn visual_resource_alignment_kind(kind : String) -> Bool {
  match kind {
    "symbol"
    | "linearGradient"
    | "radialGradient"
    | "pattern"
    | "marker"
    | "clipPath"
    | "mask"
    | "filter" => true
    _ => false
  }
}

///|
fn structural_alignment_role(
  before : Array[StructuralAlignmentSubject],
  after : Array[StructuralAlignmentSubject],
) -> String {
  let kind = match before {
    [subject, ..] => subject.reference.kind
    [] => after[0].reference.kind
  }
  if visual_resource_alignment_kind(kind) {
    "resource"
  } else {
    "entity"
  }
}

///|
fn resource_alignment_basis(basis : String) -> String {
  match basis {
    "structural_semantic_signature" => "resource_semantic_signature"
    "structural_authored_id" => "resource_authored_id"
    "structural_path" => "resource_path"
    "stable_kind_order" => "resource_stable_kind_order"
    "unmatched_structural_subject" => "unmatched_visual_resource"
    _ => basis
  }
}

///|
fn resource_alignment_score_kind(score_kind : String) -> String {
  match score_kind {
    "structural_semantic_signature" => "resource_semantic_signature"
    "structural_authored_id" => "resource_authored_id"
    "structural_path" => "resource_path"
    "stable_kind_order" => "resource_stable_kind_order"
    _ => score_kind
  }
}

///|
fn structural_node_path_signature(
  document : StructuralDocument,
  node_index : Int,
) -> String {
  let segment = structural_path_segment(document, node_index)
  match document.nodes[node_index].parent_index {
    Some(parent_index) => {
      let parent = structural_node_path_signature(document, parent_index)
      if parent == "" {
        segment
      } else {
        "\{parent}/\{segment}"
      }
    }
    None => segment
  }
}

///|
fn structural_signature_attribute(
  attribute : @xml.NamespaceAttribute,
) -> String? {
  let local_name = attribute.name.local_name
  let unprefixed = attribute.name.prefix is None
  if (unprefixed && local_name == "id") ||
    (unprefixed && local_name.has_prefix("aria-")) ||
    (unprefixed && local_name.has_prefix("data-")) ||
    local_name == "xmlns" ||
    attribute.name.prefix == Some("xmlns") {
    return None
  }
  let expanded_name = match attribute.name.namespace_uri {
    Some(namespace_uri) => "{\{namespace_uri}}\{local_name}"
    None => local_name
  }
  let value = attribute.value.trim()
  Some("\{expanded_name.length()}:\{expanded_name}\{value.length()}:\{value}")
}

///|
fn structural_node_semantic_signature(
  document : StructuralDocument,
  node_index : Int,
) -> String {
  let node = document.nodes[node_index]
  let attributes : Array[String] = []
  for attribute in node.element.attributes {
    match structural_signature_attribute(attribute) {
      Some(signature) => attributes.push(signature)
      None => ()
    }
  }
  attributes.sort()
  let children = [
    for child in node.children => {
      structural_node_semantic_signature(document, child)
    }
  ]
  let text = if node.kind == "text" { node.direct_text } else { "" }
  let attribute_signature = attributes.join("|")
  let child_signature = children.join("|")
  "kind:\{node.kind.length()}:\{node.kind}|attrs:\{attribute_signature}|text:\{text.length()}:\{text}|children:\{child_signature}"
}

///|
fn structural_alignment_subjects(
  document : StructuralDocument,
) -> Array[StructuralAlignmentSubject] {
  let subjects : Array[StructuralAlignmentSubject] = []
  for node_index, node in document.nodes {
    if !structural_alignment_kind(node.kind) {
      continue
    }
    let authored_id = authored_subject_id(node.element)
    subjects.push({
      reference: {
        source_index: node.source_offset,
        kind: node.kind,
        authored_id,
        instance_context: None,
      },
      path_signature: structural_node_path_signature(document, node_index),
      semantic_signature: structural_node_semantic_signature(
        document, node_index,
      ),
    })
  }
  subjects
}

///|
fn alignment_property_order() -> Array[String] {
  [
    "x", "y", "width", "height", "rx", "ry", "cx", "cy", "r", "x1", "y1", "x2", "y2",
    "points", "fill", "fill-opacity", "fill-rule", "stroke", "stroke-opacity", "stroke-width",
    "stroke-linecap", "stroke-linejoin", "stroke-miterlimit", "stroke-dasharray",
    "stroke-dashoffset", "vector-effect", "marker", "marker-start", "marker-mid",
    "marker-end", "paint-order", "clip-rule", "opacity", "clip-path", "mask", "mask-mode",
  ]
}

///|
fn bounded_alignment_distance(value : Double) -> Double {
  if value <= 0.0 {
    0.0
  } else {
    value / (1.0 + value)
  }
}

///|
fn alignment_viewport_diagonal(profile : ComparisonProfile) -> Double {
  @math.hypot(
    profile.viewport_width.to_double(),
    profile.viewport_height.to_double(),
  ).max(1.0)
}

///|
fn alignment_subject_bounds(subject : SourceSubject) -> CssBounds? {
  if subject.transform_complete {
    source_subject_bounds(subject)
  } else {
    None
  }
}

///|
fn alignment_bounds_signature(subject : SourceSubject) -> String {
  match alignment_subject_bounds(subject) {
    Some(bounds) =>
      "bounds(\{bounds.x},\{bounds.y},\{bounds.width},\{bounds.height})"
    None => "bounds-unavailable"
  }
}

///|
fn exact_subject_alignment_signature(subject : SourceSubject) -> String {
  let transform = if subject.transform_complete {
    subject.cumulative_transform.signature()
  } else {
    "transform-incomplete"
  }
  "\{subject.signature}|alignment-transform=\{transform}|alignment-\{alignment_bounds_signature(subject)}"
}

///|
fn alignment_declared_fact_signature(fact : DeclaredVisualFact?) -> String {
  match fact {
    Some(fact) => {
      let value = fact.declared_value
      let origin = fact.origin
      "present:\{value.length()}:\{value}:\{origin.length()}:\{origin}"
    }
    None => "absent"
  }
}

///|
fn alignment_transform_chain_signature(subject : SourceSubject) -> String {
  let sites : Array[String] = []
  for site in subject.transform_chain {
    let viewport_facts = [
      for fact in site.viewport_facts => {
        "\{fact.property}=\{alignment_declared_fact_signature(Some(fact))}"
      }
    ]
    viewport_facts.sort()
    sites.push(
      "\{site.kind}:\{site.complete}:\{site.normalized_signature}:\{alignment_declared_fact_signature(site.fact)}:viewport=\{viewport_facts.join("|")}",
    )
  }
  sites.join(";")
}

///|
fn alignment_path_source_signature(subject : SourceSubject) -> String {
  let segments : Array[String] = []
  for segment in subject.path_segments {
    segments.push(
      "\{segment.authored_command}:\{normalized_path_segment_signature(segment.normalized)}",
    )
  }
  segments.join(";")
}

///|
fn repeated_subject_equivalence_signature(subject : SourceSubject) -> String {
  let facts : Array[String] = []
  for property in alignment_property_order() {
    facts.push(
      "\{property}=\{alignment_declared_fact_signature(source_subject_fact(subject, property))}",
    )
  }
  "\{exact_subject_alignment_signature(subject)}|source-facts=\{facts.join("|")}|source-path=\{alignment_path_source_signature(subject)}|source-transform=\{alignment_transform_chain_signature(subject)}"
}

///|
fn rendered_bounds_feature_distance(
  left : SourceSubject,
  right : SourceSubject,
  profile : ComparisonProfile,
) -> Double? {
  match (alignment_subject_bounds(left), alignment_subject_bounds(right)) {
    (None, None) => None
    (Some(_), None) | (None, Some(_)) => Some(1.0)
    (Some(left), Some(right)) => {
      let diagonal = alignment_viewport_diagonal(profile)
      let left_center_x = left.x + left.width / 2.0
      let left_center_y = left.y + left.height / 2.0
      let right_center_x = right.x + right.width / 2.0
      let right_center_y = right.y + right.height / 2.0
      Some(
        (
          bounded_alignment_distance(
            (left_center_x - right_center_x).abs() / diagonal,
          ) +
          bounded_alignment_distance(
            (left_center_y - right_center_y).abs() / diagonal,
          ) +
          bounded_alignment_distance(
            (left.width - right.width).abs() / diagonal,
          ) +
          bounded_alignment_distance(
            (left.height - right.height).abs() / diagonal,
          )
        ) /
        4.0,
      )
    }
  }
}

///|
fn transform_probe_feature_distance(
  left : SourceSubject,
  right : SourceSubject,
  profile : ComparisonProfile,
) -> Double? {
  match (left.transform_complete, right.transform_complete) {
    (false, false) => None
    (true, false) | (false, true) => Some(1.0)
    (true, true) => {
      let width = profile.viewport_width.to_double()
      let height = profile.viewport_height.to_double()
      let diagonal = alignment_viewport_diagonal(profile)
      let probes = [(0.0, 0.0), (width, 0.0), (0.0, height), (width, height)]
      let mut distance = 0.0
      for probe in probes {
        let (x, y) = probe
        let (left_x, left_y) = left.cumulative_transform.apply_point(x, y)
        let (right_x, right_y) = right.cumulative_transform.apply_point(x, y)
        distance += bounded_alignment_distance(
          @math.hypot(left_x - right_x, left_y - right_y) / diagonal,
        )
      }
      Some(distance / probes.length().to_double())
    }
  }
}

///|
fn alignment_property_feature_distance(
  left : SourceSubject,
  right : SourceSubject,
) -> Double {
  let mut distance = 0.0
  let mut compared = 0
  for property in alignment_property_order() {
    if basic_shape_geometry_property(left.kind, property) {
      continue
    }
    let left_value = subject_value(left, property)
    let right_value = subject_value(right, property)
    if left_value is None && right_value is None {
      continue
    }
    compared += 1
    if left_value == right_value {
      continue
    }
    match
      (parse_alignment_number(left_value), parse_alignment_number(right_value)) {
      (Some(left_number), Some(right_number)) =>
        distance += bounded_alignment_distance(
          (left_number - right_number).abs() /
          (left_number.abs() + right_number.abs() + 1.0),
        )
      _ => distance += 1.0
    }
  }
  if compared == 0 {
    0.0
  } else {
    distance / compared.to_double()
  }
}

///|
fn alignment_point_distance(
  left : AffineTransform,
  left_x : Double,
  left_y : Double,
  right : AffineTransform,
  right_x : Double,
  right_y : Double,
  diagonal : Double,
) -> Double {
  let (left_x, left_y) = left.apply_point(left_x, left_y)
  let (right_x, right_y) = right.apply_point(right_x, right_y)
  bounded_alignment_distance(
    @math.hypot(left_x - right_x, left_y - right_y) / diagonal,
  )
}

///|
fn path_segment_feature_distance(
  left : NormalizedPathSegment,
  left_transform : AffineTransform,
  right : NormalizedPathSegment,
  right_transform : AffineTransform,
  diagonal : Double,
) -> Double {
  match (left, right) {
    (MoveTo(left_x, left_y), MoveTo(right_x, right_y))
    | (LineTo(left_x, left_y), LineTo(right_x, right_y)) =>
      alignment_point_distance(
        left_transform, left_x, left_y, right_transform, right_x, right_y, diagonal,
      )
    (CubicTo(lx1, ly1, lx2, ly2, lx, ly), CubicTo(rx1, ry1, rx2, ry2, rx, ry)) =>
      (
        alignment_point_distance(
          left_transform, lx1, ly1, right_transform, rx1, ry1, diagonal,
        ) +
        alignment_point_distance(
          left_transform, lx2, ly2, right_transform, rx2, ry2, diagonal,
        ) +
        alignment_point_distance(
          left_transform, lx, ly, right_transform, rx, ry, diagonal,
        )
      ) /
      3.0
    (QuadraticTo(lx1, ly1, lx, ly), QuadraticTo(rx1, ry1, rx, ry)) =>
      (
        alignment_point_distance(
          left_transform, lx1, ly1, right_transform, rx1, ry1, diagonal,
        ) +
        alignment_point_distance(
          left_transform, lx, ly, right_transform, rx, ry, diagonal,
        )
      ) /
      2.0
    (
      ArcTo(lrx, lry, lrotation, llarge, lsweep, lx, ly),
      ArcTo(rrx, rry, rrotation, rlarge, rsweep, rx, ry),
    ) => {
      let parameter_distance = bounded_alignment_distance(
        (lrx - rrx).abs() +
        (lry - rry).abs() +
        (lrotation - rrotation).abs() / 180.0 +
        (if llarge == rlarge { 0.0 } else { 1.0 }) +
        (if lsweep == rsweep { 0.0 } else { 1.0 }),
      )
      (
        alignment_point_distance(
          left_transform, lx, ly, right_transform, rx, ry, diagonal,
        ) +
        parameter_distance
      ) /
      2.0
    }
    (ClosePath, ClosePath) => 0.0
    _ => 1.0
  }
}

///|
fn path_feature_distance(
  left : SourceSubject,
  right : SourceSubject,
  profile : ComparisonProfile,
) -> Double? {
  if left.kind != "path" || right.kind != "path" {
    return None
  }
  match (left.transform_complete, right.transform_complete) {
    (false, false) => return None
    (true, false) | (false, true) => return Some(1.0)
    (true, true) => ()
  }
  if left.path_data_complete != right.path_data_complete {
    return Some(1.0)
  }
  if left.path_segments.length() != right.path_segments.length() {
    return Some(1.0)
  }
  if left.path_segments.is_empty() {
    return Some(0.0)
  }
  let diagonal = alignment_viewport_diagonal(profile)
  let mut distance = 0.0
  for index in 0..<left.path_segments.length() {
    distance += path_segment_feature_distance(
      left.path_segments[index].normalized,
      left.cumulative_transform,
      right.path_segments[index].normalized,
      right.cumulative_transform,
      diagonal,
    )
  }
  Some(distance / left.path_segments.length().to_double())
}

///|
fn subject_alignment_feature_distance(
  left : SourceSubject,
  right : SourceSubject,
  profile : ComparisonProfile,
) -> Double {
  let rendered_bounds = rendered_bounds_feature_distance(left, right, profile)
  let transform_probes = match rendered_bounds {
    Some(_) => None
    None => transform_probe_feature_distance(left, right, profile)
  }
  let appearance = alignment_property_feature_distance(left, right)
  let hierarchy = if left.hierarchy_signature == right.hierarchy_signature {
    0.0
  } else {
    1.0
  }
  let path = path_feature_distance(left, right, profile)
  let mut total = appearance + hierarchy
  let mut count = 2
  match rendered_bounds {
    Some(value) => {
      total += value
      count += 1
    }
    None => ()
  }
  match transform_probes {
    Some(value) => {
      total += value
      count += 1
    }
    None => ()
  }
  match path {
    Some(value) => {
      total += value
      count += 1
    }
    None => ()
  }
  total / count.to_double()
}

///|
fn subject_value(subject : SourceSubject, property : String) -> String? {
  for item in subject.values {
    let (name, value) = item
    if name == property {
      return Some(value)
    }
  }
  None
}
