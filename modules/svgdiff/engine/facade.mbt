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
fn diff_bundle(bundle : ResourceBundle) -> @resource_model.ResourceBundle {
  let entries : Array[@resource_model.ResourceBundleEntry] = []
  for entry in bundle.entries {
    entries.push({
      locator: entry.locator,
      media_type: entry.media_type,
      bytes: entry.bytes,
    })
  }
  { entries, }
}

///|
fn diff_control(control : ComparisonControl) -> @control.ComparisonControl {
  {
    should_cancel: control.should_cancel,
    max_checkpoints: control.max_checkpoints,
  }
}

///|
pub fn audit_nonvisual_metadata(
  before_svg : String,
  after_svg : String,
) -> @source.SourceAuditReport {
  @source.audit_nonvisual_metadata(before_svg, after_svg)
}

///|
pub fn compare(
  before_svg : String,
  after_svg : String,
  profile : @model.ComparisonProfile,
) -> @model.StructuredReport {
  @diff.compare(before_svg, after_svg, profile)
}

///|
pub fn compare_with_resources(
  before_svg : String,
  after_svg : String,
  profile : @model.ComparisonProfile,
  before_resources : ResourceBundle,
  after_resources : ResourceBundle,
) -> @model.StructuredReport {
  @diff.compare_with_resources(
    before_svg,
    after_svg,
    profile,
    diff_bundle(before_resources),
    diff_bundle(after_resources),
  )
}

///|
pub fn compare_with_control(
  before_svg : String,
  after_svg : String,
  profile : @model.ComparisonProfile,
  control : ComparisonControl,
) -> @model.StructuredReport raise ComparisonInterrupted {
  @diff.compare_with_control(
    before_svg,
    after_svg,
    profile,
    diff_control(control),
  ) catch {
    Cancelled => raise Cancelled
    CheckpointBudgetExceeded(max_checkpoints~) =>
      raise CheckpointBudgetExceeded(max_checkpoints~)
  }
}

///|
pub fn compare_with_control_and_resources(
  before_svg : String,
  after_svg : String,
  profile : @model.ComparisonProfile,
  before_resources : ResourceBundle,
  after_resources : ResourceBundle,
  control : ComparisonControl,
) -> @model.StructuredReport raise ComparisonInterrupted {
  @diff.compare_with_control_and_resources(
    before_svg,
    after_svg,
    profile,
    diff_bundle(before_resources),
    diff_bundle(after_resources),
    diff_control(control),
  ) catch {
    Cancelled => raise Cancelled
    CheckpointBudgetExceeded(max_checkpoints~) =>
      raise CheckpointBudgetExceeded(max_checkpoints~)
  }
}

///|
pub fn compare_artifact_with_control_and_resources(
  before_svg : String,
  after_svg : String,
  profile : @model.ComparisonProfile,
  before_resources : ResourceBundle,
  after_resources : ResourceBundle,
  control : ComparisonControl,
) -> ComparisonArtifact raise ComparisonInterrupted {
  let artifact = @diff.compare_artifact_with_control_and_resources(
    before_svg,
    after_svg,
    profile,
    diff_bundle(before_resources),
    diff_bundle(after_resources),
    diff_control(control),
  ) catch {
    Cancelled => raise Cancelled
    CheckpointBudgetExceeded(max_checkpoints~) =>
      raise CheckpointBudgetExceeded(max_checkpoints~)
  }
  { report: artifact.report, difference_rgba: artifact.difference_rgba }
}
