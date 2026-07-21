///|
pub using @model {
  type AlignmentEvidence,
  type AtomicDifference,
  type CauseEnvelope,
  type ChangedFact,
  type ComparisonProfile,
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
  type ReportSourceSpan,
  type ResolvedVisualFact,
  type SourceResolutionPair,
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
pub using @source {
  type SourceAuditDiagnostic,
  type SourceAuditDifference,
  type SourceAuditFact,
  type SourceAuditReport,
}

///|
pub(all) struct ResourceBundleEntry {
  locator : String
  media_type : String
  bytes : Bytes
}

///|
pub(all) struct ResourceBundle {
  entries : Array[ResourceBundleEntry]
}

///|
pub fn ResourceBundle::empty() -> ResourceBundle {
  { entries: [] }
}

///|
pub(all) struct ComparisonControl {
  should_cancel : () -> Bool
  max_checkpoints : Int?
}

///|
pub fn ComparisonControl::unlimited() -> ComparisonControl {
  let should_cancel : () -> Bool = () => false
  { should_cancel, max_checkpoints: None }
}

///|
pub(all) suberror ComparisonInterrupted {
  Cancelled
  CheckpointBudgetExceeded(max_checkpoints~ : Int)
} derive(Debug, Eq)
