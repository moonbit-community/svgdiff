///|
/// Fixed safety budgets for one comparison.
///
/// This type stays package-private so production callers share one versioned
/// contract while whitebox tests can exercise exact boundaries cheaply.
priv struct ResourceLimits {
  max_input_bytes : Int
  max_elements : Int
  max_path_data_units : Int
  max_nesting_depth : Int
  max_references : Int
  max_reference_graph_edges : Int
  max_expanded_elements : Int
  max_embedded_data_uri_bytes : Int
  max_embedded_data_bytes : Int
  max_embedded_raster_dimension : Int
  max_embedded_raster_pixels : Int
  max_resource_bundle_entries : Int
  max_resource_bundle_entry_bytes : Int
  max_resource_bundle_bytes : Int
  max_raster_dimension : Int
  max_raster_pixels : Int
  max_regions : Int
  max_perceptual_map_pixels : Int
  max_perceptual_flip_samples : Int
  max_report_bytes : Int
}

///|
fn default_resource_limits() -> ResourceLimits {
  {
    max_input_bytes: 8_388_608,
    max_elements: 100_000,
    max_path_data_units: 1_000_000,
    max_nesting_depth: 256,
    max_references: 100_000,
    max_reference_graph_edges: 1_000_000,
    max_expanded_elements: 1_000_000,
    max_embedded_data_uri_bytes: 6_291_456,
    max_embedded_data_bytes: 4_194_304,
    max_embedded_raster_dimension: 8_192,
    max_embedded_raster_pixels: 16_777_216,
    max_resource_bundle_entries: 1_024,
    max_resource_bundle_entry_bytes: 4_194_304,
    max_resource_bundle_bytes: 16_777_216,
    max_raster_dimension: 8_192,
    max_raster_pixels: 16_777_216,
    max_regions: 65_536,
    max_perceptual_map_pixels: 1_048_576,
    max_perceptual_flip_samples: 268_435_456,
    max_report_bytes: 33_554_432,
  }
}

///|
fn utf8_character_bytes(character : Char) -> Int {
  let codepoint = character.to_int()
  if codepoint <= 0x7f {
    1
  } else if codepoint <= 0x7ff {
    2
  } else if codepoint <= 0xffff {
    3
  } else {
    4
  }
}

///|
fn utf8_byte_length(value : String) -> Int {
  value.fold(init=0, fn(length, character) {
    length + utf8_character_bytes(character)
  })
}

///|
fn utf8_byte_length_exceeds(value : String, limit : Int) -> Bool {
  let mut length = 0
  for character in value {
    length += utf8_character_bytes(character)
    if length > limit {
      return true
    }
  }
  false
}

///|
fn limit_subject(dimension : String, source_role : String?) -> String {
  match source_role {
    Some(role) => "\{dimension}.\{role}"
    None => dimension
  }
}

///|
fn resource_limit_diagnostic(
  dimension : String,
  source_role : String?,
  span : @xml.SourceSpan?,
) -> Diagnostic {
  let subject_id = limit_subject(dimension, source_role)
  let source_locations = match (source_role, span) {
    (Some(role), Some(span)) => [diagnostic_location_from_xml(role, span)]
    _ => []
  }
  {
    id: "diagnostic:resource-limit-exceeded:\{subject_id}",
    code: "resource_limit_exceeded",
    subject_id,
    affected_evidence_layers: [
      "source_semantics", "computed_appearance", "rendered_evidence",
    ],
    source_locations,
  }
}

///|
fn failed_resource_report(
  profile : ComparisonProfile,
  diagnostics : Array[Diagnostic],
) -> StructuredReport {
  let coverage_matrix : Array[FeatureCoverage] = []
  for diagnostic in diagnostics {
    coverage_matrix.push({
      feature_id: "resource.\{diagnostic.subject_id}",
      subject_id: diagnostic.subject_id,
      source_semantics: "failed",
      computed_appearance: "failed",
      rendered_evidence: "failed",
      diagnostic_ids: [diagnostic.id],
    })
  }
  coverage_matrix.sort_by(fn(left, right) {
    let feature_order = left.feature_id.compare(right.feature_id)
    if feature_order != 0 {
      feature_order
    } else {
      left.subject_id.compare(right.subject_id)
    }
  })
  {
    schema_version: "1.44",
    analysis_status: "failed",
    impact_assessment: empty_impact_assessment(),
    coverage_matrix,
    renderer_capability_gaps: [],
    profile,
    subject_alignments: [],
    changed_facts: [],
    source_resolutions: [],
    atomic_differences: [],
    events: [],
    diagnostics,
  }
}

///|
fn path_data_units(value : String) -> Int {
  let mut units = 0
  for character in value {
    match character.to_int() {
      0x09 | 0x0a | 0x0c | 0x0d | 0x20 | 0x2c => ()
      _ => units += 1
    }
  }
  units
}

///|
fn reference_count(attribute : @xml.NamespaceAttribute) -> Int {
  let mut count = if attribute.name.local_name == "href" { 1 } else { 0 }
  let url_parts = attribute.value.to_lower().split("url(").count()
  if url_parts > 1 {
    count += url_parts - 1
  }
  count
}

///|
fn source_structure_limit(
  input : String,
  source_role : String,
  limits : ResourceLimits,
) -> Diagnostic? raise {
  let reader = @xml.NamespaceReader::from_string(input)
  let mut elements = 0
  let mut nesting_depth = 0
  let mut path_units = 0
  let mut references = 0
  while !reader.is_eof() {
    let event = reader.read_event()
    match event.kind {
      Start(element) | Empty(element) => {
        elements += 1
        if elements > limits.max_elements {
          return Some(
            resource_limit_diagnostic(
              "elements",
              Some(source_role),
              Some(event.span),
            ),
          )
        }
        match event.kind {
          Start(_) => {
            nesting_depth += 1
            if nesting_depth > limits.max_nesting_depth {
              return Some(
                resource_limit_diagnostic(
                  "nesting_depth",
                  Some(source_role),
                  Some(event.span),
                ),
              )
            }
          }
          _ => ()
        }
        for attribute in element.attributes {
          if element.name.local_name == "path" &&
            attribute.name.local_name == "d" {
            path_units += path_data_units(attribute.value)
            if path_units > limits.max_path_data_units {
              return Some(
                resource_limit_diagnostic(
                  "path_data_units",
                  Some(source_role),
                  Some(attribute.span),
                ),
              )
            }
          }
          references += reference_count(attribute)
          if references > limits.max_references {
            return Some(
              resource_limit_diagnostic(
                "references",
                Some(source_role),
                Some(attribute.span),
              ),
            )
          }
        }
      }
      End(_) => nesting_depth -= 1
      Eof => break
      _ => ()
    }
  }
  None
}

///|
fn raster_limit(
  profile : ComparisonProfile,
  limits : ResourceLimits,
) -> Diagnostic? {
  let width = profile.viewport_width
  let height = profile.viewport_height
  if width <= 0 ||
    height <= 0 ||
    width > limits.max_raster_dimension ||
    height > limits.max_raster_dimension ||
    width * height > limits.max_raster_pixels {
    Some(resource_limit_diagnostic("raster_dimensions", None, None))
  } else {
    None
  }
}

///|
fn source_limit(
  input : String,
  source_role : String,
  bundle : ResourceBundle,
  limits : ResourceLimits,
) -> (Diagnostic?, String) {
  if utf8_byte_length_exceeds(input, limits.max_input_bytes) {
    return (
      Some(resource_limit_diagnostic("input_bytes", Some(source_role), None)),
      input,
    )
  }
  let structure = try source_structure_limit(input, source_role, limits) catch {
    // The ordinary parser preflight owns malformed-XML evidence and its exact
    // Source Span. Resource scanning must not replace that Diagnostic.
    _ => None
  } noraise {
    diagnostic => diagnostic
  }
  match structure {
    Some(diagnostic) => return (Some(diagnostic), input)
    None => ()
  }
  let semantic_input = visual_semantic_input(input)
  let embedded_raster = try
    embedded_raster_source_limit(semantic_input, source_role, bundle, limits)
  catch {
    // Malformed XML remains owned by the ordinary parser preflight.
    _ => None
  } noraise {
    diagnostic => diagnostic
  }
  match embedded_raster {
    Some(diagnostic) => return (Some(diagnostic), semantic_input)
    None => ()
  }
  let reference = try
    reference_safety_diagnostic(semantic_input, source_role, limits)
  catch {
    // Malformed XML remains owned by the ordinary parser preflight.
    _ => None
  } noraise {
    diagnostic => diagnostic
  }
  (reference, semantic_input)
}

///|
fn total_region_count(report : StructuredReport) -> Int {
  let mut count = 0
  for event in report.events {
    count += event.difference_regions.length()
  }
  count
}

///|
fn serialized_report_bytes(report : StructuredReport) -> Int {
  let compact = utf8_byte_length(report.to_compact_json_string())
  let indented = utf8_byte_length(report.to_json_string())
  if compact > indented {
    compact
  } else {
    indented
  }
}

///|
fn enforce_output_resource_limits(
  report : StructuredReport,
  limits : ResourceLimits,
) -> StructuredReport {
  if total_region_count(report) > limits.max_regions {
    return failed_resource_report(report.profile, [
      resource_limit_diagnostic("regions", None, None),
    ])
  }
  if serialized_report_bytes(report) > limits.max_report_bytes {
    return failed_resource_report(report.profile, [
      resource_limit_diagnostic("report_bytes", None, None),
    ])
  }
  report
}

///|
fn compare_with_resource_limits_controlled(
  before_svg : String,
  after_svg : String,
  profile : ComparisonProfile,
  limits : ResourceLimits,
  resources : ComparisonResourceBundles,
  comparison_guard : ComparisonGuard,
) -> StructuredReport raise ComparisonInterrupted {
  comparison_guard.checkpoint()
  match raster_limit(profile, limits) {
    Some(diagnostic) => return failed_resource_report(profile, [diagnostic])
    None => ()
  }
  comparison_guard.checkpoint()
  let diagnostics : Array[Diagnostic] = []
  match validate_resource_bundle(resources.before, "before", limits) {
    Some(diagnostic) => diagnostics.push(diagnostic)
    None => ()
  }
  match validate_resource_bundle(resources.after, "after", limits) {
    Some(diagnostic) => diagnostics.push(diagnostic)
    None => ()
  }
  if !diagnostics.is_empty() {
    return failed_resource_report(profile, diagnostics)
  }
  comparison_guard.checkpoint()
  let (before_limit, before_semantic_input) = source_limit(
    before_svg,
    "before",
    resources.before,
    limits,
  )
  match before_limit {
    Some(diagnostic) => diagnostics.push(diagnostic)
    None => ()
  }
  comparison_guard.checkpoint()
  let (after_limit, after_semantic_input) = source_limit(
    after_svg,
    "after",
    resources.after,
    limits,
  )
  match after_limit {
    Some(diagnostic) => diagnostics.push(diagnostic)
    None => ()
  }
  comparison_guard.checkpoint()
  if !diagnostics.is_empty() {
    return failed_resource_report(profile, diagnostics)
  }
  let report = compare_without_resource_limits(
    before_semantic_input, after_semantic_input, profile, limits, resources, comparison_guard,
  )
  comparison_guard.checkpoint()
  let report = enforce_output_resource_limits(report, limits)
  comparison_guard.checkpoint()
  report
}

///|
fn compare_with_resource_limits(
  before_svg : String,
  after_svg : String,
  profile : ComparisonProfile,
  limits : ResourceLimits,
) -> StructuredReport {
  try
    compare_with_resource_limits_controlled(
      before_svg,
      after_svg,
      profile,
      limits,
      ComparisonResourceBundles::empty(),
      ComparisonGuard::new(ComparisonControl::unlimited()),
    )
  catch {
    _ => abort("unlimited comparison was interrupted")
  } noraise {
    report => report
  }
}
