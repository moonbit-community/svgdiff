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
  let report = @engine.compare_with_resources(
    before_svg, after_svg, profile, before_resources, after_resources,
  )
  { ..report, schema_version: "5.0" }
}

///|
/// The controlled comparison stopped before a report was established.
pub(all) suberror ComparisonInterrupted {
  Cancelled
  CheckpointBudgetExceeded(max_checkpoints~ : Int)
} derive(Debug, Eq)

///|
pub(all) struct ComparisonArtifact {
  report : StructuredReport
  difference_rgba : Bytes?
}

///|
/// Compare two deterministic static SVG sources under one profile.
///
/// The two SVG strings are analyzed under a shared viewport. The root API
/// preserves `profile.viewport_width`, `profile.viewport_height`, the optional
/// Perceptual Background, optional FLIP Viewing Conditions, and optional FLIP
/// error threshold. Unsupported semantics produce Diagnostics and reduce
/// `analysis_status` instead of being treated as equality.
///
/// Inspect `analysis_status` before using an empty `atomic_differences` array as
/// a profile-scoped equality conclusion.
pub fn compare(
  before_svg : String,
  after_svg : String,
  profile : ComparisonProfile,
) -> StructuredReport {
  let report = @engine.compare(before_svg, after_svg, profile)
  { ..report, schema_version: "5.0" }
}

///|
/// Compare with cooperative cancellation and a deterministic checkpoint budget.
///
/// Interruption raises `ComparisonInterrupted` and returns no report. Checks
/// occur at deterministic engine checkpoints; one dependency call cannot be
/// preempted and may complete before the next checkpoint is observed.
pub fn compare_with_control(
  before_svg : String,
  after_svg : String,
  profile : ComparisonProfile,
  control : ComparisonControl,
) -> StructuredReport raise ComparisonInterrupted {
  try
    @engine.compare_with_control(before_svg, after_svg, profile, control)
  catch {
    Cancelled => raise Cancelled
    CheckpointBudgetExceeded(max_checkpoints~) =>
      raise CheckpointBudgetExceeded(max_checkpoints~)
  } noraise {
    report => { ..report, schema_version: "5.0" }
  }
}

///|
/// Compare explicit resources with cooperative cancellation and checkpoint work.
pub fn compare_with_control_and_resources(
  before_svg : String,
  after_svg : String,
  profile : ComparisonProfile,
  before_resources : ResourceBundle,
  after_resources : ResourceBundle,
  control : ComparisonControl,
) -> StructuredReport raise ComparisonInterrupted {
  try
    @engine.compare_with_control_and_resources(
      before_svg, after_svg, profile, before_resources, after_resources, control,
    )
  catch {
    Cancelled => raise Cancelled
    CheckpointBudgetExceeded(max_checkpoints~) =>
      raise CheckpointBudgetExceeded(max_checkpoints~)
  } noraise {
    report => { ..report, schema_version: "5.0" }
  }
}

///|
/// Compare explicit resources and return the canonical raster difference used
/// by rendered measurements together with the Structured Report.
pub fn compare_artifact_with_control_and_resources(
  before_svg : String,
  after_svg : String,
  profile : ComparisonProfile,
  before_resources : ResourceBundle,
  after_resources : ResourceBundle,
  control : ComparisonControl,
) -> ComparisonArtifact raise ComparisonInterrupted {
  try
    @engine.compare_artifact_with_control_and_resources(
      before_svg, after_svg, profile, before_resources, after_resources, control,
    )
  catch {
    Cancelled => raise Cancelled
    CheckpointBudgetExceeded(max_checkpoints~) =>
      raise CheckpointBudgetExceeded(max_checkpoints~)
  } noraise {
    artifact =>
      {
        report: { ..artifact.report, schema_version: "5.0" },
        difference_rgba: artifact.difference_rgba,
      }
  }
}

///|
pub extend ComparisonInterrupted with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend ComparisonInterrupted with Eq::{not_equal, equal}
