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
fn subject_alignments_for_sources_with_guard(
  before_svg : String,
  after_svg : String,
  profile : ComparisonProfile,
  comparison_guard : ComparisonGuard,
) -> Array[SubjectAlignment] raise ComparisonInterrupted {
  let inventories = try
    Some(
      (
        extract_source_subjects_or_raise(before_svg, profile~),
        extract_source_subjects_or_raise(after_svg, profile~),
        structural_alignment_subjects(
          extract_structural_document_or_raise(before_svg),
        ),
        structural_alignment_subjects(
          extract_structural_document_or_raise(after_svg),
        ),
      ),
    )
  catch {
    _ => None
  } noraise {
    value => value
  }
  match inventories {
    Some((before, after, before_structural, after_structural)) => {
      let alignments = align_source_subjects_with_guard(
        before, after, profile, comparison_guard,
      )
      alignments.push_iter(
        align_structural_subjects_with_guard(
          before_structural,
          after_structural,
          alignments.length(),
          comparison_guard,
        ).iter(),
      )
      alignments
    }
    None => []
  }
}

///|
fn attach_subject_alignments(
  report : StructuredReport,
  alignments : Array[SubjectAlignment],
) -> StructuredReport {
  let differences : Array[AtomicDifference] = []
  for difference in report.atomic_differences {
    let mut alignment_id = difference.subject_alignment_id
    if alignment_id is None && difference.subject_role == "entity" {
      let mut report_subject_id : String? = None
      for event in report.events {
        if event.atomic_difference_ids.contains(difference.id) {
          report_subject_id = Some(event.primary_subject_id)
          break
        }
      }
      match report_subject_id {
        Some(subject_id) =>
          for alignment in alignments {
            let matches_before = alignment.before.any(reference => {
              reference.authored_id == Some(subject_id) ||
              "\{reference.kind}:\{reference.source_index}" == subject_id
            })
            let matches_after = alignment.after.any(reference => {
              reference.authored_id == Some(subject_id) ||
              "\{reference.kind}:\{reference.source_index}" == subject_id
            })
            if matches_before || matches_after {
              alignment_id = Some(alignment.id)
              break
            }
          }
        None => ()
      }
    }
    differences.push({ ..difference, subject_alignment_id: alignment_id })
  }
  {
    schema_version: report.schema_version,
    analysis_status: report.analysis_status,
    canvas_outcome: report.canvas_outcome,
    impact_assessment: report.impact_assessment,
    coverage_matrix: report.coverage_matrix,
    renderer_capability_gaps: report.renderer_capability_gaps,
    visual_scene: report.visual_scene,
    profile: report.profile,
    subject_alignments: alignments,
    changed_facts: report.changed_facts,
    source_resolutions: report.source_resolutions,
    atomic_differences: differences,
    events: report.events,
    diagnostics: report.diagnostics,
  }
}

///|
fn attach_visual_scene_limitation(
  report : StructuredReport,
) -> StructuredReport {
  let diagnostic = unlocated_diagnostic(
    "diagnostic:visual-scene-analysis-unavailable:document",
    "visual_scene_analysis_unavailable",
    "document",
    ["source_semantics", "computed_appearance"],
  )
  let diagnostics = report.diagnostics.copy()
  merge_diagnostic_into(diagnostics, diagnostic)
  let coverage_matrix = report.coverage_matrix.copy()
  add_feature_coverage(coverage_matrix, {
    feature_id: "document.visual_scene",
    subject_id: "document",
    source_semantics: "limited",
    computed_appearance: "limited",
    rendered_evidence: "not_applicable",
    diagnostic_ids: [diagnostic.id],
  })
  {
    ..report,
    analysis_status: if report.analysis_status == "failed" {
      "failed"
    } else {
      "partial"
    },
    coverage_matrix,
    diagnostics,
  }
}

///|
fn finish_report(
  report : StructuredReport,
  diagnostics : Array[Diagnostic],
  alignments : Array[SubjectAlignment],
  before_svg : String,
  after_svg : String,
  limits : ResourceLimits,
  resources : ComparisonResourceBundles,
  comparison_guard : ComparisonGuard,
) -> StructuredReport raise ComparisonInterrupted {
  comparison_guard.checkpoint()
  let (report, extra_alignments) = attach_group_opacity_differences(
    report, before_svg, after_svg,
  )
  comparison_guard.checkpoint()
  let report = apply_preflight_diagnostics(report, diagnostics)
  comparison_guard.checkpoint()
  let (report, blend_alignments) = attach_blend_differences(
    report, before_svg, after_svg,
  )
  let combined_alignments = alignments.copy()
  combined_alignments.push_iter(extra_alignments.iter())
  combined_alignments.push_iter(blend_alignments.iter())
  let rendered_alignments = [
    for alignment in combined_alignments if !source_structural_alignment_basis(
      alignment.basis,
    ) => alignment
  ]
  comparison_guard.checkpoint()
  let report = attach_subject_alignments(report, combined_alignments)
  comparison_guard.checkpoint()
  let report = attach_transform_differences(
    report, before_svg, after_svg, rendered_alignments,
  )
  comparison_guard.checkpoint()
  let report = attach_gradient_differences(report, before_svg, after_svg)
  comparison_guard.checkpoint()
  let report = attach_pattern_differences(report, before_svg, after_svg)
  comparison_guard.checkpoint()
  let report = attach_clip_path_differences(report, before_svg, after_svg)
  comparison_guard.checkpoint()
  let report = attach_mask_differences(report, before_svg, after_svg)
  comparison_guard.checkpoint()
  let report = attach_filter_differences(report, before_svg, after_svg)
  comparison_guard.checkpoint()
  let report = attach_marker_resource_differences(report, before_svg, after_svg)
  comparison_guard.checkpoint()
  let report = attach_embedded_image_differences(
    report, before_svg, after_svg, combined_alignments, resources, limits,
  )
  comparison_guard.checkpoint()
  let report = attach_unused_definition_differences(
    report, before_svg, after_svg,
  )
  comparison_guard.checkpoint()
  let report = attach_resource_alignment_ids(report)
  comparison_guard.checkpoint()
  let report = attach_structural_differences(
    report, before_svg, after_svg, rendered_alignments,
  )
  comparison_guard.checkpoint()
  if precompletion_report_exceeds_byte_limit(report, limits) {
    return failed_resource_report(report.profile, [
      resource_limit_diagnostic("report_bytes", None, None),
    ])
  }
  let report = match
    attach_difference_regions(
      report, before_svg, after_svg, rendered_alignments, resources, limits, comparison_guard,
    ) {
    RegionsAttached(report) => report
    AttachmentRegionLimitExceeded =>
      return failed_resource_report(report.profile, [
        resource_limit_diagnostic("regions", None, None),
      ])
  }
  comparison_guard.checkpoint()
  if precompletion_report_exceeds_byte_limit(report, limits) {
    return failed_resource_report(report.profile, [
      resource_limit_diagnostic("report_bytes", None, None),
    ])
  }
  let report = attach_cause_envelopes(report)
  comparison_guard.checkpoint()
  let report = attach_difference_magnitudes(report, before_svg, after_svg)
  comparison_guard.checkpoint()
  let report = attach_feature_coverage(
    report, before_svg, after_svg, resources, limits,
  )
  comparison_guard.checkpoint()
  let report = enforce_coverage_proof(report, before_svg, after_svg)
  comparison_guard.checkpoint()
  let report = attach_renderer_capability_gaps(report)
  comparison_guard.checkpoint()
  let report = attach_diagnostic_fact_locations(report)
  comparison_guard.checkpoint()
  let report = attach_impact_assessment(report)
  comparison_guard.checkpoint()
  let (visual_scene, visual_scene_failed) = (
    @scene.compare_visual_scenes(before_svg, after_svg, report.profile),
    false,
  ) catch {
    _ => (@model.empty_visual_scene_analysis(), true)
  }
  let report = if visual_scene_failed {
    attach_visual_scene_limitation(report)
  } else {
    report
  }
  let report = {
    ..report,
    visual_scene: @scene.attach_visual_scene_evidence(
      visual_scene,
      report.atomic_differences,
      report.events,
    ),
  }
  if precompletion_report_exceeds_byte_limit(report, limits) {
    return failed_resource_report(report.profile, [
      resource_limit_diagnostic("report_bytes", None, None),
    ])
  }
  report
}
