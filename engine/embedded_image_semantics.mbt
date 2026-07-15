///|
priv struct EmbeddedImageSubject {
  reference : SubjectReference
  subject_id : String
  href_fact : DeclaredVisualFact?
  compact_href_fact : DeclaredVisualFact?
  href_authored : String?
  raster : EmbeddedRasterDecodeResult
  x_fact : DeclaredVisualFact?
  y_fact : DeclaredVisualFact?
  width_fact : DeclaredVisualFact?
  height_fact : DeclaredVisualFact?
  opacity_fact : DeclaredVisualFact?
  preserve_aspect_ratio_fact : DeclaredVisualFact?
  x : Double
  y : Double
  width : Double
  height : Double
  opacity : Double
  preserve_aspect_ratio : String
  cumulative_transform : AffineTransform
  placement_complete : Bool
  direct_visual : Bool
}

///|
fn embedded_image_property(property : String) -> Bool {
  property == "x" ||
  property == "y" ||
  property == "width" ||
  property == "height" ||
  property == "opacity"
}

///|
fn embedded_image_fact(
  facts : Array[DeclaredVisualFact],
  property : String,
) -> DeclaredVisualFact? {
  declared_fact_in_array(facts, property)
}

///|
fn embedded_image_cascade_facts(
  input : String,
  element : @xml.NamespaceElement,
  source_offset : Int,
  css_document : CssStaticDocument,
) -> Array[DeclaredVisualFact] {
  let candidates : Array[CssCascadeCandidate] = []
  let mut style_attribute : @xml.NamespaceAttribute? = None
  for attribute in element.attributes {
    let name = attribute.name.local_name
    if embedded_image_property(name) {
      candidates.push(
        presentation_cascade_candidate(
          presentation_fact(input, name, attribute),
          attribute.span.start.offset,
        ),
      )
    } else if name == "style" {
      style_attribute = Some(attribute)
    }
  }
  match style_attribute {
    Some(attribute) => {
      let style = inline_style_facts(input, attribute)
      for candidate in style.candidates {
        if embedded_image_property(candidate.declaration.property) {
          candidates.push(candidate)
        }
      }
    }
    None => ()
  }
  let stylesheet = css_stylesheet_match_for_source(css_document, source_offset)
  for candidate in stylesheet.candidates {
    if embedded_image_property(candidate.declaration.property) {
      candidates.push(candidate)
    }
  }
  cascade_visual_declarations(candidates)
}

///|
fn embedded_image_attribute_fact(
  input : String,
  element : @xml.NamespaceElement,
  property : String,
) -> DeclaredVisualFact? {
  for attribute in element.attributes {
    if attribute.name.local_name == property {
      return Some(presentation_fact(input, property, attribute))
    }
  }
  None
}

///|
fn embedded_image_href_summary(result : EmbeddedRasterDecodeResult) -> String {
  match result {
    EmbeddedRasterDecoded(image) =>
      "\{image.source_kind}:\{image.media_type};encoding=\{image.encoding};bytes=\{image.encoded_bytes};encoded_sha256=\{image.encoded_sha256};intrinsic=\{image.width}x\{image.height};rgba8_sha256=\{image.rgba8_sha256}"
    EmbeddedRasterUnsupported(reason) => "unsupported:\{reason}"
    EmbeddedRasterInvalid(reason) => "invalid:\{reason}"
    EmbeddedRasterLimitExceeded(reason) => "limit_exceeded:\{reason}"
    EmbeddedRasterBundleMissing => "resource_bundle_entry_missing"
  }
}

///|
fn compact_embedded_image_href_fact(
  fact : DeclaredVisualFact?,
  raster : EmbeddedRasterDecodeResult,
) -> DeclaredVisualFact? {
  fact.map(value => {
    let summary = embedded_image_href_summary(raster)
    { ..value, authored_value: summary, declared_value: summary }
  })
}

///|
fn embedded_image_position(
  fact : DeclaredVisualFact?,
  direction : SvgLengthDirection,
  viewport : ViewportContext,
  profile : ComparisonProfile,
) -> (Double, Bool) {
  match fact {
    None => (0.0, true)
    Some(fact) =>
      match
        parse_svg_length(fact.declared_value, direction, viewport, profile) {
        Some(value) => (value, true)
        None => (0.0, false)
      }
  }
}

///|
fn embedded_image_explicit_dimension(
  fact : DeclaredVisualFact?,
  direction : SvgLengthDirection,
  viewport : ViewportContext,
  profile : ComparisonProfile,
) -> (Double?, Bool) {
  match fact {
    None => (None, true)
    Some(fact) if fact.declared_value.trim().to_owned().to_lower() == "auto" =>
      (None, true)
    Some(fact) =>
      match
        parse_svg_length(fact.declared_value, direction, viewport, profile) {
        Some(value) if value >= 0.0 => (Some(value), true)
        _ => (None, false)
      }
  }
}

///|
fn embedded_image_intrinsic_size(
  raster : EmbeddedRasterDecodeResult,
) -> (Double, Double)? {
  match raster {
    EmbeddedRasterDecoded(image) =>
      Some((image.width.to_double(), image.height.to_double()))
    _ => None
  }
}

///|
fn embedded_image_used_size(
  raster : EmbeddedRasterDecodeResult,
  width_fact : DeclaredVisualFact?,
  height_fact : DeclaredVisualFact?,
  viewport : ViewportContext,
  profile : ComparisonProfile,
) -> (Double, Double, Bool) {
  let (explicit_width, width_complete) = embedded_image_explicit_dimension(
    width_fact,
    Horizontal,
    viewport,
    profile,
  )
  let (explicit_height, height_complete) = embedded_image_explicit_dimension(
    height_fact,
    Vertical,
    viewport,
    profile,
  )
  guard width_complete && height_complete else { return (0.0, 0.0, false) }
  match
    (explicit_width, explicit_height, embedded_image_intrinsic_size(raster)) {
    (Some(width), Some(height), _) => (width, height, true)
    (None, None, Some((width, height))) => (width, height, true)
    (Some(width), None, Some((intrinsic_width, intrinsic_height))) =>
      (width, width * intrinsic_height / intrinsic_width, true)
    (None, Some(height), Some((intrinsic_width, intrinsic_height))) =>
      (height * intrinsic_width / intrinsic_height, height, true)
    _ => (0.0, 0.0, false)
  }
}

///|
fn embedded_image_opacity(fact : DeclaredVisualFact?) -> (Double, Bool) {
  match fact {
    None => (1.0, true)
    Some(fact) =>
      match @css_color.parse_alpha_value(fact.declared_value) {
        Some(value) => (value, true)
        None => (1.0, false)
      }
  }
}

///|
fn embedded_image_preserve_aspect_ratio(
  fact : DeclaredVisualFact?,
) -> (String, Bool) {
  match fact {
    None =>
      (preserve_aspect_ratio_signature(default_preserve_aspect_ratio()), true)
    Some(fact) =>
      match parse_preserve_aspect_ratio_value(fact.declared_value) {
        Some(value) => (preserve_aspect_ratio_signature(value), true)
        None => (fact.declared_value, false)
      }
  }
}

///|
fn embedded_image_subject_from_element(
  input : String,
  element : @xml.NamespaceElement,
  source_offset : Int,
  source_index : Int,
  transform_chain : Array[SourceTransformSite],
  viewport : ViewportContext,
  profile : ComparisonProfile,
  css_document : CssStaticDocument,
  direct_visual : Bool,
  bundle : ResourceBundle,
  limits : ResourceLimits,
) -> EmbeddedImageSubject {
  let reference : SubjectReference = {
    source_index,
    kind: "image",
    authored_id: authored_subject_id(element),
    instance_context: None,
  }
  let subject_id = reference.authored_id.unwrap_or("image:\{source_index}")
  let href_fact = structural_href_fact(input, element)
  let href_authored = href_fact.map(fact => fact.declared_value)
  let raster = match href_authored {
    Some(value) =>
      decode_embedded_raster(
        value,
        bundle,
        limits.max_embedded_data_uri_bytes,
        limits.max_embedded_data_bytes,
        limits.max_resource_bundle_entry_bytes,
        limits.max_embedded_raster_dimension,
        limits.max_embedded_raster_pixels,
      )
    None => EmbeddedRasterInvalid("embedded_raster_href_missing")
  }
  let facts = embedded_image_cascade_facts(
    input, element, source_offset, css_document,
  )
  let x_fact = embedded_image_fact(facts, "x")
  let y_fact = embedded_image_fact(facts, "y")
  let width_fact = embedded_image_fact(facts, "width")
  let height_fact = embedded_image_fact(facts, "height")
  let opacity_fact = embedded_image_fact(facts, "opacity")
  let preserve_aspect_ratio_fact = embedded_image_attribute_fact(
    input, element, "preserveAspectRatio",
  )
  let (x, x_complete) = embedded_image_position(
    x_fact,
    Horizontal,
    viewport,
    profile,
  )
  let (y, y_complete) = embedded_image_position(
    y_fact,
    Vertical,
    viewport,
    profile,
  )
  let (width, height, size_complete) = embedded_image_used_size(
    raster, width_fact, height_fact, viewport, profile,
  )
  let (opacity, opacity_complete) = embedded_image_opacity(opacity_fact)
  let (preserve_aspect_ratio, preserve_complete) = embedded_image_preserve_aspect_ratio(
    preserve_aspect_ratio_fact,
  )
  let (cumulative_transform, transform_complete, _) = cumulative_transform(
    transform_chain,
  )
  {
    reference,
    subject_id,
    href_fact,
    compact_href_fact: compact_embedded_image_href_fact(href_fact, raster),
    href_authored,
    raster,
    x_fact,
    y_fact,
    width_fact,
    height_fact,
    opacity_fact,
    preserve_aspect_ratio_fact,
    x,
    y,
    width,
    height,
    opacity,
    preserve_aspect_ratio,
    cumulative_transform,
    placement_complete: x_complete &&
    y_complete &&
    size_complete &&
    opacity_complete &&
    preserve_complete &&
    transform_complete,
    direct_visual,
  }
}

///|
fn embedded_image_definition_container(kind : String) -> Bool {
  kind == "defs" ||
  kind == "symbol" ||
  kind == "pattern" ||
  kind == "marker" ||
  kind == "clipPath" ||
  kind == "mask" ||
  kind == "filter"
}

///|
fn embedded_image_only_scene(input : String) -> Bool raise {
  let mut images = 0
  let reader = @xml.NamespaceReader::from_string(input)
  for event in reader.read_events_until_eof() {
    match event.kind {
      Start(element) | Empty(element) =>
        match element.name.local_name {
          "image" => images += 1
          "svg" | "g" | "defs" | "title" | "desc" | "metadata" | "style" => ()
          _ => return false
        }
      _ => ()
    }
  }
  images > 0
}

///|
fn extract_embedded_image_subjects_or_raise(
  input : String,
  profile : ComparisonProfile,
  bundle : ResourceBundle,
  limits : ResourceLimits,
) -> Array[EmbeddedImageSubject] raise {
  let css_document = parse_static_css_document_or_raise(input)
  let subjects : Array[EmbeddedImageSubject] = []
  let transforms : Array[SourceTransformSite] = []
  let viewport_contexts : Array[ViewportContext] = []
  let mut node_index = 0
  let mut definition_depth = 0
  let reader = @xml.NamespaceReader::from_string(input)
  for event in reader.read_events_until_eof() {
    match event.kind {
      Start(element) => {
        let kind = element.name.local_name
        let (transform, child_viewport) = source_transform_site_with_viewport(
          input,
          element,
          node_index,
          profile,
          viewport_contexts.last(),
        )
        node_index += 1
        transforms.push(transform)
        if kind == "svg" {
          match child_viewport {
            Some(value) => viewport_contexts.push(value)
            None => ()
          }
        }
        if kind == "image" {
          subjects.push(
            embedded_image_subject_from_element(
              input,
              element,
              event.span.start.offset,
              subjects.length(),
              transforms.copy(),
              viewport_contexts
              .last()
              .unwrap_or({
                width: profile.viewport_width.to_double(),
                height: profile.viewport_height.to_double(),
              }),
              profile,
              css_document,
              definition_depth == 0,
              bundle,
              limits,
            ),
          )
        }
        if embedded_image_definition_container(kind) {
          definition_depth += 1
        }
      }
      Empty(element) => {
        let kind = element.name.local_name
        let (transform, _) = source_transform_site_with_viewport(
          input,
          element,
          node_index,
          profile,
          viewport_contexts.last(),
        )
        node_index += 1
        if kind == "image" {
          let chain = transforms.copy()
          chain.push(transform)
          subjects.push(
            embedded_image_subject_from_element(
              input,
              element,
              event.span.start.offset,
              subjects.length(),
              chain,
              viewport_contexts
              .last()
              .unwrap_or({
                width: profile.viewport_width.to_double(),
                height: profile.viewport_height.to_double(),
              }),
              profile,
              css_document,
              definition_depth == 0,
              bundle,
              limits,
            ),
          )
        }
      }
      End(name) => {
        if embedded_image_definition_container(name.local_name) {
          definition_depth -= 1
        }
        ignore(transforms.pop())
        if name.local_name == "svg" {
          ignore(viewport_contexts.pop())
        }
      }
      _ => ()
    }
  }
  subjects
}

///|
fn embedded_image_subject_bounds(subject : EmbeddedImageSubject) -> CssBounds? {
  if !subject.direct_visual || !subject.placement_complete {
    return None
  }
  Some(
    transform_bounds(
      {
        x: subject.x,
        y: subject.y,
        width: subject.width,
        height: subject.height,
      },
      subject.cumulative_transform,
    ),
  )
}

///|
fn embedded_image_unique_id_count(
  subjects : Array[EmbeddedImageSubject],
  id : String,
) -> Int {
  let mut count = 0
  for subject in subjects {
    if subject.reference.authored_id == Some(id) {
      count += 1
    }
  }
  count
}

///|
fn embedded_image_alignment(
  index : Int,
  relation : String,
  before : EmbeddedImageSubject?,
  after : EmbeddedImageSubject?,
  basis : String,
) -> SubjectAlignment {
  {
    id: "alignment:image:\{index}",
    relation,
    before: before.map(subject => [subject.reference]).unwrap_or([]),
    after: after.map(subject => [subject.reference]).unwrap_or([]),
    basis,
    evidence: alignment_evidence(
      "embedded_image_source_order_v1",
      if relation == "correspondence" {
        Some(0.0)
      } else {
        None
      },
      if relation == "correspondence" {
        1
      } else {
        0
      },
      if relation == "correspondence" {
        1
      } else {
        0
      },
      if relation == "correspondence" {
        "unique"
      } else {
        "not_assessed"
      },
    ),
  }
}

///|
fn embedded_image_alignments(
  before : Array[EmbeddedImageSubject],
  after : Array[EmbeddedImageSubject],
) -> Array[SubjectAlignment] {
  let alignments : Array[SubjectAlignment] = []
  let before_used = Array::make(before.length(), false)
  let after_used = Array::make(after.length(), false)
  for before_index, subject in before {
    guard subject.reference.authored_id is Some(id) else { continue }
    if embedded_image_unique_id_count(before, id) != 1 ||
      embedded_image_unique_id_count(after, id) != 1 {
      continue
    }
    for after_index, candidate in after {
      if candidate.reference.authored_id == Some(id) {
        alignments.push(
          embedded_image_alignment(
            alignments.length(),
            "correspondence",
            Some(subject),
            Some(candidate),
            "unique_authored_id",
          ),
        )
        before_used[before_index] = true
        after_used[after_index] = true
        break
      }
    }
  }
  let remaining_before = [
    for index in 0..<before.length() if !before_used[index] => index
  ]
  let remaining_after = [
    for index in 0..<after.length() if !after_used[index] => index
  ]
  let paired = remaining_before.length().min(remaining_after.length())
  for index in 0..<paired {
    let before_index = remaining_before[index]
    let after_index = remaining_after[index]
    alignments.push(
      embedded_image_alignment(
        alignments.length(),
        "correspondence",
        Some(before[before_index]),
        Some(after[after_index]),
        "stable_image_source_order",
      ),
    )
    before_used[before_index] = true
    after_used[after_index] = true
  }
  for index, subject in before {
    if !before_used[index] {
      alignments.push(
        embedded_image_alignment(
          alignments.length(),
          "deletion",
          Some(subject),
          None,
          "unmatched_image_subject",
        ),
      )
    }
  }
  for index, subject in after {
    if !after_used[index] {
      alignments.push(
        embedded_image_alignment(
          alignments.length(),
          "insertion",
          None,
          Some(subject),
          "unmatched_image_subject",
        ),
      )
    }
  }
  alignments
}

///|
fn embedded_image_alignments_for_sources(
  before_svg : String,
  after_svg : String,
  profile : ComparisonProfile,
  before_bundle : ResourceBundle,
  after_bundle : ResourceBundle,
  limits : ResourceLimits,
) -> Array[SubjectAlignment] {
  let before = extract_embedded_image_subjects_or_raise(
    before_svg, profile, before_bundle, limits,
  ) catch {
    _ => return []
  }
  let after = extract_embedded_image_subjects_or_raise(
    after_svg, profile, after_bundle, limits,
  ) catch {
    _ => return []
  }
  embedded_image_alignments(before, after)
}

///|
fn embedded_image_diagnostic_location(
  source_role : String,
  subject : EmbeddedImageSubject,
) -> Array[DiagnosticSourceLocation] {
  match subject.href_fact {
    Some(fact) => [diagnostic_location(source_role, fact.source_span)]
    None => []
  }
}

///|
fn embedded_image_diagnostic(
  source_role : String,
  subject : EmbeddedImageSubject,
  code : String,
  layers : Array[String],
) -> Diagnostic {
  {
    id: "diagnostic:\{code}:\{source_role}:\{subject.reference.source_index}",
    code,
    subject_id: subject.subject_id,
    affected_evidence_layers: layers,
    source_locations: embedded_image_diagnostic_location(source_role, subject),
  }
}

///|
fn embedded_image_preflight_diagnostics(
  input : String,
  profile : ComparisonProfile,
  source_role : String,
  bundle : ResourceBundle,
  limits : ResourceLimits,
) -> Array[Diagnostic] raise {
  let diagnostics : Array[Diagnostic] = []
  for
    subject in extract_embedded_image_subjects_or_raise(
      input, profile, bundle, limits,
    ) {
    match subject.raster {
      EmbeddedRasterDecoded(_) =>
        diagnostics.push(
          embedded_image_diagnostic(
            source_role,
            subject,
            "renderer_embedded_raster_unavailable",
            ["rendered_evidence"],
          ),
        )
      EmbeddedRasterUnsupported(reason) =>
        diagnostics.push(
          embedded_image_diagnostic(
            source_role,
            subject,
            if reason == "embedded_raster_variant_unsupported" {
              "embedded_raster_variant_unsupported"
            } else {
              "embedded_raster_media_type_unsupported"
            },
            ["computed_appearance", "rendered_evidence"],
          ),
        )
      EmbeddedRasterInvalid(_) =>
        diagnostics.push(
          embedded_image_diagnostic(
            source_role,
            subject,
            "embedded_raster_data_invalid",
            ["computed_appearance", "rendered_evidence"],
          ),
        )
      EmbeddedRasterLimitExceeded(dimension) =>
        diagnostics.push(
          unlocated_diagnostic(
            "diagnostic:resource-limit-exceeded:\{source_role}:\{dimension}",
            "resource_limit_exceeded",
            "\{source_role}:\{dimension}",
            ["source_semantics", "computed_appearance", "rendered_evidence"],
          ),
        )
      EmbeddedRasterBundleMissing =>
        diagnostics.push(
          embedded_image_diagnostic(
            source_role,
            subject,
            "resource_bundle_entry_missing",
            ["computed_appearance", "rendered_evidence"],
          ),
        )
    }
    if !subject.placement_complete {
      diagnostics.push(
        embedded_image_diagnostic(
          source_role,
          subject,
          "embedded_image_placement_unsupported",
          ["computed_appearance", "rendered_evidence"],
        ),
      )
    }
    if !subject.direct_visual {
      diagnostics.push(
        embedded_image_diagnostic(
          source_role,
          subject,
          "embedded_image_instance_resolution_unsupported",
          ["computed_appearance", "rendered_evidence"],
        ),
      )
    }
  }
  diagnostics
}
