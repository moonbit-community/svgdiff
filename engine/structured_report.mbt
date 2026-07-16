///|
/// Rendering and normalization conditions recorded for one comparison.
///
/// The root schema `1.32` API accepts caller-provided viewport dimensions and
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
/// Return the fixed schema `1.32` profile with a `16 x 16` viewport.
///
/// Callers may copy the record with different positive viewport dimensions.
pub fn ComparisonProfile::v1_default() -> ComparisonProfile {
  {
    viewport_width: 16,
    viewport_height: 16,
    comparison_dpr: 1.0,
    color_interpretation: "srgb",
    raster_representation: "linear_srgb_premultiplied_rgba_f64",
    renderer_id: "svgdiff/style-precedence-normalizer@3+ordinary-inheritance-normalizer@1+css-computed-value-normalizer@3+css-color3-opacity-normalizer@1+length-used-value-normalizer@1+stroke-used-geometry-normalizer@1+basic-shape-used-geometry-normalizer@1+isolated-group-compositor@1+static-mask-normalizer@1+static-mask-compositor@1+static-filter-graph-compositor@1+static-blend-compositor@1+mizchi/svg@0.2.1",
    renderer_conformance_profile_id: "svgdiff-renderer-conformance-profile/25",
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
/// Intrinsic decoded-raster comparison, independent of final SVG compositing.
pub(all) struct IntrinsicRasterMagnitude {
  before_width : Int
  before_height : Int
  after_width : Int
  after_height : Int
  compared_pixels : Int?
  changed_pixels : Int?
  changed_pixel_fraction : Double?
  rgba8_rmse : Double?
  linear_premultiplied_rgba_rmse : Double?
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
/// Viewport-space translation change and its Euclidean CSS-pixel magnitude.
pub(all) struct TransformTranslationMagnitude {
  before_x_css_px : Double
  before_y_css_px : Double
  after_x_css_px : Double
  after_y_css_px : Double
  delta_x_css_px : Double
  delta_y_css_px : Double
  norm_css_px : Double
} derive(ToJson)

///|
/// Canonical paired rotation values and shortest signed angular change.
pub(all) struct TransformRotationMagnitude {
  before_degrees : Double
  after_degrees : Double
  signed_delta_degrees : Double
  abs_delta_degrees : Double
} derive(ToJson)

///|
/// Canonical signed axis scales and their largest absolute paired delta.
pub(all) struct TransformScaleMagnitude {
  before_x : Double
  before_y : Double
  after_x : Double
  after_y : Double
  max_abs_delta : Double
} derive(ToJson)

///|
/// Canonical paired X-skew values and shortest signed angular change.
pub(all) struct TransformSkewMagnitude {
  before_degrees : Double
  after_degrees : Double
  signed_delta_degrees : Double
  abs_delta_degrees : Double
} derive(ToJson)

///|
/// Exact singular linear transforms retained without a coefficient score.
pub(all) struct TransformResidualMagnitude {
  before_matrix : Array[Double]
  after_matrix : Array[Double]
  before_determinant : Double
  after_determinant : Double
} derive(ToJson)

///|
/// Tagged raw magnitude for one canonical transform-effect domain.
pub(all) enum TransformEffectMagnitude {
  TranslationEffect(TransformTranslationMagnitude)
  RotationEffect(TransformRotationMagnitude)
  ScaleEffect(TransformScaleMagnitude)
  SkewEffect(TransformSkewMagnitude)
  ResidualMatrixEffect(TransformResidualMagnitude)
}

///|
pub impl ToJson for TransformEffectMagnitude with fn to_json(self) {
  match self {
    TranslationEffect(value) =>
      {
        "kind": "translation",
        "before_x_css_px": value.before_x_css_px,
        "before_y_css_px": value.before_y_css_px,
        "after_x_css_px": value.after_x_css_px,
        "after_y_css_px": value.after_y_css_px,
        "delta_x_css_px": value.delta_x_css_px,
        "delta_y_css_px": value.delta_y_css_px,
        "norm_css_px": value.norm_css_px,
      }
    RotationEffect(value) =>
      {
        "kind": "rotation",
        "before_degrees": value.before_degrees,
        "after_degrees": value.after_degrees,
        "signed_delta_degrees": value.signed_delta_degrees,
        "abs_delta_degrees": value.abs_delta_degrees,
      }
    ScaleEffect(value) =>
      {
        "kind": "scale",
        "before_x": value.before_x,
        "before_y": value.before_y,
        "after_x": value.after_x,
        "after_y": value.after_y,
        "max_abs_delta": value.max_abs_delta,
      }
    SkewEffect(value) =>
      {
        "kind": "skew",
        "before_degrees": value.before_degrees,
        "after_degrees": value.after_degrees,
        "signed_delta_degrees": value.signed_delta_degrees,
        "abs_delta_degrees": value.abs_delta_degrees,
      }
    ResidualMatrixEffect(value) =>
      {
        "kind": "residual_matrix",
        "before_matrix": value.before_matrix,
        "after_matrix": value.after_matrix,
        "before_determinant": value.before_determinant,
        "after_determinant": value.after_determinant,
      }
  }
}

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
  intrinsic_raster : IntrinsicRasterMagnitude?
  transform_effect : TransformEffectMagnitude?
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
  let fields : Map[String, Json] = Map([])
  fields["parameter_abs_user_units"] = nullable_report_value(
    self.parameter_abs_user_units,
  )
  fields["parameter_signed_user_units"] = nullable_report_value(
    self.parameter_signed_user_units,
  )
  fields["symmetric_relative"] = nullable_report_value(self.symmetric_relative)
  fields["geometry_displacement_css_px"] = nullable_report_value(
    self.geometry_displacement_css_px,
  )
  fields["geometry_viewport_fraction"] = nullable_report_value(
    self.geometry_viewport_fraction,
  )
  fields["presence_painted_viewport_fraction"] = nullable_report_value(
    self.presence_painted_viewport_fraction,
  )
  fields["raster_changed_pixel_fraction"] = nullable_report_value(
    self.raster_changed_pixel_fraction,
  )
  fields["raster_rgba8_rmse"] = nullable_report_value(self.raster_rgba8_rmse)
  fields["raster_linear_premultiplied_rgba_rmse"] = nullable_report_value(
    self.raster_linear_premultiplied_rgba_rmse,
  )
  fields["intrinsic_raster"] = nullable_report_value(self.intrinsic_raster)
  match self.transform_effect {
    Some(value) => fields["transform_effect"] = value.to_json()
    None => ()
  }
  Json::object(fields)
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
    intrinsic_raster: None,
    transform_effect: None,
  }
}

///|
fn empty_domain_ordering() -> DomainOrdering {
  { policy_id: "v2_domain_lexicographic", components: [] }
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
/// Placement identity for a subject rendered through one or more `use` hosts.
///
/// The corresponding authored definition keeps its own identity and Source
/// Spans; `instance_id` identifies only this rendered outcome.
pub(all) struct SubjectInstanceContext {
  instance_id : String
  definition_subject_id : String
  use_path : Array[String]
} derive(ToJson)

///|
/// Report-local reference to one visual subject in an input SVG.
pub(all) struct SubjectReference {
  source_index : Int
  kind : String
  authored_id : String?
  instance_context : SubjectInstanceContext?
}

///|
pub impl ToJson for SubjectReference with fn to_json(self) {
  {
    "source_index": self.source_index,
    "kind": self.kind,
    "authored_id": nullable_report_value(self.authored_id),
    "instance_context": nullable_report_value(self.instance_context),
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
/// Complete schema `1.32` result of one SVG comparison.
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
/// Serialize this report as indented schema `1.32` JSON.
pub fn StructuredReport::to_json_string(self : StructuredReport) -> String {
  ToJson::to_json(self).stringify(indent=2)
}

///|
/// Serialize this report as whitespace-free schema `1.32` JSON.
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
    | "symbol"
    | "use"
    | "linearGradient"
    | "radialGradient"
    | "pattern"
    | "clipPath"
    | "mask"
    | "filter"
    | "feOffset"
    | "marker"
    | "image"
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
fn group_opacity_container(kind : String) -> Bool {
  kind == "svg" || kind == "g" || kind == "symbol" || kind == "use"
}

///|
fn known_source_attribute(kind : String, name : String) -> Bool {
  if name == "id" ||
    name == "class" ||
    name.has_prefix("data-") ||
    name.has_prefix("aria-") ||
    name == "style" ||
    name == "transform" ||
    name == "color" ||
    name == "color-interpolation" ||
    name == "fill" ||
    name == "fill-opacity" ||
    name == "fill-rule" ||
    name == "stroke" ||
    name == "stroke-opacity" ||
    name == "stroke-width" ||
    name == "stroke-linecap" ||
    name == "stroke-linejoin" ||
    name == "stroke-miterlimit" ||
    name == "stroke-dasharray" ||
    name == "stroke-dashoffset" ||
    name == "vector-effect" ||
    name == "marker" ||
    name == "marker-start" ||
    name == "marker-mid" ||
    name == "marker-end" ||
    name == "paint-order" ||
    name == "clip-rule" ||
    name == "clip-path" ||
    name == "filter" ||
    name == "mask" ||
    name == "mask-mode" ||
    name == "mask-type" ||
    name == "mask-image" ||
    name == "mask-position" ||
    name == "mask-size" ||
    name == "mask-repeat" ||
    name == "mask-origin" ||
    name == "mask-clip" ||
    name == "mask-composite" ||
    name.has_prefix("mask-border") ||
    name == "opacity" {
    return true
  }
  match kind {
    "svg" =>
      name == "x" ||
      name == "y" ||
      name == "width" ||
      name == "height" ||
      name == "viewBox" ||
      name == "preserveAspectRatio" ||
      name == "xmlns"
    "symbol" =>
      name == "x" ||
      name == "y" ||
      name == "width" ||
      name == "height" ||
      name == "viewBox" ||
      name == "preserveAspectRatio"
    "use" =>
      name == "x" ||
      name == "y" ||
      name == "width" ||
      name == "height" ||
      name == "href"
    "image" =>
      name == "x" ||
      name == "y" ||
      name == "width" ||
      name == "height" ||
      name == "href" ||
      name == "preserveAspectRatio"
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
      name == "spreadMethod" ||
      name == "href"
    "radialGradient" =>
      name == "cx" ||
      name == "cy" ||
      name == "r" ||
      name == "fx" ||
      name == "fy" ||
      name == "fr" ||
      name == "gradientUnits" ||
      name == "gradientTransform" ||
      name == "spreadMethod" ||
      name == "href"
    "pattern" =>
      name == "x" ||
      name == "y" ||
      name == "width" ||
      name == "height" ||
      name == "patternUnits" ||
      name == "patternContentUnits" ||
      name == "patternTransform" ||
      name == "viewBox" ||
      name == "preserveAspectRatio" ||
      name == "href" ||
      name == "overflow"
    "clipPath" => name == "clipPathUnits"
    "mask" =>
      name == "maskUnits" ||
      name == "maskContentUnits" ||
      name == "x" ||
      name == "y" ||
      name == "width" ||
      name == "height"
    "filter" =>
      name == "filterUnits" ||
      name == "primitiveUnits" ||
      name == "x" ||
      name == "y" ||
      name == "width" ||
      name == "height" ||
      name == "href"
    "feOffset" =>
      name == "in" ||
      name == "result" ||
      name == "dx" ||
      name == "dy" ||
      name == "x" ||
      name == "y" ||
      name == "width" ||
      name == "height"
    "marker" =>
      name == "markerUnits" ||
      name == "markerWidth" ||
      name == "markerHeight" ||
      name == "refX" ||
      name == "refY" ||
      name == "orient" ||
      name == "viewBox" ||
      name == "preserveAspectRatio" ||
      name == "overflow"
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
fn unsupported_visual_value_code(property : String, value : String) -> String? {
  let trimmed = value.trim().to_owned()
  let normalized = trimmed.to_lower()
  if css_wide_keyword(normalized) || normalized.find("var(") is Some(_) {
    return None
  }
  if property.has_prefix("mask-border") {
    return Some("mask_border_unsupported")
  }
  if property == "mask-image" {
    return Some("mask_image_unsupported")
  }
  if property == "mask-position" ||
    property == "mask-size" ||
    property == "mask-repeat" ||
    property == "mask-origin" ||
    property == "mask-clip" ||
    property == "mask-composite" {
    return Some("mask_layer_subproperty_unsupported")
  }
  if property == "mask" {
    if normalized.find("gradient(") is Some(_) ||
      normalized.has_prefix("image(") ||
      normalized.has_prefix("image-set(") ||
      normalized.has_prefix("cross-fade(") {
      return Some("mask_image_unsupported")
    }
    if normalized.find(",") is Some(_) {
      return Some("mask_multiple_layers_unsupported")
    }
    return match parse_mask_reference(trimmed) {
      MaskNone | MaskLocal(_) => None
      MaskExternal => Some("mask_external_reference_unsupported")
      MaskInvalid => Some("mask_reference_invalid")
    }
  }
  if property == "mask-mode" {
    return if normalized == "match-source" ||
      normalized == "alpha" ||
      normalized == "luminance" {
      None
    } else {
      Some("mask_mode_invalid")
    }
  }
  if property == "mask-type" {
    return if normalized == "alpha" || normalized == "luminance" {
      None
    } else {
      Some("mask_type_invalid")
    }
  }
  if property == "opacity" ||
    property == "fill-opacity" ||
    property == "stroke-opacity" ||
    property == "stop-opacity" {
    return if @css_color.parse_alpha_value(normalized) is Some(_) {
      None
    } else {
      Some("opacity_syntax_unsupported")
    }
  }
  if property == "paint-order" ||
    property == "fill-rule" ||
    property == "clip-rule" {
    return if paint_rule_value_valid(property, normalized) {
      None
    } else {
      Some(paint_rule_issue_code(property))
    }
  }
  if property != "color" &&
    property != "fill" &&
    property != "stroke" &&
    property != "stop-color" {
    return None
  }
  if property == "fill" || property == "stroke" {
    match parse_paint_value(trimmed) {
      NoPaint | LocalPaintServer(_, _) => return None
      ExternalPaintServer | ContextPaint =>
        return Some("paint_value_semantics_unsupported")
      InvalidPaint if ascii_url_start(trimmed, 0) =>
        return Some("paint_value_semantics_unsupported")
      SolidPaint(_) | InvalidPaint => ()
    }
  }
  match @css_color.parse_solid_color(normalized) {
    Resolved(_) | CurrentColor => None
    SystemColor(_) => Some("system_color_environment_unsupported")
    Invalid =>
      if normalized.has_prefix("lab(") ||
        normalized.has_prefix("lch(") ||
        normalized.has_prefix("oklab(") ||
        normalized.has_prefix("oklch(") ||
        normalized.has_prefix("color(") ||
        normalized.has_prefix("hwb(") {
        Some("color_profile_unsupported")
      } else {
        Some("solid_color_syntax_unsupported")
      }
  }
}

///|
fn geometry_source_property(kind : String, property : String) -> Bool {
  basic_shape_geometry_property(kind, property)
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
fn contains_fractional_paint_alpha(property : String, value : String) -> Bool {
  if property == "opacity" ||
    property == "fill-opacity" ||
    property == "stroke-opacity" ||
    property == "stop-opacity" {
    match @css_color.parse_alpha_value(value) {
      Some(alpha) => return alpha > 0.0 && alpha < 1.0
      None => return false
    }
  }
  if property == "color" ||
    property == "fill" ||
    property == "stroke" ||
    property == "stop-color" {
    match @css_color.parse_solid_color(value) {
      Resolved(color) => return color.alpha > 0.0 && color.alpha < 1.0
      _ => return false
    }
  }
  false
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
  }
}

///|
fn object_bbox_clip_child_offsets(
  input : String,
  profile : ComparisonProfile,
) -> Array[Int] {
  let document = extract_clip_semantic_document_or_raise(input, profile) catch {
    _ => return []
  }
  let offsets : Array[Int] = []
  for resource in document.resources {
    if resource.complete &&
      resource.units == "objectBoundingBox" &&
      resource.rect_source_offset is Some(offset) {
      offsets.push(offset)
    }
  }
  let masks = extract_mask_semantic_document_or_raise(input, profile) catch {
    _ => return offsets
  }
  for resource in masks.resources {
    if resource.complete &&
      resource.content_units == "objectBoundingBox" &&
      resource.rect_source_offset is Some(offset) {
      offsets.push(offset)
    }
  }
  offsets
}

///|
fn admitted_mask_content_offsets(
  input : String,
  profile : ComparisonProfile,
) -> Array[Int] {
  let document = extract_mask_semantic_document_or_raise(input, profile) catch {
    _ => return []
  }
  let offsets : Array[Int] = []
  for resource in document.resources {
    if resource.complete && resource.rect_source_offset is Some(offset) {
      offsets.push(offset)
    }
  }
  offsets
}

///|
fn preflight_source_or_raise(
  input : String,
  profile : ComparisonProfile,
  source_role : String,
  bundle : ResourceBundle,
  limits : ResourceLimits,
) -> Array[Diagnostic] raise {
  let diagnostics : Array[Diagnostic] = []
  for
    diagnostic in embedded_image_preflight_diagnostics(
      input, profile, source_role, bundle, limits,
    ) {
    merge_diagnostic_into(diagnostics, diagnostic)
  }
  let css_document = parse_static_css_document_or_raise(input)
  if !css_document.complete {
    merge_diagnostic_into(
      diagnostics,
      unlocated_diagnostic(
        "diagnostic:css-cascade-unsupported:document",
        "css_cascade_unsupported",
        "document",
        ["source_semantics", "computed_appearance", "rendered_evidence"],
      ),
    )
  }
  let gradient_ids : Array[String] = []
  let pattern_ids : Array[String] = []
  let paint_server_references : Array[
    (String, String, String, ReportSourceSpan),
  ] = []
  let object_bbox_clip_offsets = object_bbox_clip_child_offsets(input, profile)
  let mask_content_offsets = admitted_mask_content_offsets(input, profile)
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
          let unsupported_visual_values : Array[
            (String, String, ReportSourceSpan),
          ] = []
          let paint_references : Array[(String, String, ReportSourceSpan)] = []
          let fractional_geometry_properties : Array[(String, ReportSourceSpan)] = []
          let mut style_attribute : @xml.NamespaceAttribute? = None
          let mut subject_id = kind
          let fractional_leaf_opacity_spans : Array[ReportSourceSpan] = []
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
            } else if supported_presentation_property(name) {
              presentation_properties.push((name, attribute_span))
            }
            match unsupported_visual_value_code(name, attribute.value) {
              Some(code) =>
                unsupported_visual_values.push((name, code, attribute_span))
              None => ()
            }
            match paint_server_reference(attribute.value) {
              Some(id) if name == "fill" || name == "stroke" =>
                paint_references.push((name, id, attribute_span))
              _ => ()
            }
            if geometry_source_property(kind, name) &&
              contains_fractional_number(attribute.value) &&
              !object_bbox_clip_offsets.contains(event.span.start.offset) {
              fractional_geometry_properties.push((name, attribute_span))
            }
            if !(name == "opacity" && group_opacity_container(kind)) &&
              !mask_content_offsets.contains(event.span.start.offset) &&
              contains_fractional_paint_alpha(name, attribute.value) {
              fractional_leaf_opacity_spans.push(attribute_span)
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
          if (kind == "linearGradient" || kind == "radialGradient") &&
            subject_id != kind {
            gradient_ids.push(subject_id)
          }
          if kind == "pattern" && subject_id != kind {
            pattern_ids.push(subject_id)
          }
          for reference in paint_references {
            let (property, id, span) = reference
            paint_server_references.push((subject_id, property, id, span))
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
          for entry in unsupported_visual_values {
            let (property, code, span) = entry
            merge_diagnostic_into(diagnostics, {
              ..unlocated_diagnostic(
                "diagnostic:\{code}:\{subject_id}:\{property}",
                code,
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
                if geometry_source_property(kind, fact.property) &&
                  contains_fractional_number(fact.declared_value) &&
                  !object_bbox_clip_offsets.contains(event.span.start.offset) {
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
                if !(fact.property == "opacity" && group_opacity_container(kind)) &&
                  !mask_content_offsets.contains(event.span.start.offset) &&
                  contains_fractional_paint_alpha(
                    fact.property,
                    fact.declared_value,
                  ) {
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
                match
                  unsupported_visual_value_code(
                    fact.property,
                    fact.declared_value,
                  ) {
                  Some(code) => {
                    let id = "diagnostic:\{code}:\{subject_id}:\{fact.property}"
                    merge_diagnostic_into(diagnostics, {
                      ..unlocated_diagnostic(id, code, subject_id, [
                        "computed_appearance", "rendered_evidence",
                      ]),
                      source_locations: [
                        diagnostic_location(source_role, fact.source_span),
                      ],
                    })
                  }
                  None => ()
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
          let stylesheet_match = css_stylesheet_match_for_source(
            css_document,
            event.span.start.offset,
          )
          for candidate in stylesheet_match.candidates {
            let fact = candidate.declaration
            if geometry_source_property(kind, fact.property) &&
              contains_fractional_number(fact.declared_value) &&
              !object_bbox_clip_offsets.contains(event.span.start.offset) {
              merge_diagnostic_into(diagnostics, {
                ..unlocated_diagnostic(
                  "diagnostic:renderer-fractional-geometry-unproven:{subject_id}:{fact.property}",
                  "renderer_fractional_geometry_unproven",
                  subject_id,
                  ["rendered_evidence"],
                ),
                source_locations: [
                  diagnostic_location(source_role, fact.source_span),
                ],
              })
            }
            if !(fact.property == "opacity" && group_opacity_container(kind)) &&
              !mask_content_offsets.contains(event.span.start.offset) &&
              contains_fractional_paint_alpha(
                fact.property,
                fact.declared_value,
              ) {
              merge_diagnostic_into(diagnostics, {
                ..unlocated_diagnostic(
                  "diagnostic:renderer-fractional-opacity-unproven:{subject_id}",
                  "renderer_fractional_opacity_unproven",
                  subject_id,
                  ["rendered_evidence"],
                ),
                source_locations: [
                  diagnostic_location(source_role, fact.source_span),
                ],
              })
            }
            match
              unsupported_visual_value_code(fact.property, fact.declared_value) {
              Some(code) =>
                merge_diagnostic_into(diagnostics, {
                  ..unlocated_diagnostic(
                    "diagnostic:{code}:{subject_id}:{fact.property}",
                    code,
                    subject_id,
                    ["computed_appearance", "rendered_evidence"],
                  ),
                  source_locations: [
                    diagnostic_location(source_role, fact.source_span),
                  ],
                })
              None => ()
            }
            match paint_server_reference(fact.declared_value) {
              Some(id) if fact.property == "fill" || fact.property == "stroke" =>
                paint_server_references.push(
                  (subject_id, fact.property, id, fact.source_span),
                )
              _ => ()
            }
          }
        }
      }
      _ => ()
    }
  }
  append_viewport_preflight_diagnostics(
    input, profile, source_role, diagnostics,
  )
  append_use_structure_diagnostics(input, profile, source_role, diagnostics)
  append_marker_resource_diagnostics(input, profile, source_role, diagnostics)
  let visual_subjects = extract_source_subjects_with_profile_or_raise(
    input, profile,
  )
  append_basic_shape_geometry_diagnostics(
    visual_subjects, source_role, diagnostics,
  )
  append_stroke_geometry_diagnostics(visual_subjects, source_role, diagnostics)
  append_marker_geometry_diagnostics(visual_subjects, source_role, diagnostics)
  append_clip_path_diagnostics(input, profile, source_role, diagnostics)
  append_mask_diagnostics(input, profile, source_role, diagnostics)
  append_filter_diagnostics(input, profile, source_role, diagnostics)
  append_blend_diagnostics(input, profile, source_role, diagnostics)
  append_basic_shape_renderer_diagnostics(
    visual_subjects, source_role, diagnostics,
  )
  append_stroke_renderer_diagnostics(visual_subjects, source_role, diagnostics)
  for reference in paint_server_references {
    let (subject_id, property, server_id, span) = reference
    if gradient_ids.contains(server_id) {
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
    } else if pattern_ids.contains(server_id) {
      let id = "diagnostic:renderer-pattern-raster-unproven:\{subject_id}:\{property}"
      merge_diagnostic_into(diagnostics, {
        ..unlocated_diagnostic(
          id,
          "renderer_pattern_raster_unproven",
          subject_id,
          ["rendered_evidence"],
        ),
        source_locations: [diagnostic_location(source_role, span)],
      })
    }
  }
  diagnostics
}

///|
fn preflight_source(
  input : String,
  profile : ComparisonProfile,
  source_role : String,
  bundle : ResourceBundle,
  limits : ResourceLimits,
) -> SourcePreflight {
  try
    preflight_source_or_raise(input, profile, source_role, bundle, limits)
  catch {
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
    schema_version: "1.32",
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
  let before_image = render_product_document_to_image(
    before,
    profile.viewport_width,
    profile.viewport_height,
  )
  let after_image = render_product_document_to_image(
    after,
    profile.viewport_width,
    profile.viewport_height,
  )
  rendered_image_difference(before_image, after_image)
}

///|
fn rendered_image_difference(
  before_image : @svg.Image,
  after_image : @svg.Image,
) -> RenderedMagnitude {
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
        schema_version: "1.32",
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
        schema_version: "1.32",
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
        schema_version: "1.32",
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
fn compare_without_resource_limits(
  before_svg : String,
  after_svg : String,
  profile : ComparisonProfile,
  limits : ResourceLimits,
  resources : ComparisonResourceBundles,
  comparison_guard : ComparisonGuard,
) -> StructuredReport raise ComparisonInterrupted {
  comparison_guard.checkpoint()
  let preflight_diagnostics : Array[Diagnostic] = []
  match
    (
      preflight_source(before_svg, profile, "before", resources.before, limits),
      preflight_source(after_svg, profile, "after", resources.after, limits),
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
  let subject_alignments = subject_alignments_for_sources_with_guard(
    before_svg, after_svg, comparison_guard,
  )
  subject_alignments.push_iter(
    embedded_image_alignments_for_sources(
      before_svg,
      after_svg,
      profile,
      resources.before,
      resources.after,
      limits,
    ).iter(),
  )
  let rendered_subject_alignments = [
    for alignment in subject_alignments if !source_structural_alignment_basis(
      alignment.basis,
    ) => alignment
  ]
  comparison_guard.checkpoint()
  match inherited_fill_report(before_svg, after_svg, profile) {
    Some(report) =>
      return finish_report(
        report, preflight_diagnostics, subject_alignments, before_svg, after_svg,
        limits, resources, comparison_guard,
      )
    None => ()
  }
  let documents = (
    @svg.parse_svg_document(
      normalize_renderer_input_with_profile(before_svg, profile),
    ),
    @svg.parse_svg_document(
      normalize_renderer_input_with_profile(after_svg, profile),
    ),
  )
  comparison_guard.checkpoint()
  match documents {
    (Some(before_document), Some(after_document)) => {
      let no_rendered_subjects = try
        extract_source_subjects_with_profile_or_raise(before_svg, profile).is_empty() &&
        extract_source_subjects_with_profile_or_raise(after_svg, profile).is_empty()
      catch {
        _ => false
      }
      if no_rendered_subjects &&
        preflight_diagnostics.is_empty() &&
        (empty_rendered_scene_supported(before_svg) catch { _ => false }) &&
        (empty_rendered_scene_supported(after_svg) catch { _ => false }) {
        return finish_report(
          {
            schema_version: "1.32",
            analysis_status: "complete",
            coverage_matrix: [],
            renderer_capability_gaps: [],
            profile,
            subject_alignments: [],
            changed_facts: [],
            source_resolutions: [],
            atomic_differences: [],
            events: [],
            diagnostics: [],
          },
          preflight_diagnostics,
          subject_alignments,
          before_svg,
          after_svg,
          limits,
          resources,
          comparison_guard,
        )
      }
      let has_embedded_image_alignment = subject_alignments.any(alignment => {
        alignment.id.has_prefix("alignment:image:")
      })
      let before_is_embedded_image_scene = (embedded_image_only_scene(
          before_svg,
        ) catch {
          _ => false
        }) ||
        (empty_rendered_scene_supported(before_svg) catch { _ => false })
      let after_is_embedded_image_scene = (embedded_image_only_scene(after_svg) catch {
          _ => false
        }) ||
        (empty_rendered_scene_supported(after_svg) catch { _ => false })
      if no_rendered_subjects &&
        has_embedded_image_alignment &&
        before_is_embedded_image_scene &&
        after_is_embedded_image_scene {
        return finish_report(
          {
            schema_version: "1.32",
            analysis_status: "partial",
            coverage_matrix: [],
            renderer_capability_gaps: [],
            profile,
            subject_alignments: [],
            changed_facts: [],
            source_resolutions: [],
            atomic_differences: [],
            events: [],
            diagnostics: [],
          },
          preflight_diagnostics,
          subject_alignments,
          before_svg,
          after_svg,
          limits,
          resources,
          comparison_guard,
        )
      }
      match
        generic_basic_shape_report(
          before_svg, after_svg, before_document, after_document, profile, rendered_subject_alignments,
        ) {
        Some(report) =>
          return finish_report(
            report, preflight_diagnostics, subject_alignments, before_svg, after_svg,
            limits, resources, comparison_guard,
          )
        None => ()
      }
      match deferred_font_report(before_svg, after_svg, profile) {
        Some(report) =>
          return finish_report(
            report, preflight_diagnostics, subject_alignments, before_svg, after_svg,
            limits, resources, comparison_guard,
          )
        None => ()
      }
      match presence_change_report(before_document, after_document, profile) {
        Some(report) =>
          return finish_report(
            report, preflight_diagnostics, subject_alignments, before_svg, after_svg,
            limits, resources, comparison_guard,
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
            limits, resources, comparison_guard,
          )
        None =>
          finish_report(
            {
              schema_version: "1.32",
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
            resources,
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
/// Compare with separate caller-supplied resource bundles for both sources.
pub fn compare_with_resources(
  before_svg : String,
  after_svg : String,
  profile : ComparisonProfile,
  before_resources : ResourceBundle,
  after_resources : ResourceBundle,
) -> StructuredReport {
  try
    compare_with_resource_limits_controlled(
      before_svg,
      after_svg,
      profile,
      default_resource_limits(),
      { before: before_resources, after: after_resources },
      ComparisonGuard::new(ComparisonControl::unlimited()),
    )
  catch {
    _ => abort("unlimited comparison was interrupted")
  } noraise {
    report => report
  }
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
    ComparisonResourceBundles::empty(),
    ComparisonGuard::new(control),
  )
}

///|
/// Compare explicit resources with cooperative interruption controls.
pub fn compare_with_control_and_resources(
  before_svg : String,
  after_svg : String,
  profile : ComparisonProfile,
  before_resources : ResourceBundle,
  after_resources : ResourceBundle,
  control : ComparisonControl,
) -> StructuredReport raise ComparisonInterrupted {
  compare_with_resource_limits_controlled(
    before_svg,
    after_svg,
    profile,
    default_resource_limits(),
    { before: before_resources, after: after_resources },
    ComparisonGuard::new(control),
  )
}
