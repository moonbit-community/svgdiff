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
  type PresenceMagnitude,
  type RenderedEvidence,
  type RenderedMagnitude,
  type RendererCapabilityGap,
  type ReportSourceSpan,
  type ResolvedVisualFact,
  type SourceResolutionPair,
  type StructuredReport,
  type SubjectAlignment,
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
/// The controlled comparison stopped before a report was established.
pub(all) suberror ComparisonInterrupted {
  Cancelled
  TimeBudgetExceeded(max_elapsed_milliseconds~ : Int)
} derive(Debug, Eq)

///|
/// Compare two deterministic static SVG sources under one schema `1.15` profile.
///
/// The two SVG strings are analyzed under a shared viewport. The root API
/// preserves `profile.viewport_width` and `profile.viewport_height` and pins
/// DPR, color interpretation, raster representation, renderer identity, and
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
  }
  let report = @engine.compare(before_svg, after_svg, canonical_profile)
  { ..report, schema_version: "1.15" }
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
    report => { ..report, schema_version: "1.15" }
  }
}
