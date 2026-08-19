// Copyright 2026 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

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
pub(all) struct ComparisonArtifact {
  report : StructuredReport
  difference_rgba : Bytes?
}

///|
pub(all) suberror ComparisonInterrupted {
  Cancelled
  CheckpointBudgetExceeded(max_checkpoints~ : Int)
} derive(Debug, Eq)
