///|
pub using @engine {
  type AlignmentEvidence,
  type AtomicDifference,
  type CauseEnvelope,
  type ChangedFact,
  type ComparisonProfile,
  type ComparisonControl,
  type ComputedRelation,
  type DeclaredVisualFact,
  type Diagnostic,
  type DiagnosticSourceLocation,
  type DifferenceMagnitude,
  type DifferenceRegion,
  type DomainOrdering,
  type FeatureCoverage,
  type FlipErrorThreshold,
  type FlipViewingConditions,
  type IntrinsicRasterMagnitude,
  type ImpactAssessment,
  type ImpactDominationWitness,
  type ImpactFrontierGroup,
  type ImpactMeasurement,
  type PaintedBoundaryDisplacementMagnitude,
  type PaintedCoverageDifferenceMagnitude,
  type PerceptualBackground,
  type PerceptualColorEvidence,
  type PerceptualColorMagnitude,
  type PerceptualFlipEvidence,
  type PerceptualFlipAreaAboveThreshold,
  type PerceptualFlipMap,
  type PerceptualFlipStatistics,
  type PresenceMagnitude,
  type RenderedEvidence,
  type RenderedMagnitude,
  type RendererCapabilityGap,
  type ResourceBundle,
  type ResourceBundleEntry,
  type ReportSourceSpan,
  type ResolvedVisualFact,
  type SourceResolutionPair,
  type SourceAuditDiagnostic,
  type SourceAuditDifference,
  type SourceAuditFact,
  type SourceAuditReport,
  type StructuredReport,
  type SubjectAlignment,
  type SubjectInstanceContext,
  type SubjectReference,
  type TransformEffectMagnitude,
  type TransformResidualMagnitude,
  type TransformRotationMagnitude,
  type TransformScaleMagnitude,
  type TransformSkewMagnitude,
  type TransformTranslationMagnitude,
  type VisualEvent,
}

///|
/// Audit nonvisual metadata without adding it to visual Atomic Differences.
///
/// This independent source-only operation inventories exact authored content
/// inside SVG `title`, `desc`, and `metadata` elements plus unprefixed
/// `aria-*` and `data-*` attributes. It never changes comparison results.
pub fn audit_nonvisual_metadata(
  before_svg : String,
  after_svg : String,
) -> SourceAuditReport {
  @engine.audit_nonvisual_metadata(before_svg, after_svg)
}

///|
/// Compare with separate explicit resource bundles for the two SVG sources.
///
/// Bundle locators are opaque exact-match keys. The engine performs no file or
/// network I/O and resolves only caller-supplied PNG/JPEG bytes.
pub fn compare_with_resources(
  before_svg : String,
  after_svg : String,
  profile : ComparisonProfile,
  before_resources : ResourceBundle,
  after_resources : ResourceBundle,
) -> StructuredReport {
  let canonical_profile = {
    ..ComparisonProfile::v1_default(),
    viewport_width: profile.viewport_width,
    viewport_height: profile.viewport_height,
    perceptual_background: profile.perceptual_background,
    flip_viewing_conditions: profile.flip_viewing_conditions,
    flip_error_threshold: profile.flip_error_threshold,
  }
  let report = @engine.compare_with_resources(
    before_svg, after_svg, canonical_profile, before_resources, after_resources,
  )
  { ..report, schema_version: "1.43" }
}

///|
/// The controlled comparison stopped before a report was established.
pub(all) suberror ComparisonInterrupted {
  Cancelled
  TimeBudgetExceeded(max_elapsed_milliseconds~ : Int)
} derive(Debug, Eq)

///|
/// Compare two deterministic static SVG sources under one schema `1.43` profile.
///
/// The two SVG strings are analyzed under a shared viewport. The root API
/// preserves `profile.viewport_width`, `profile.viewport_height`, the optional
/// Perceptual Background, optional FLIP Viewing Conditions, and optional FLIP
/// error threshold, and pins DPR,
/// color interpretation, raster representation, renderer identity, and
/// renderer conformance profile to the v1 defaults. Unsupported semantics
/// produce Diagnostics and reduce `analysis_status` instead of being treated
/// as equality.
///
/// Inspect `analysis_status` before using an empty `atomic_differences` array as
/// a profile-scoped equality conclusion.
pub fn compare(
  before_svg : String,
  after_svg : String,
  profile : ComparisonProfile,
) -> StructuredReport {
  let canonical_profile = {
    ..ComparisonProfile::v1_default(),
    viewport_width: profile.viewport_width,
    viewport_height: profile.viewport_height,
    perceptual_background: profile.perceptual_background,
    flip_viewing_conditions: profile.flip_viewing_conditions,
    flip_error_threshold: profile.flip_error_threshold,
  }
  let report = @engine.compare(before_svg, after_svg, canonical_profile)
  { ..report, schema_version: "1.43" }
}

///|
/// Compare with cooperative cancellation and an optional elapsed-time budget.
///
/// Interruption raises `ComparisonInterrupted` and returns no report. Checks
/// occur at deterministic engine checkpoints; one dependency parse or render
/// call cannot be preempted and may complete before expiry is observed.
pub fn compare_with_control(
  before_svg : String,
  after_svg : String,
  profile : ComparisonProfile,
  control : ComparisonControl,
) -> StructuredReport raise ComparisonInterrupted {
  let canonical_profile = {
    ..ComparisonProfile::v1_default(),
    viewport_width: profile.viewport_width,
    viewport_height: profile.viewport_height,
    perceptual_background: profile.perceptual_background,
    flip_viewing_conditions: profile.flip_viewing_conditions,
    flip_error_threshold: profile.flip_error_threshold,
  }
  try
    @engine.compare_with_control(
      before_svg, after_svg, canonical_profile, control,
    )
  catch {
    Cancelled => raise Cancelled
    TimeBudgetExceeded(max_elapsed_milliseconds~) =>
      raise TimeBudgetExceeded(max_elapsed_milliseconds~)
  } noraise {
    report => { ..report, schema_version: "1.43" }
  }
}

///|
/// Compare explicit resources with cooperative cancellation and elapsed time.
pub fn compare_with_control_and_resources(
  before_svg : String,
  after_svg : String,
  profile : ComparisonProfile,
  before_resources : ResourceBundle,
  after_resources : ResourceBundle,
  control : ComparisonControl,
) -> StructuredReport raise ComparisonInterrupted {
  let canonical_profile = {
    ..ComparisonProfile::v1_default(),
    viewport_width: profile.viewport_width,
    viewport_height: profile.viewport_height,
    perceptual_background: profile.perceptual_background,
    flip_viewing_conditions: profile.flip_viewing_conditions,
    flip_error_threshold: profile.flip_error_threshold,
  }
  try
    @engine.compare_with_control_and_resources(
      before_svg, after_svg, canonical_profile, before_resources, after_resources,
      control,
    )
  catch {
    Cancelled => raise Cancelled
    TimeBudgetExceeded(max_elapsed_milliseconds~) =>
      raise TimeBudgetExceeded(max_elapsed_milliseconds~)
  } noraise {
    report => { ..report, schema_version: "1.43" }
  }
}
