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
/// Displayed-color magnitude for one selected rendered outcome after explicit
/// background compositing.
pub(all) struct PerceptualColorMagnitude {
  method_id : String
  sample_count : Int
  mean_delta_e_ok : Double
} derive(ToJson, Eq)

///|
/// Availability and optional event-local perceptual-color magnitude.
pub(all) struct PerceptualColorEvidence {
  status : String
  reason_code : String?
  magnitude : PerceptualColorMagnitude?
} derive(ToJson, Eq)

///|
/// Deterministic quantized LDR-FLIP map for one selected rendered outcome.
pub(all) struct PerceptualFlipMap {
  method_id : String
  pixel_x : Int
  pixel_y : Int
  pixel_width : Int
  pixel_height : Int
  encoding : String
  quantization_step : Double
  values_base64 : String
} derive(ToJson, Eq)

///|
/// Explicit-threshold spatial extent for one event-local LDR-FLIP response.
pub(all) struct PerceptualFlipAreaAboveThreshold {
  threshold : Double
  pixel_count : Int
  canvas_fraction : Double
} derive(ToJson, Eq)

///|
/// Separate pooled domains over one unquantized LDR-FLIP map.
pub(all) struct PerceptualFlipStatistics {
  method_id : String
  canvas_pixel_count : Int
  event_region_sample_count : Int
  response_sample_count : Int
  canvas_mean : Double
  event_region_mean : Double
  response_p95 : Double
  response_maximum : Double
  area_above_threshold : PerceptualFlipAreaAboveThreshold?
} derive(Eq)

///|
pub impl ToJson for PerceptualFlipStatistics with fn to_json(self) {
  let fields : Map[String, Json] = Map([])
  fields["method_id"] = self.method_id.to_json()
  fields["canvas_pixel_count"] = self.canvas_pixel_count.to_json()
  fields["event_region_sample_count"] = self.event_region_sample_count.to_json()
  fields["response_sample_count"] = self.response_sample_count.to_json()
  fields["canvas_mean"] = self.canvas_mean.to_json()
  fields["event_region_mean"] = self.event_region_mean.to_json()
  fields["response_p95"] = self.response_p95.to_json()
  fields["response_maximum"] = self.response_maximum.to_json()
  fields["area_above_threshold"] = nullable_report_value(
    self.area_above_threshold,
  )
  Json::object(fields)
}

///|
/// Availability and optional event-local LDR-FLIP map.
pub(all) struct PerceptualFlipEvidence {
  status : String
  reason_code : String?
  map : PerceptualFlipMap?
  statistics : PerceptualFlipStatistics?
} derive(ToJson, Eq)

///|
/// Availability and optional magnitude of canonical rendered evidence.
///
/// A computed zero magnitude is distinct from `not_computed`.
pub(all) struct RenderedEvidence {
  status : String
  reason_code : String?
  magnitude : RenderedMagnitude?
  perceptual_color : PerceptualColorEvidence
  perceptual_flip : PerceptualFlipEvidence
} derive(ToJson)

///|
/// Availability and comparison-wide LDR-FLIP mean.
pub(all) struct CanvasPerceptualFlipEvidence {
  status : String
  reason_code : String?
  method_id : String?
  canvas_mean : Double?
} derive(ToJson)

///|
/// Measurements computed once from the final before and after canvases.
pub(all) struct CanvasOutcome {
  status : String
  reason_code : String?
  magnitude : RenderedMagnitude?
  perceptual_flip : CanvasPerceptualFlipEvidence
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
/// Symmetric nearest-boundary statistics from the pinned renderer's alpha support.
pub(all) struct PaintedBoundaryDisplacementMagnitude {
  method_id : String
  before_sample_count : Int
  after_sample_count : Int
  mean_css_px : Double
  p95_css_px : Double
  max_css_px : Double
} derive(ToJson, Eq)

///|
/// Symmetric alpha-only isolated painted-coverage comparison.
pub(all) struct PaintedCoverageDifferenceMagnitude {
  method_id : String
  before_coverage_css_px2 : Double
  after_coverage_css_px2 : Double
  absolute_difference_css_px2 : Double
  union_coverage_css_px2 : Double
  fraction : Double
} derive(ToJson, Eq)

///|
/// Domain-appropriate magnitude vector for one Atomic Difference.
///
/// Optional components that were not computed serialize as null rather than zero.
pub(all) struct DifferenceMagnitude {
  parameter_abs_user_units : Double?
  parameter_signed_user_units : Double?
  symmetric_relative : Double?
  parameter_abs_css_px : Double?
  parameter_viewport_fraction : Double?
  parameter_entity_fraction : Double?
  geometry_displacement_css_px : Double?
  painted_boundary_displacement : PaintedBoundaryDisplacementMagnitude?
  painted_coverage_difference : PaintedCoverageDifferenceMagnitude?
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
  fields["parameter_abs_css_px"] = nullable_report_value(
    self.parameter_abs_css_px,
  )
  fields["parameter_viewport_fraction"] = nullable_report_value(
    self.parameter_viewport_fraction,
  )
  fields["parameter_entity_fraction"] = nullable_report_value(
    self.parameter_entity_fraction,
  )
  fields["geometry_displacement_css_px"] = nullable_report_value(
    self.geometry_displacement_css_px,
  )
  fields["painted_boundary_displacement"] = nullable_report_value(
    self.painted_boundary_displacement,
  )
  fields["painted_coverage_difference"] = nullable_report_value(
    self.painted_coverage_difference,
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
    parameter_abs_css_px: None,
    parameter_viewport_fraction: None,
    parameter_entity_fraction: None,
    geometry_displacement_css_px: None,
    painted_boundary_displacement: None,
    painted_coverage_difference: None,
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
  subject_role : String
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
/// Common whole-canvas event measurements used by one Impact Assessment.
pub(all) struct ImpactMeasurement {
  changed_pixel_fraction : Double
  linear_premultiplied_rgba_rmse : Double
} derive(ToJson, Eq)

///|
/// One singleton or exact measured-tie group on the main-event frontier.
pub(all) struct ImpactFrontierGroup {
  event_ids : Array[String]
  atomic_difference_ids : Array[String]
  measurements : ImpactMeasurement?
} derive(Eq)

///|
pub impl ToJson for ImpactFrontierGroup with fn to_json(self) {
  let fields : Map[String, Json] = Map([])
  fields["event_ids"] = self.event_ids.to_json()
  fields["atomic_difference_ids"] = self.atomic_difference_ids.to_json()
  fields["measurements"] = nullable_report_value(self.measurements)
  Json::object(fields)
}

///|
/// One deterministic explanation for excluding a dominated event.
pub(all) struct ImpactDominationWitness {
  dominant_event_id : String
  dominated_event_id : String
  rule_id : String
} derive(ToJson, Eq)

///|
/// Additive versioned main-event assessment that preserves partial ordering.
pub(all) struct ImpactAssessment {
  policy_id : String
  status : String
  calibration_status : String
  input_fields : Array[String]
  candidate_event_count : Int
  frontier_relation : String
  frontier_groups : Array[ImpactFrontierGroup]
  domination_witnesses : Array[ImpactDominationWitness]
} derive(ToJson, Eq)

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
/// Complete schema `1.45` result of one SVG comparison.
///
/// Read `analysis_status` and `diagnostics` before interpreting an empty
/// `atomic_differences` array as profile-scoped equality.
pub(all) struct StructuredReport {
  schema_version : String
  analysis_status : String
  canvas_outcome : CanvasOutcome
  impact_assessment : ImpactAssessment
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
/// Serialize this report as indented schema `1.45` JSON.
pub fn StructuredReport::to_json_string(self : StructuredReport) -> String {
  ToJson::to_json(self).stringify(indent=2)
}

///|
/// Serialize this report as whitespace-free schema `1.45` JSON.
///
/// This serialization contains the same fields and evidence as
/// `to_json_string`; it only removes presentation whitespace.
pub fn StructuredReport::to_compact_json_string(
  self : StructuredReport,
) -> String {
  ToJson::to_json(self).stringify()
}
