///|
pub using @engine {
  type AtomicDifference,
  type CauseEnvelope,
  type ChangedFact,
  type ComparisonProfile,
  type ComputedRelation,
  type DeclaredVisualFact,
  type Diagnostic,
  type DifferenceMagnitude,
  type DifferenceRegion,
  type DomainOrdering,
  type PresenceMagnitude,
  type RenderedEvidence,
  type RenderedMagnitude,
  type ReportSourceSpan,
  type ResolvedVisualFact,
  type SourceResolutionPair,
  type StructuredReport,
  type SubjectAlignment,
  type SubjectReference,
  type VisualEvent,
}

///|
/// Compare two deterministic static SVG sources under one declared profile.
/// Unsupported semantics reduce `analysis_status` and produce diagnostics.
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
  { ..report, schema_version: "1.0" }
}
