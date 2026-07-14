///|
/// Rendering and normalization conditions recorded for one comparison.
///
/// The root schema `1.5` API accepts caller-provided viewport dimensions and
/// canonicalizes the remaining fields to `v1_default`.
pub(all) struct ComparisonProfile {
  viewport_width : Int
  viewport_height : Int
  comparison_dpr : Double
  color_interpretation : String
  raster_representation : String
  renderer_id : String
  renderer_conformance_profile_id : String
} derive(ToJson)

///|
/// Return the fixed schema `1.5` profile with a `16 x 16` viewport.
///
/// Callers may copy the record with different positive viewport dimensions.
pub fn ComparisonProfile::v1_default() -> ComparisonProfile {
  {
    viewport_width: 16,
    viewport_height: 16,
    comparison_dpr: 1.0,
    color_interpretation: "srgb",
    raster_representation: "linear_srgb_premultiplied_rgba_f64",
    renderer_id: "svgdiff/style-precedence-normalizer@1+mizchi/svg@0.2.1",
    renderer_conformance_profile_id: "svgdiff-renderer-conformance-profile/3",
  }
}

///|
/// Relationship between the supported before and after computed facts.
///
/// `status` is `equivalent`, `different`, `indeterminate`, or
/// `not_applicable`; `reason_code` and Diagnostic references explain why.
pub(all) struct ComputedRelation {
  status : String
  reason_code : String
  missing_side : String?
  diagnostic_ids : Array[String]
} derive(ToJson)

///|
/// Continuous canonical raster measurements for one rendered outcome.
pub(all) struct RenderedMagnitude {
  changed_pixels : Int
  changed_pixel_fraction : Double
  rgba8_rmse : Double
  linear_premultiplied_rgba_rmse : Double
} derive(ToJson)

///|
/// Availability and optional magnitude of canonical rendered evidence.
///
/// A computed zero magnitude is distinct from `not_computed`.
pub(all) struct RenderedEvidence {
  status : String
  reason_code : String?
  magnitude : RenderedMagnitude?
} derive(ToJson)

///|
/// Conservative Changed Fact candidates for one Difference Region.
///
/// A `sound_overapproximation` contains every actual changed cause within
/// complete analysis coverage, but may contain false positives.
pub(all) struct CauseEnvelope {
  guarantee : String
  coverage : String
  fallback_scope : String
  candidate_changed_fact_ids : Array[String]
  diagnostic_ids : Array[String]
} derive(ToJson)

///|
/// Pixel-space and CSS-space localization of one visual outcome component.
pub(all) struct DifferenceRegion {
  id : String
  source : String
  pixel_x : Int
  pixel_y : Int
  pixel_width : Int
  pixel_height : Int
  css_x : Double
  css_y : Double
  css_width : Double
  css_height : Double
  changed_pixels : Int
  viewport_fraction : Double
  cause_envelope : CauseEnvelope
} derive(ToJson)

///|
/// Numeric footprint of inserted or deleted visual subjects.
pub(all) struct PresenceMagnitude {
  affected_entity_count : Int
  bounds_area_css_px2 : Double
  bounds_viewport_fraction : Double
  painted_area_css_px2 : Double
  painted_viewport_fraction : Double
} derive(ToJson)

///|
/// Domain-appropriate magnitude vector for one Atomic Difference.
///
/// Optional components that were not computed serialize as null rather than zero.
pub(all) struct DifferenceMagnitude {
  parameter_abs_user_units : Double?
  parameter_signed_user_units : Double?
  symmetric_relative : Double?
  geometry_displacement_css_px : Double?
  geometry_viewport_fraction : Double?
  presence_painted_viewport_fraction : Double?
  raster_changed_pixel_fraction : Double?
  raster_rgba8_rmse : Double?
  raster_linear_premultiplied_rgba_rmse : Double?
}

///|
fn[T : ToJson] nullable_report_value(value : T?) -> Json {
  match value {
    Some(value) => value.to_json()
    None => Json::null()
  }
}

///|
pub impl ToJson for DifferenceMagnitude with fn to_json(self) {
  {
    "parameter_abs_user_units": nullable_report_value(
      self.parameter_abs_user_units,
    ),
    "parameter_signed_user_units": nullable_report_value(
      self.parameter_signed_user_units,
    ),
    "symmetric_relative": nullable_report_value(self.symmetric_relative),
    "geometry_displacement_css_px": nullable_report_value(
      self.geometry_displacement_css_px,
    ),
    "geometry_viewport_fraction": nullable_report_value(
      self.geometry_viewport_fraction,
    ),
    "presence_painted_viewport_fraction": nullable_report_value(
      self.presence_painted_viewport_fraction,
    ),
    "raster_changed_pixel_fraction": nullable_report_value(
      self.raster_changed_pixel_fraction,
    ),
    "raster_rgba8_rmse": nullable_report_value(self.raster_rgba8_rmse),
    "raster_linear_premultiplied_rgba_rmse": nullable_report_value(
      self.raster_linear_premultiplied_rgba_rmse,
    ),
  }
}

///|
/// Versioned lexicographic components for ordering differences in one domain.
pub(all) struct DomainOrdering {
  policy_id : String
  components : Array[Double]
} derive(ToJson)

///|
fn empty_difference_magnitude() -> DifferenceMagnitude {
  {
    parameter_abs_user_units: None,
    parameter_signed_user_units: None,
    symmetric_relative: None,
    geometry_displacement_css_px: None,
    geometry_viewport_fraction: None,
    presence_painted_viewport_fraction: None,
    raster_changed_pixel_fraction: None,
    raster_rgba8_rmse: None,
    raster_linear_premultiplied_rgba_rmse: None,
  }
}

///|
fn empty_domain_ordering() -> DomainOrdering {
  { policy_id: "v1_domain_lexicographic", components: [] }
}

///|
/// Half-open UTF-16 offsets into the original SVG source.
pub(all) struct ReportSourceSpan {
  start_offset : Int
  end_offset : Int
} derive(ToJson)

///|
/// One source-qualified location establishing a Diagnostic.
pub(all) struct DiagnosticSourceLocation {
  source_role : String
  source_span : ReportSourceSpan
} derive(ToJson)

///|
/// One supported authored visual declaration with exact source provenance.
pub(all) struct DeclaredVisualFact {
  property : String
  authored_value : String
  declared_value : String
  origin : String
  source_span : ReportSourceSpan
} derive(ToJson)

///|
/// One supported visual fact after declaration precedence and inheritance.
pub(all) struct ResolvedVisualFact {
  subject_id : String
  property : String
  resolved_value : String
  resolution : String
  declaration_owner_id : String?
  declaration : DeclaredVisualFact?
  inheritance_depth : Int
} derive(ToJson)

///|
/// Before and after resolved facts for one subject property.
pub(all) struct SourceResolutionPair {
  subject_id : String
  property : String
  before : ResolvedVisualFact?
  after : ResolvedVisualFact?
} derive(ToJson)

///|
/// Report-local reference to one visual subject in an input SVG.
pub(all) struct SubjectReference {
  source_index : Int
  kind : String
  authored_id : String?
}

///|
pub impl ToJson for SubjectReference with fn to_json(self) {
  {
    "source_index": self.source_index,
    "kind": self.kind,
    "authored_id": nullable_report_value(self.authored_id),
  }
}

///|
/// Reviewable selection evidence for one Subject Alignment.
///
/// `confidence` remains null while `confidence_status` is `not_calibrated`;
/// deterministic selection does not imply a calibrated probability.
pub(all) struct AlignmentEvidence {
  score_kind : String
  selected_score : Double?
  candidate_count : Int
  equal_score_candidate_count : Int
  ambiguity : String
  confidence : Double?
  confidence_status : String
}

///|
pub impl ToJson for AlignmentEvidence with fn to_json(self) {
  {
    "score_kind": self.score_kind,
    "selected_score": nullable_report_value(self.selected_score),
    "candidate_count": self.candidate_count,
    "equal_score_candidate_count": self.equal_score_candidate_count,
    "ambiguity": self.ambiguity,
    "confidence": nullable_report_value(self.confidence),
    "confidence_status": self.confidence_status,
  }
}

///|
/// Set-to-set relationship between before and after visual subjects.
pub(all) struct SubjectAlignment {
  id : String
  relation : String
  before : Array[SubjectReference]
  after : Array[SubjectReference]
  basis : String
  evidence : AlignmentEvidence
} derive(ToJson)

///|
/// One changed supported authored fact and the subjects it may affect.
pub(all) struct ChangedFact {
  id : String
  subject_id : String
  property : String
  before : DeclaredVisualFact?
  after : DeclaredVisualFact?
  affected_subject_ids : Array[String]
}

///|
pub impl ToJson for ChangedFact with fn to_json(self) {
  {
    "id": self.id,
    "subject_id": self.subject_id,
    "property": self.property,
    "before": nullable_report_value(self.before),
    "after": nullable_report_value(self.after),
    "affected_subject_ids": self.affected_subject_ids,
  }
}

///|
/// Smallest independently reportable visual-semantic change.
///
/// Domain, evidence layers, computed relation, magnitude, and ordering remain
/// independent so representation and measured visual impact are not conflated.
pub(all) struct AtomicDifference {
  id : String
  subject_role : String
  subject_alignment_id : String?
  domain : String
  source_before : String
  source_after : String
  source_fact_before : DeclaredVisualFact?
  source_fact_after : DeclaredVisualFact?
  changed_fact_ids : Array[String]
  evidence_layers : Array[String]
  computed_relation : ComputedRelation
  parameter_delta_css_px : Double?
  presence_magnitude : PresenceMagnitude?
  magnitude : DifferenceMagnitude
  domain_ordering : DomainOrdering
}

///|
pub impl ToJson for AtomicDifference with fn to_json(self) {
  let fields : Map[String, Json] = Map([])
  fields["id"] = self.id.to_json()
  fields["subject_role"] = self.subject_role.to_json()
  fields["subject_alignment_id"] = nullable_report_value(
    self.subject_alignment_id,
  )
  fields["domain"] = self.domain.to_json()
  fields["source_before"] = self.source_before.to_json()
  fields["source_after"] = self.source_after.to_json()
  match self.source_fact_before {
    Some(value) => fields["source_fact_before"] = value.to_json()
    None => ()
  }
  match self.source_fact_after {
    Some(value) => fields["source_fact_after"] = value.to_json()
    None => ()
  }
  fields["changed_fact_ids"] = self.changed_fact_ids.to_json()
  fields["evidence_layers"] = self.evidence_layers.to_json()
  fields["computed_relation"] = self.computed_relation.to_json()
  match self.parameter_delta_css_px {
    Some(value) => fields["parameter_delta_css_px"] = value.to_json()
    None => ()
  }
  match self.presence_magnitude {
    Some(value) => fields["presence_magnitude"] = value.to_json()
    None => ()
  }
  fields["magnitude"] = self.magnitude.to_json()
  fields["domain_ordering"] = self.domain_ordering.to_json()
  Json::object(fields)
}

///|
/// Agent-facing grouping of Atomic Differences around one subject outcome.
pub(all) struct VisualEvent {
  id : String
  primary_subject_id : String
  atomic_difference_ids : Array[String]
  rendered_outcome : RenderedEvidence
  difference_regions : Array[DifferenceRegion]
} derive(ToJson)

///|
/// Structured coverage limitation or analysis failure.
pub(all) struct Diagnostic {
  id : String
  code : String
  subject_id : String
  affected_evidence_layers : Array[String]
  source_locations : Array[DiagnosticSourceLocation]
} derive(ToJson)

///|
fn diagnostic_location(
  source_role : String,
  span : ReportSourceSpan,
) -> DiagnosticSourceLocation {
  { source_role, source_span: span }
}

///|
fn diagnostic_location_from_xml(
  source_role : String,
  span : @xml.SourceSpan,
) -> DiagnosticSourceLocation {
  diagnostic_location(source_role, {
    start_offset: span.start.offset,
    end_offset: span.end.offset,
  })
}

///|
fn unlocated_diagnostic(
  id : String,
  code : String,
  subject_id : String,
  affected_evidence_layers : Array[String],
) -> Diagnostic {
  { id, code, subject_id, affected_evidence_layers, source_locations: [] }
}

///|
fn located_diagnostic(
  id : String,
  code : String,
  subject_id : String,
  affected_evidence_layers : Array[String],
  source_role : String,
  span : @xml.SourceSpan,
) -> Diagnostic {
  {
    id,
    code,
    subject_id,
    affected_evidence_layers,
    source_locations: [diagnostic_location_from_xml(source_role, span)],
  }
}

///|
fn same_diagnostic_location(
  left : DiagnosticSourceLocation,
  right : DiagnosticSourceLocation,
) -> Bool {
  left.source_role == right.source_role &&
  left.source_span.start_offset == right.source_span.start_offset &&
  left.source_span.end_offset == right.source_span.end_offset
}

///|
fn merge_diagnostic_into(
  diagnostics : Array[Diagnostic],
  diagnostic : Diagnostic,
) -> Unit {
  let mut index = 0
  while index < diagnostics.length() {
    if diagnostics[index].id == diagnostic.id {
      for location in diagnostic.source_locations {
        if !diagnostics[index].source_locations.any(current => {
            same_diagnostic_location(current, location)
          }) {
          diagnostics[index].source_locations.push(location)
        }
      }
      return
    }
    index += 1
  }
  diagnostics.push(diagnostic)
}

///|
fn element_diagnostic_locations(
  input : String,
  source_role : String,
  local_name : String,
) -> Array[DiagnosticSourceLocation] {
  let locations : Array[DiagnosticSourceLocation] = []
  let reader = @xml.NamespaceReader::from_string(input)
  let events = reader.read_events_until_eof() catch { _ => return locations }
  for event in events {
    match event.kind {
      Start(element) | Empty(element) if element.name.local_name == local_name =>
        locations.push(diagnostic_location_from_xml(source_role, event.span))
      _ => ()
    }
  }
  locations
}

///|
fn attach_diagnostic_fact_locations(
  report : StructuredReport,
) -> StructuredReport {
  for diagnostic in report.diagnostics {
    if !diagnostic.source_locations.is_empty() {
      continue
    }
    for difference in report.atomic_differences {
      if !difference.computed_relation.diagnostic_ids.contains(diagnostic.id) {
        continue
      }
      match difference.source_fact_before {
        Some(fact) =>
          merge_diagnostic_into(report.diagnostics, {
            ..diagnostic,
            source_locations: [diagnostic_location("before", fact.source_span)],
          })
        None => ()
      }
      match difference.source_fact_after {
        Some(fact) =>
          merge_diagnostic_into(report.diagnostics, {
            ..diagnostic,
            source_locations: [diagnostic_location("after", fact.source_span)],
          })
        None => ()
      }
    }
  }
  report
}

///|
/// Coverage of one encountered feature at each canonical evidence layer.
///
/// Layer status is `covered`, `limited`, `not_applicable`, or `failed`.
/// Diagnostics explain every limited or failed row.
pub(all) struct FeatureCoverage {
  feature_id : String
  subject_id : String
  source_semantics : String
  computed_appearance : String
  rendered_evidence : String
  diagnostic_ids : Array[String]
} derive(ToJson)

///|
/// One renderer capability gap encountered by the current comparison.
///
/// `support_status` is `guarded` or `unavailable`. Diagnostic references remain
/// the authority for affected subjects and evidence layers.
pub(all) struct RendererCapabilityGap {
  capability_id : String
  support_status : String
  diagnostic_ids : Array[String]
} derive(ToJson)

///|
/// Complete schema `1.5` result of one SVG comparison.
///
/// Read `analysis_status` and `diagnostics` before interpreting an empty
/// `atomic_differences` array as profile-scoped equality.
pub(all) struct StructuredReport {
  schema_version : String
  analysis_status : String
  coverage_matrix : Array[FeatureCoverage]
  renderer_capability_gaps : Array[RendererCapabilityGap]
  profile : ComparisonProfile
  subject_alignments : Array[SubjectAlignment]
  changed_facts : Array[ChangedFact]
  source_resolutions : Array[SourceResolutionPair]
  atomic_differences : Array[AtomicDifference]
  events : Array[VisualEvent]
  diagnostics : Array[Diagnostic]
} derive(ToJson)

///|
/// Serialize this report as indented schema `1.5` JSON.
pub fn StructuredReport::to_json_string(self : StructuredReport) -> String {
  ToJson::to_json(self).stringify(indent=2)
}

///|
/// Serialize this report as whitespace-free schema `1.5` JSON.
///
/// This serialization contains the same fields and evidence as
/// `to_json_string`; it only removes presentation whitespace.
pub fn StructuredReport::to_compact_json_string(
  self : StructuredReport,
) -> String {
  ToJson::to_json(self).stringify()
}

///|
priv enum SourcePreflight {
  SourceCovered
  SourcePartial(Array[Diagnostic])
  SourceFailed(Diagnostic)
}

///|
fn known_source_element(kind : String) -> Bool {
  match kind {
    "svg"
    | "g"
    | "rect"
    | "circle"
    | "ellipse"
    | "line"
    | "polyline"
    | "polygon"
    | "defs"
    | "linearGradient"
    | "stop"
    | "text"
    | "title"
    | "desc"
    | "metadata"
    | "style" => true
    _ => false
  }
}

///|
fn known_source_attribute(kind : String, name : String) -> Bool {
  if name == "id" ||
    name == "style" ||
    name == "transform" ||
    name == "fill" ||
    name == "stroke" ||
    name == "stroke-width" ||
    name == "opacity" {
    return true
  }
  match kind {
    "svg" =>
      name == "width" ||
      name == "height" ||
      name == "viewBox" ||
      name == "preserveAspectRatio" ||
      name == "xmlns"
    "rect" =>
      name == "x" ||
      name == "y" ||
      name == "width" ||
      name == "height" ||
      name == "rx" ||
      name == "ry"
    "circle" => name == "cx" || name == "cy" || name == "r"
    "ellipse" => name == "cx" || name == "cy" || name == "rx" || name == "ry"
    "line" => name == "x1" || name == "y1" || name == "x2" || name == "y2"
    "polyline" | "polygon" => name == "points"
    "linearGradient" =>
      name == "x1" ||
      name == "y1" ||
      name == "x2" ||
      name == "y2" ||
      name == "gradientUnits" ||
      name == "gradientTransform" ||
      name == "href"
    "stop" => name == "offset" || name == "stop-color" || name == "stop-opacity"
    "text" =>
      name == "x" ||
      name == "y" ||
      name == "dx" ||
      name == "dy" ||
      name == "font-family" ||
      name == "font-size" ||
      name == "text-anchor"
    "title" | "desc" | "metadata" => true
    _ => false
  }
}

///|
fn unsupported_paint_value(property : String, value : String) -> Bool {
  if property != "fill" && property != "stroke" {
    return false
  }
  let normalized = value.trim().to_owned().to_lower()
  normalized == "currentcolor" ||
  normalized == "inherit" ||
  normalized == "initial" ||
  normalized == "revert" ||
  normalized == "revert-layer" ||
  normalized == "unset"
}

///|
fn paint_server_reference(value : String) -> String? {
  let normalized = value.trim().to_owned()
  if normalized.has_prefix("url(#") &&
    normalized.has_suffix(")") &&
    normalized.length() > 6 {
    Some(
      normalized
      .view(start_offset=5, end_offset=normalized.length() - 1)
      .to_owned(),
    )
  } else {
    None
  }
}

///|
fn geometry_source_property(kind : String, property : String) -> Bool {
  match kind {
    "rect" =>
      property == "x" ||
      property == "y" ||
      property == "width" ||
      property == "height" ||
      property == "rx" ||
      property == "ry"
    "circle" => property == "cx" || property == "cy" || property == "r"
    "ellipse" =>
      property == "cx" ||
      property == "cy" ||
      property == "rx" ||
      property == "ry"
    "line" =>
      property == "x1" ||
      property == "y1" ||
      property == "x2" ||
      property == "y2"
    "polyline" | "polygon" => property == "points"
    _ => false
  }
}

///|
fn contains_fractional_number(value : String) -> Bool {
  let normalized = value
    .replace_all(old=",", new=" ")
    .replace_all(old="\t", new=" ")
    .replace_all(old="\n", new=" ")
    .replace_all(old="\r", new=" ")
  for token in normalized.split(" ") {
    let token = token.trim()
    if token == "" {
      continue
    }
    match parse_alignment_number(Some(token.to_owned())) {
      Some(number) if number != number.floor() => return true
      _ => ()
    }
  }
  false
}

///|
fn gradient_unsupported_signature_or_raise(input : String) -> String raise {
  let reader = @xml.NamespaceReader::from_string(input)
  let mut signature = ""
  let mut in_gradient = false
  let mut stop_index = 0
  for event in reader.read_events_until_eof() {
    match event.kind {
      Start(element) if element.name.local_name == "linearGradient" => {
        in_gradient = true
        stop_index = 0
        let attributes : Array[String] = []
        for attribute in element.attributes {
          attributes.push(
            "\{attribute.name.local_name}=\{attribute.value.trim()}",
          )
        }
        attributes.sort()
        signature += "gradient"
        for attribute in attributes {
          signature += "[\{attribute}]"
        }
      }
      Start(element) | Empty(element) if in_gradient &&
        element.name.local_name == "stop" => {
        let attributes : Array[String] = []
        for attribute in element.attributes {
          if stop_index > 0 || attribute.name.local_name != "stop-color" {
            attributes.push(
              "\{attribute.name.local_name}=\{attribute.value.trim()}",
            )
          }
        }
        attributes.sort()
        signature += "stop:\{stop_index}"
        for attribute in attributes {
          signature += "[\{attribute}]"
        }
        stop_index += 1
      }
      Start(element) if in_gradient =>
        signature += "child:\{element.name.local_name}"
      End(name) if name.local_name == "linearGradient" => in_gradient = false
      _ => ()
    }
  }
  signature
}

///|
fn identity_view_box(value : String, profile : ComparisonProfile) -> Bool {
  let normalized = value
    .replace_all(old=",", new=" ")
    .replace_all(old="\t", new=" ")
    .replace_all(old="\n", new=" ")
    .replace_all(old="\r", new=" ")
  let numbers : Array[Double] = []
  for token in normalized.split(" ") {
    let token = token.trim()
    if token == "" {
      continue
    }
    match parse_alignment_number(Some(token.to_owned())) {
      Some(number) => numbers.push(number)
      None => return false
    }
  }
  numbers.length() == 4 &&
  numbers[0] == 0.0 &&
  numbers[1] == 0.0 &&
  numbers[2] == profile.viewport_width.to_double() &&
  numbers[3] == profile.viewport_height.to_double()
}

///|
fn preflight_element_subject_id(element : @xml.NamespaceElement) -> String {
  authored_subject_id(element).unwrap_or(element.name.local_name)
}

///|
fn append_transform_preflight_diagnostics(
  diagnostics : Array[Diagnostic],
  element : @xml.NamespaceElement,
  source_role : String,
) -> Unit {
  let subject_id = preflight_element_subject_id(element)
  for attribute in element.attributes {
    let name = attribute.name.local_name
    if name != "transform" &&
      name != "gradientTransform" &&
      name != "patternTransform" {
      continue
    }
    match parse_transform_list(attribute.value) {
      InvalidTransformList => {
        let id = "diagnostic:transform-syntax-unsupported:\{subject_id}:\{name}"
        merge_diagnostic_into(
          diagnostics,
          located_diagnostic(
            id,
            "transform_syntax_unsupported",
            subject_id,
            ["source_semantics", "computed_appearance", "rendered_evidence"],
            source_role,
            attribute.span,
          ),
        )
      }
      ValidTransformList(transform) if name == "transform" &&
        !transform.matrix.has_proven_renderer_conformance() => {
        let id = "diagnostic:renderer-transform-raster-unproven:\{subject_id}"
        merge_diagnostic_into(
          diagnostics,
          located_diagnostic(
            id,
            "renderer_transform_raster_unproven",
            subject_id,
            ["rendered_evidence"],
            source_role,
            attribute.span,
          ),
        )
      }
      _ => ()
    }
    if name == "gradientTransform" || name == "patternTransform" {
      let id = "diagnostic:resource-transform-semantics-unsupported:\{subject_id}:\{name}"
      merge_diagnostic_into(
        diagnostics,
        located_diagnostic(
          id,
          "resource_transform_semantics_unsupported",
          subject_id,
          ["computed_appearance", "rendered_evidence"],
          source_role,
          attribute.span,
        ),
      )
    }
  }
}

///|
fn preflight_source_or_raise(
  input : String,
  profile : ComparisonProfile,
  source_role : String,
) -> Array[Diagnostic] raise {
  let diagnostics : Array[Diagnostic] = []
  let paint_server_ids : Array[String] = []
  let paint_server_references : Array[
    (String, String, String, ReportSourceSpan),
  ] = []
  let reader = @xml.NamespaceReader::from_string(input)
  for event in reader.read_events_until_eof() {
    match event.kind {
      Start(element) | Empty(element) => {
        let kind = element.name.local_name
        append_transform_preflight_diagnostics(
          diagnostics, element, source_role,
        )
        if !known_source_element(kind) {
          let id = "diagnostic:unsupported-visual-subject:\{kind}"
          merge_diagnostic_into(
            diagnostics,
            located_diagnostic(
              id,
              "unsupported_visual_subject",
              kind,
              ["computed_appearance", "rendered_evidence"],
              source_role,
              event.span,
            ),
          )
        } else {
          let presentation_properties : Array[(String, ReportSourceSpan)] = []
          let unsupported_paint_properties : Array[(String, ReportSourceSpan)] = []
          let paint_references : Array[(String, String, ReportSourceSpan)] = []
          let fractional_geometry_properties : Array[(String, ReportSourceSpan)] = []
          let mut style_attribute : @xml.NamespaceAttribute? = None
          let mut subject_id = kind
          let group_opacity_spans : Array[ReportSourceSpan] = []
          let fractional_leaf_opacity_spans : Array[ReportSourceSpan] = []
          let mut view_box_attribute : @xml.NamespaceAttribute? = None
          for attribute in element.attributes {
            let name = attribute.name.local_name
            let attribute_span = {
              start_offset: attribute.span.start.offset,
              end_offset: attribute.span.end.offset,
            }
            if name == "id" && attribute.value.trim() != "" {
              subject_id = attribute.value.trim().to_owned()
            } else if name == "style" {
              style_attribute = Some(attribute)
            } else if supported_rect_property(name) {
              presentation_properties.push((name, attribute_span))
            }
            if unsupported_paint_value(name, attribute.value) {
              unsupported_paint_properties.push((name, attribute_span))
            }
            match paint_server_reference(attribute.value) {
              Some(id) if name == "fill" || name == "stroke" =>
                paint_references.push((name, id, attribute_span))
              _ => ()
            }
            if (kind == "svg" || kind == "g") && name == "opacity" {
              group_opacity_spans.push(attribute_span)
            }
            if geometry_source_property(kind, name) &&
              contains_fractional_number(attribute.value) {
              fractional_geometry_properties.push((name, attribute_span))
            }
            if kind != "svg" &&
              kind != "g" &&
              name == "opacity" &&
              contains_fractional_number(attribute.value) {
              fractional_leaf_opacity_spans.push(attribute_span)
            }
            if kind == "svg" && name == "viewBox" {
              view_box_attribute = Some(attribute)
            }
            if !known_source_attribute(kind, name) {
              let id = "diagnostic:unsupported-visual-attribute:\{kind}:\{name}"
              merge_diagnostic_into(
                diagnostics,
                located_diagnostic(
                  id,
                  "unsupported_visual_attribute",
                  kind,
                  [
                    "source_semantics", "computed_appearance", "rendered_evidence",
                  ],
                  source_role,
                  attribute.span,
                ),
              )
            }
          }
          match view_box_attribute {
            Some(attribute) if !identity_view_box(attribute.value, profile) => {
              let id = "diagnostic:viewport-semantics-unsupported:viewBox"
              merge_diagnostic_into(
                diagnostics,
                located_diagnostic(
                  id,
                  "viewport_semantics_unsupported",
                  "svg",
                  [
                    "source_semantics", "computed_appearance", "rendered_evidence",
                  ],
                  source_role,
                  attribute.span,
                ),
              )
            }
            _ => ()
          }
          if kind == "linearGradient" && subject_id != kind {
            paint_server_ids.push(subject_id)
          }
          for reference in paint_references {
            let (property, id, span) = reference
            paint_server_references.push((subject_id, property, id, span))
          }
          for span in group_opacity_spans {
            merge_diagnostic_into(diagnostics, {
              ..unlocated_diagnostic(
                "diagnostic:group-opacity-compositing-unsupported:\{subject_id}",
                "group_opacity_compositing_unsupported",
                subject_id,
                ["source_semantics", "computed_appearance", "rendered_evidence"],
              ),
              source_locations: [diagnostic_location(source_role, span)],
            })
          }
          for property_and_span in fractional_geometry_properties {
            let (property, span) = property_and_span
            merge_diagnostic_into(diagnostics, {
              ..unlocated_diagnostic(
                "diagnostic:renderer-fractional-geometry-unproven:\{subject_id}:\{property}",
                "renderer_fractional_geometry_unproven",
                subject_id,
                ["rendered_evidence"],
              ),
              source_locations: [diagnostic_location(source_role, span)],
            })
          }
          for span in fractional_leaf_opacity_spans {
            merge_diagnostic_into(diagnostics, {
              ..unlocated_diagnostic(
                "diagnostic:renderer-fractional-opacity-unproven:\{subject_id}",
                "renderer_fractional_opacity_unproven",
                subject_id,
                ["rendered_evidence"],
              ),
              source_locations: [diagnostic_location(source_role, span)],
            })
          }
          for property_and_span in unsupported_paint_properties {
            let (property, span) = property_and_span
            merge_diagnostic_into(diagnostics, {
              ..unlocated_diagnostic(
                "diagnostic:paint-value-semantics-unsupported:\{subject_id}:\{property}",
                "paint_value_semantics_unsupported",
                subject_id,
                ["computed_appearance", "rendered_evidence"],
              ),
              source_locations: [diagnostic_location(source_role, span)],
            })
          }
          match style_attribute {
            Some(attribute) => {
              let style = inline_style_facts(input, attribute)
              for fact in style.facts {
                if (kind == "svg" || kind == "g") && fact.property == "opacity" {
                  let id = "diagnostic:group-opacity-compositing-unsupported:\{subject_id}"
                  merge_diagnostic_into(diagnostics, {
                    ..unlocated_diagnostic(
                      id,
                      "group_opacity_compositing_unsupported",
                      subject_id,
                      [
                        "source_semantics", "computed_appearance", "rendered_evidence",
                      ],
                    ),
                    source_locations: [
                      diagnostic_location(source_role, fact.source_span),
                    ],
                  })
                }
                if geometry_source_property(kind, fact.property) &&
                  contains_fractional_number(fact.declared_value) {
                  let id = "diagnostic:renderer-fractional-geometry-unproven:\{subject_id}:\{fact.property}"
                  merge_diagnostic_into(diagnostics, {
                    ..unlocated_diagnostic(
                      id,
                      "renderer_fractional_geometry_unproven",
                      subject_id,
                      ["rendered_evidence"],
                    ),
                    source_locations: [
                      diagnostic_location(source_role, fact.source_span),
                    ],
                  })
                }
                if kind != "svg" &&
                  kind != "g" &&
                  fact.property == "opacity" &&
                  contains_fractional_number(fact.declared_value) {
                  let id = "diagnostic:renderer-fractional-opacity-unproven:\{subject_id}"
                  merge_diagnostic_into(diagnostics, {
                    ..unlocated_diagnostic(
                      id,
                      "renderer_fractional_opacity_unproven",
                      subject_id,
                      ["rendered_evidence"],
                    ),
                    source_locations: [
                      diagnostic_location(source_role, fact.source_span),
                    ],
                  })
                }
                if unsupported_paint_value(fact.property, fact.declared_value) {
                  let id = "diagnostic:paint-value-semantics-unsupported:\{subject_id}:\{fact.property}"
                  merge_diagnostic_into(diagnostics, {
                    ..unlocated_diagnostic(
                      id,
                      "paint_value_semantics_unsupported",
                      subject_id,
                      ["computed_appearance", "rendered_evidence"],
                    ),
                    source_locations: [
                      diagnostic_location(source_role, fact.source_span),
                    ],
                  })
                }
                match paint_server_reference(fact.declared_value) {
                  Some(id) if fact.property == "fill" ||
                    fact.property == "stroke" =>
                    paint_server_references.push(
                      (subject_id, fact.property, id, fact.source_span),
                    )
                  _ => ()
                }
                for presentation in presentation_properties {
                  let (property, presentation_span) = presentation
                  if !style.complete && property == fact.property {
                    let id = "diagnostic:renderer-style-precedence-unresolved:\{subject_id}:\{fact.property}"
                    merge_diagnostic_into(diagnostics, {
                      ..unlocated_diagnostic(
                        id,
                        "renderer_style_precedence_unresolved",
                        subject_id,
                        ["computed_appearance", "rendered_evidence"],
                      ),
                      source_locations: [
                        diagnostic_location(source_role, presentation_span),
                        diagnostic_location(source_role, fact.source_span),
                      ],
                    })
                  }
                }
              }
            }
            None => ()
          }
        }
      }
      _ => ()
    }
  }
  let visual_subjects = extract_source_subjects_or_raise(input)
  for reference in paint_server_references {
    let (subject_id, property, server_id, span) = reference
    if !paint_server_ids.contains(server_id) {
      let id = "diagnostic:paint-value-semantics-unsupported:\{subject_id}:\{property}"
      merge_diagnostic_into(diagnostics, {
        ..unlocated_diagnostic(
          id,
          "paint_value_semantics_unsupported",
          subject_id,
          ["computed_appearance", "rendered_evidence"],
        ),
        source_locations: [diagnostic_location(source_role, span)],
      })
    } else {
      let proven_gradient_slice = paint_server_ids.length() == 1 &&
        server_id == "gradient" &&
        subject_id == "box" &&
        property == "fill" &&
        visual_subjects.length() == 1 &&
        visual_subjects[0].kind == "rect" &&
        visual_subjects[0].reference.authored_id == Some("box")
      if !proven_gradient_slice {
        let id = "diagnostic:paint-server-analysis-unsupported:\{subject_id}:\{property}"
        merge_diagnostic_into(diagnostics, {
          ..unlocated_diagnostic(
            id,
            "paint_server_analysis_unsupported",
            subject_id,
            ["source_semantics", "computed_appearance", "rendered_evidence"],
          ),
          source_locations: [diagnostic_location(source_role, span)],
        })
      } else {
        let id = "diagnostic:renderer-gradient-raster-unproven:\{subject_id}:\{property}"
        merge_diagnostic_into(diagnostics, {
          ..unlocated_diagnostic(
            id,
            "renderer_gradient_raster_unproven",
            subject_id,
            ["rendered_evidence"],
          ),
          source_locations: [diagnostic_location(source_role, span)],
        })
      }
    }
  }
  diagnostics
}

///|
fn preflight_source(
  input : String,
  profile : ComparisonProfile,
  source_role : String,
) -> SourcePreflight {
  try preflight_source_or_raise(input, profile, source_role) catch {
    @xml.At(error=_, span~) =>
      SourceFailed(
        located_diagnostic(
          "diagnostic:svg-parse-failed:document",
          "svg_parse_failed",
          "document",
          ["source_semantics", "computed_appearance", "rendered_evidence"],
          source_role,
          span,
        ),
      )
    _ =>
      SourceFailed(
        unlocated_diagnostic(
          "diagnostic:svg-parse-failed:document",
          "svg_parse_failed",
          "document",
          ["source_semantics", "computed_appearance", "rendered_evidence"],
        ),
      )
  } noraise {
    diagnostics =>
      if diagnostics.is_empty() {
        SourceCovered
      } else {
        SourcePartial(diagnostics)
      }
  }
}

///|
fn failed_source_report(
  profile : ComparisonProfile,
  diagnostics : Array[Diagnostic],
) -> StructuredReport {
  let diagnostic_id = "diagnostic:svg-parse-failed:document"
  {
    schema_version: "1.5",
    analysis_status: "failed",
    coverage_matrix: [
      {
        feature_id: "document.xml",
        subject_id: "document",
        source_semantics: "failed",
        computed_appearance: "failed",
        rendered_evidence: "failed",
        diagnostic_ids: [diagnostic_id],
      },
    ],
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
fn apply_preflight_diagnostics(
  report : StructuredReport,
  diagnostics : Array[Diagnostic],
) -> StructuredReport {
  if diagnostics.is_empty() {
    return report
  }
  let combined = report.diagnostics.copy()
  for diagnostic in diagnostics {
    merge_diagnostic_into(combined, diagnostic)
  }
  {
    schema_version: report.schema_version,
    analysis_status: if report.analysis_status == "failed" {
      "failed"
    } else {
      "partial"
    },
    coverage_matrix: report.coverage_matrix,
    renderer_capability_gaps: report.renderer_capability_gaps,
    profile: report.profile,
    subject_alignments: report.subject_alignments,
    changed_facts: report.changed_facts,
    source_resolutions: report.source_resolutions,
    atomic_differences: report.atomic_differences,
    events: report.events,
    diagnostics: combined,
  }
}

///|
fn source_slice(input : String, span : @xml.SourceSpan) -> String {
  let view = input.view(
    start_offset=span.start.offset,
    end_offset=span.end.offset,
  )
  "\{view}"
}

///|
fn source_attribute_value_or_raise(
  input : String,
  element_name : String,
  attribute_name : String,
) -> String? raise {
  let reader = @xml.NamespaceReader::from_string(input)
  for event in reader.read_events_until_eof() {
    match event.kind {
      Start(element) | Empty(element) =>
        if element.name.local_name == element_name {
          for attribute in element.attributes {
            if attribute.name.qualified_name == attribute_name ||
              attribute.name.local_name == attribute_name {
              return Some(source_slice(input, attribute.value_span))
            }
          }
          return None
        }
      _ => ()
    }
  }
  None
}

///|
fn source_attribute_value(
  input : String,
  element_name : String,
  attribute_name : String,
) -> String? {
  try
    source_attribute_value_or_raise(input, element_name, attribute_name)
  catch {
    _ => None
  } noraise {
    value => value
  }
}

///|
fn source_text_content_or_raise(input : String) -> String? raise {
  let reader = @xml.NamespaceReader::from_string(input)
  let mut in_text = false
  let mut nested_depth = 0
  let mut text = ""
  for event in reader.read_events_until_eof() {
    match event.kind {
      Start(element) =>
        if in_text {
          nested_depth += 1
        } else if element.name.local_name == "text" {
          in_text = true
        }
      Empty(element) =>
        if !in_text && element.name.local_name == "text" {
          return Some("")
        }
      Text(_) if in_text && nested_depth == 0 =>
        text += source_slice(input, event.span)
      End(_) if in_text && nested_depth == 0 => return Some(text)
      End(_) if in_text => nested_depth -= 1
      _ => ()
    }
  }
  None
}

///|
fn source_text_content(input : String) -> String? {
  try source_text_content_or_raise(input) catch {
    _ => None
  } noraise {
    value => value
  }
}

///|
fn has_subject(document : @svg.SVGDocument, id : String) -> Bool {
  let scene = @svg.Scene::new(document.root)
  scene.find_node(id) is Some(_)
}

///|
fn rect_presence_footprint(
  document : @svg.SVGDocument,
  id : String,
  profile : ComparisonProfile,
) -> PresenceMagnitude? {
  let scene = @svg.Scene::new(document.root)
  match scene.find_node(id) {
    Some(node) =>
      match node.shape {
        Rect(x=_, y=_, width~, height~, rx=_, ry=_) => {
          let bounds_area = width * height
          let viewport_area = profile.viewport_width.to_double() *
            profile.viewport_height.to_double()
          let painted_area = if node.opacity == 0.0 { 0.0 } else { bounds_area }
          Some({
            affected_entity_count: 1,
            bounds_area_css_px2: bounds_area,
            bounds_viewport_fraction: bounds_area / viewport_area,
            painted_area_css_px2: painted_area,
            painted_viewport_fraction: painted_area / viewport_area,
          })
        }
        _ => None
      }
    None => None
  }
}

///|
fn gradient_first_stop(
  document : @svg.SVGDocument,
  id : String,
) -> (Int, Int, Int, Int)? {
  match document.gradients.get(id) {
    Some(Linear(gradient)) if !gradient.stops.is_empty() => {
      let color = gradient.stops[0].color
      Some((color.r, color.g, color.b, color.a))
    }
    _ => None
  }
}

///|
fn to_pixelmatch_image(image : @svg.Image) -> @pixelmatch.Image {
  let pixels : Array[@pixelmatch.Color] = []
  for pixel in image.pixels {
    pixels.push(@pixelmatch.Color::rgba(pixel.r, pixel.g, pixel.b, pixel.a))
  }
  @pixelmatch.Image::from_pixels(image.width, image.height, pixels)
}

///|
fn exact_pixel_options() -> @pixelmatch.Options {
  let defaults = @pixelmatch.Options::default()
  { ..defaults, threshold: 0.0, include_aa: true, detect_shift: false }
}

///|
fn raw_rgba8_squared_error(left : @svg.Color, right : @svg.Color) -> Double {
  let red = (left.r - right.r).to_double() / 255.0
  let green = (left.g - right.g).to_double() / 255.0
  let blue = (left.b - right.b).to_double() / 255.0
  let alpha = (left.a - right.a).to_double() / 255.0
  red * red + green * green + blue * blue + alpha * alpha
}

///|
fn srgb8_to_linear(value : Int) -> Double {
  let channel = value.to_double() / 255.0
  if channel <= 0.04045 {
    channel / 12.92
  } else {
    @math.pow((channel + 0.055) / 1.055, 2.4)
  }
}

///|
fn linear_premultiplied_rgba_squared_error(
  left : @svg.Color,
  right : @svg.Color,
) -> Double {
  let left_alpha = left.a.to_double() / 255.0
  let right_alpha = right.a.to_double() / 255.0
  let red = srgb8_to_linear(left.r) * left_alpha -
    srgb8_to_linear(right.r) * right_alpha
  let green = srgb8_to_linear(left.g) * left_alpha -
    srgb8_to_linear(right.g) * right_alpha
  let blue = srgb8_to_linear(left.b) * left_alpha -
    srgb8_to_linear(right.b) * right_alpha
  let alpha = left_alpha - right_alpha
  red * red + green * green + blue * blue + alpha * alpha
}

///|
fn rendered_difference(
  before : @svg.SVGDocument,
  after : @svg.SVGDocument,
  profile : ComparisonProfile,
) -> RenderedMagnitude {
  let before_image = @svg.render_svg_document_to_image(
    before,
    profile.viewport_width,
    profile.viewport_height,
  )
  let after_image = @svg.render_svg_document_to_image(
    after,
    profile.viewport_width,
    profile.viewport_height,
  )
  let mut squared_error = 0.0
  let mut linear_squared_error = 0.0
  for index in 0..<before_image.pixels.length() {
    let before_pixel = before_image.pixels[index]
    let after_pixel = after_image.pixels[index]
    squared_error += raw_rgba8_squared_error(before_pixel, after_pixel)
    linear_squared_error += linear_premultiplied_rgba_squared_error(
      before_pixel, after_pixel,
    )
  }
  let report = @pixelmatch.diff_report(
    to_pixelmatch_image(before_image),
    to_pixelmatch_image(after_image),
    exact_pixel_options(),
    grid_size=4,
  )
  {
    changed_pixels: report.diff_count,
    changed_pixel_fraction: report.diff_count.to_double() /
    report.total_pixels.to_double(),
    rgba8_rmse: (squared_error / (before_image.pixels.length() * 4).to_double()).sqrt(),
    linear_premultiplied_rgba_rmse: (linear_squared_error /
    (before_image.pixels.length() * 4).to_double()).sqrt(),
  }
}

///|
fn computed_rendered_evidence(
  magnitude : RenderedMagnitude,
) -> RenderedEvidence {
  { status: "computed", reason_code: None, magnitude: Some(magnitude) }
}

///|
fn not_computed_rendered_evidence(reason_code : String) -> RenderedEvidence {
  { status: "not_computed", reason_code: Some(reason_code), magnitude: None }
}

///|
fn deferred_font_report(
  before_svg : String,
  after_svg : String,
  profile : ComparisonProfile,
) -> StructuredReport? {
  match (source_text_content(before_svg), source_text_content(after_svg)) {
    (Some(source_before), Some(source_after)) if source_before != source_after => {
      let diagnostic_id = "diagnostic:font-analysis-deferred:label"
      let difference_id = "diff:entity:label:text"
      Some({
        schema_version: "1.5",
        analysis_status: "partial",
        coverage_matrix: [],
        renderer_capability_gaps: [],
        profile,
        subject_alignments: [],
        changed_facts: [],
        source_resolutions: [],
        atomic_differences: [
          {
            id: difference_id,
            subject_role: "entity",
            subject_alignment_id: None,
            domain: "text.content",
            source_before,
            source_after,
            source_fact_before: None,
            source_fact_after: None,
            changed_fact_ids: [],
            evidence_layers: ["source_semantics"],
            computed_relation: {
              status: "indeterminate",
              reason_code: "font_analysis_deferred",
              missing_side: None,
              diagnostic_ids: [diagnostic_id],
            },
            parameter_delta_css_px: None,
            presence_magnitude: None,
            magnitude: empty_difference_magnitude(),
            domain_ordering: empty_domain_ordering(),
          },
        ],
        events: [
          {
            id: "event:label",
            primary_subject_id: "label",
            atomic_difference_ids: [difference_id],
            rendered_outcome: not_computed_rendered_evidence(
              "font_analysis_deferred",
            ),
            difference_regions: [],
          },
        ],
        diagnostics: [
          {
            id: diagnostic_id,
            code: "font_analysis_deferred",
            subject_id: "label",
            affected_evidence_layers: [
              "computed_appearance", "rendered_evidence",
            ],
            source_locations: element_diagnostic_locations(
              before_svg, "before", "text",
            ) +
            element_diagnostic_locations(after_svg, "after", "text"),
          },
        ],
      })
    }
    _ => None
  }
}

///|
fn presence_change_report(
  before_document : @svg.SVGDocument,
  after_document : @svg.SVGDocument,
  profile : ComparisonProfile,
) -> StructuredReport? {
  let before_footprint = rect_presence_footprint(
    before_document, "box", profile,
  )
  let after_footprint = rect_presence_footprint(after_document, "box", profile)
  match (before_footprint, after_footprint) {
    (None, Some(presence_magnitude)) => {
      let difference_id = "diff:entity:box:presence"
      let rendered = rendered_difference(
        before_document, after_document, profile,
      )
      Some({
        schema_version: "1.5",
        analysis_status: "complete",
        coverage_matrix: [],
        renderer_capability_gaps: [],
        profile,
        subject_alignments: [],
        changed_facts: [],
        source_resolutions: [],
        atomic_differences: [
          {
            id: difference_id,
            subject_role: "entity",
            subject_alignment_id: None,
            domain: "presence.insertion",
            source_before: "",
            source_after: "rect#box",
            source_fact_before: None,
            source_fact_after: None,
            changed_fact_ids: [],
            evidence_layers: ["source_semantics", "computed_appearance"],
            computed_relation: {
              status: "not_applicable",
              reason_code: "before_fact_absent",
              missing_side: Some("before"),
              diagnostic_ids: [],
            },
            parameter_delta_css_px: None,
            presence_magnitude: Some(presence_magnitude),
            magnitude: empty_difference_magnitude(),
            domain_ordering: empty_domain_ordering(),
          },
        ],
        events: [
          {
            id: "event:box",
            primary_subject_id: "box",
            atomic_difference_ids: [difference_id],
            rendered_outcome: computed_rendered_evidence(rendered),
            difference_regions: [],
          },
        ],
        diagnostics: [],
      })
    }
    (Some(presence_magnitude), None) => {
      let difference_id = "diff:entity:box:presence"
      let rendered = rendered_difference(
        before_document, after_document, profile,
      )
      Some({
        schema_version: "1.5",
        analysis_status: "complete",
        coverage_matrix: [],
        renderer_capability_gaps: [],
        profile,
        subject_alignments: [],
        changed_facts: [],
        source_resolutions: [],
        atomic_differences: [
          {
            id: difference_id,
            subject_role: "entity",
            subject_alignment_id: None,
            domain: "presence.deletion",
            source_before: "rect#box",
            source_after: "",
            source_fact_before: None,
            source_fact_after: None,
            changed_fact_ids: [],
            evidence_layers: ["source_semantics", "computed_appearance"],
            computed_relation: {
              status: "not_applicable",
              reason_code: "after_fact_absent",
              missing_side: Some("after"),
              diagnostic_ids: [],
            },
            parameter_delta_css_px: None,
            presence_magnitude: Some(presence_magnitude),
            magnitude: empty_difference_magnitude(),
            domain_ordering: empty_domain_ordering(),
          },
        ],
        events: [
          {
            id: "event:box",
            primary_subject_id: "box",
            atomic_difference_ids: [difference_id],
            rendered_outcome: computed_rendered_evidence(rendered),
            difference_regions: [],
          },
        ],
        diagnostics: [],
      })
    }
    _ => None
  }
}

///|
fn gradient_change_report(
  before_svg : String,
  after_svg : String,
  before_document : @svg.SVGDocument,
  after_document : @svg.SVGDocument,
  profile : ComparisonProfile,
) -> StructuredReport? {
  match
    (
      source_attribute_value(before_svg, "stop", "stop-color"),
      source_attribute_value(after_svg, "stop", "stop-color"),
    ) {
    (Some(source_before), Some(source_after)) if source_before != source_after => {
      let before_stop = gradient_first_stop(before_document, "gradient")
      let after_stop = gradient_first_stop(after_document, "gradient")
      let resource_relation = if before_stop == after_stop {
        {
          status: "equivalent",
          reason_code: "same_resolved_gradient_stop",
          missing_side: None,
          diagnostic_ids: [],
        }
      } else {
        {
          status: "different",
          reason_code: "resolved_gradient_stops_differ",
          missing_side: None,
          diagnostic_ids: [],
        }
      }
      let rendered = rendered_difference(
        before_document, after_document, profile,
      )
      let resource_id = "diff:resource:gradient:stop:0"
      let entity_id = "diff:entity:box:fill"
      let resource_difference : AtomicDifference = {
        id: resource_id,
        subject_role: "resource",
        subject_alignment_id: None,
        domain: "resource.gradient.stop_color",
        source_before,
        source_after,
        source_fact_before: None,
        source_fact_after: None,
        changed_fact_ids: [],
        evidence_layers: ["source_semantics", "computed_appearance"],
        computed_relation: resource_relation,
        parameter_delta_css_px: None,
        presence_magnitude: None,
        magnitude: empty_difference_magnitude(),
        domain_ordering: empty_domain_ordering(),
      }
      if !has_subject(before_document, "box") &&
        !has_subject(after_document, "box") {
        Some({
          schema_version: "1.5",
          analysis_status: "complete",
          coverage_matrix: [],
          renderer_capability_gaps: [],
          profile,
          subject_alignments: [],
          changed_facts: [],
          source_resolutions: [],
          atomic_differences: [resource_difference],
          events: [
            {
              id: "event:gradient",
              primary_subject_id: "gradient",
              atomic_difference_ids: [resource_id],
              rendered_outcome: computed_rendered_evidence(rendered),
              difference_regions: [],
            },
          ],
          diagnostics: [],
        })
      } else {
        Some({
          schema_version: "1.5",
          analysis_status: "complete",
          coverage_matrix: [],
          renderer_capability_gaps: [],
          profile,
          subject_alignments: [],
          changed_facts: [],
          source_resolutions: [],
          atomic_differences: [
            resource_difference,
            {
              id: entity_id,
              subject_role: "entity",
              subject_alignment_id: None,
              domain: "paint.fill",
              source_before: "url(#gradient)",
              source_after: "url(#gradient)",
              source_fact_before: None,
              source_fact_after: None,
              changed_fact_ids: [],
              evidence_layers: ["computed_appearance"],
              computed_relation: {
                status: if before_stop == after_stop {
                  "equivalent"
                } else {
                  "different"
                },
                reason_code: if before_stop == after_stop {
                  "same_resolved_paint"
                } else {
                  "resolved_paints_differ"
                },
                missing_side: None,
                diagnostic_ids: [],
              },
              parameter_delta_css_px: None,
              presence_magnitude: None,
              magnitude: empty_difference_magnitude(),
              domain_ordering: empty_domain_ordering(),
            },
          ],
          events: [
            {
              id: "event:box",
              primary_subject_id: "box",
              atomic_difference_ids: [resource_id, entity_id],
              rendered_outcome: computed_rendered_evidence(rendered),
              difference_regions: [],
            },
          ],
          diagnostics: [],
        })
      }
    }
    _ => None
  }
}

///|
fn compare_without_resource_limits(
  before_svg : String,
  after_svg : String,
  profile : ComparisonProfile,
  limits : ResourceLimits,
  comparison_guard : ComparisonGuard,
) -> StructuredReport raise ComparisonInterrupted {
  comparison_guard.checkpoint()
  let preflight_diagnostics : Array[Diagnostic] = []
  match
    (
      preflight_source(before_svg, profile, "before"),
      preflight_source(after_svg, profile, "after"),
    ) {
    (SourceFailed(before), SourceFailed(after)) => {
      let diagnostics = [before]
      merge_diagnostic_into(diagnostics, after)
      return enforce_coverage_proof(
        failed_source_report(profile, diagnostics),
        before_svg,
        after_svg,
      )
    }
    (SourceFailed(diagnostic), _) | (_, SourceFailed(diagnostic)) =>
      return enforce_coverage_proof(
        failed_source_report(profile, [diagnostic]),
        before_svg,
        after_svg,
      )
    (SourcePartial(before), SourcePartial(after)) => {
      preflight_diagnostics.push_iter(before.iter())
      preflight_diagnostics.push_iter(after.iter())
    }
    (SourcePartial(diagnostics), _) | (_, SourcePartial(diagnostics)) =>
      preflight_diagnostics.push_iter(diagnostics.iter())
    _ => ()
  }
  comparison_guard.checkpoint()
  let before_gradient_signature = gradient_unsupported_signature_or_raise(
    before_svg,
  ) catch {
    _ => ""
  }
  let after_gradient_signature = gradient_unsupported_signature_or_raise(
    after_svg,
  ) catch {
    _ => ""
  }
  comparison_guard.checkpoint()
  if before_gradient_signature != after_gradient_signature {
    merge_diagnostic_into(preflight_diagnostics, {
      id: "diagnostic:gradient-semantics-unsupported:document",
      code: "gradient_semantics_unsupported",
      subject_id: "document",
      affected_evidence_layers: [
        "source_semantics", "computed_appearance", "rendered_evidence",
      ],
      source_locations: element_diagnostic_locations(
        before_svg, "before", "linearGradient",
      ) +
      element_diagnostic_locations(after_svg, "after", "linearGradient"),
    })
  }
  let subject_alignments = subject_alignments_for_sources_with_guard(
    before_svg, after_svg, comparison_guard,
  )
  comparison_guard.checkpoint()
  match inherited_fill_report(before_svg, after_svg, profile) {
    Some(report) =>
      return finish_report(
        report, preflight_diagnostics, subject_alignments, before_svg, after_svg,
        limits, comparison_guard,
      )
    None => ()
  }
  let documents = (
    @svg.parse_svg_document(normalize_renderer_style_precedence(before_svg)),
    @svg.parse_svg_document(normalize_renderer_style_precedence(after_svg)),
  )
  comparison_guard.checkpoint()
  match documents {
    (Some(before_document), Some(after_document)) => {
      match
        generic_basic_shape_report(
          before_svg, after_svg, before_document, after_document, profile, subject_alignments,
        ) {
        Some(report) =>
          return finish_report(
            report, preflight_diagnostics, subject_alignments, before_svg, after_svg,
            limits, comparison_guard,
          )
        None => ()
      }
      match deferred_font_report(before_svg, after_svg, profile) {
        Some(report) =>
          return finish_report(
            report, preflight_diagnostics, subject_alignments, before_svg, after_svg,
            limits, comparison_guard,
          )
        None => ()
      }
      match presence_change_report(before_document, after_document, profile) {
        Some(report) =>
          return finish_report(
            report, preflight_diagnostics, subject_alignments, before_svg, after_svg,
            limits, comparison_guard,
          )
        None => ()
      }
      match
        gradient_change_report(
          before_svg, after_svg, before_document, after_document, profile,
        ) {
        Some(report) =>
          return finish_report(
            report, preflight_diagnostics, subject_alignments, before_svg, after_svg,
            limits, comparison_guard,
          )
        None => ()
      }
      match
        solid_rect_change_report(
          before_svg, after_svg, before_document, after_document, profile,
        ) {
        Some(report) =>
          finish_report(
            report, preflight_diagnostics, subject_alignments, before_svg, after_svg,
            limits, comparison_guard,
          )
        None =>
          finish_report(
            {
              schema_version: "1.5",
              analysis_status: "partial",
              coverage_matrix: [],
              renderer_capability_gaps: [],
              profile,
              subject_alignments: [],
              changed_facts: [],
              source_resolutions: [],
              atomic_differences: [],
              events: [],
              diagnostics: [
                {
                  id: "diagnostic:analysis-coverage-unproven:document",
                  code: "analysis_coverage_unproven",
                  subject_id: "document",
                  affected_evidence_layers: [
                    "source_semantics", "computed_appearance", "rendered_evidence",
                  ],
                  source_locations: [],
                },
              ],
            },
            preflight_diagnostics,
            subject_alignments,
            before_svg,
            after_svg,
            limits,
            comparison_guard,
          )
      }
    }
    _ =>
      failed_source_report(profile, [
        unlocated_diagnostic(
          "diagnostic:svg-parse-failed:document",
          "svg_parse_failed",
          "document",
          ["source_semantics", "computed_appearance", "rendered_evidence"],
        ),
      ])
  }
}

///|
pub fn compare(
  before_svg : String,
  after_svg : String,
  profile : ComparisonProfile,
) -> StructuredReport {
  compare_with_resource_limits(
    before_svg,
    after_svg,
    profile,
    default_resource_limits(),
  )
}

///|
/// Compare with cooperative cancellation and elapsed-time interruption.
pub fn compare_with_control(
  before_svg : String,
  after_svg : String,
  profile : ComparisonProfile,
  control : ComparisonControl,
) -> StructuredReport raise ComparisonInterrupted {
  compare_with_resource_limits_controlled(
    before_svg,
    after_svg,
    profile,
    default_resource_limits(),
    ComparisonGuard::new(control),
  )
}
