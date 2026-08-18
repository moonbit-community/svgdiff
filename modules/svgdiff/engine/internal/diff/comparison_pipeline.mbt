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
  let scene_context = try
    @scene.prepare_visual_scene(before_svg, after_svg, profile)
  catch {
    _ => None
  } noraise {
    context => Some(context)
  }
  let subject_alignments = subject_alignments_for_sources_with_guard(
    before_svg, after_svg, profile, comparison_guard, scene_context,
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
  let inherited_report = inherited_fill_report(before_svg, after_svg, profile)
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
            schema_version: "4.0",
            analysis_status: "complete",
            canvas_outcome: not_computed_canvas_outcome(
              "rendered_evidence_unavailable",
            ),
            impact_assessment: empty_impact_assessment(),
            coverage_matrix: [],
            renderer_capability_gaps: [],
            visual_scene: @model.empty_visual_scene_analysis(),
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
          scene_context,
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
            schema_version: "4.0",
            analysis_status: "partial",
            canvas_outcome: not_computed_canvas_outcome(
              "rendered_evidence_unavailable",
            ),
            impact_assessment: empty_impact_assessment(),
            coverage_matrix: [],
            renderer_capability_gaps: [],
            visual_scene: @model.empty_visual_scene_analysis(),
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
          scene_context,
        )
      }
      match
        generic_basic_shape_report(
          before_svg, after_svg, before_document, after_document, profile, rendered_subject_alignments,
        ) {
        Some(report) => {
          let report = match inherited_report {
            Some(inherited) =>
              compose_analysis_reports(report, inherited, subject_alignments)
            None => report
          }
          return finish_report(
            report, preflight_diagnostics, subject_alignments, before_svg, after_svg,
            limits, resources, comparison_guard, scene_context,
          )
        }
        None => ()
      }
      match inherited_report {
        Some(report) =>
          return finish_report(
            report, preflight_diagnostics, subject_alignments, before_svg, after_svg,
            limits, resources, comparison_guard, scene_context,
          )
        None => ()
      }
      match deferred_font_report(before_svg, after_svg, profile) {
        Some(report) =>
          return finish_report(
            report, preflight_diagnostics, subject_alignments, before_svg, after_svg,
            limits, resources, comparison_guard, scene_context,
          )
        None => ()
      }
      match presence_change_report(before_document, after_document, profile) {
        Some(report) =>
          return finish_report(
            report, preflight_diagnostics, subject_alignments, before_svg, after_svg,
            limits, resources, comparison_guard, scene_context,
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
            limits, resources, comparison_guard, scene_context,
          )
        None =>
          finish_report(
            {
              schema_version: "4.0",
              analysis_status: "partial",
              canvas_outcome: not_computed_canvas_outcome(
                "rendered_evidence_unavailable",
              ),
              impact_assessment: empty_impact_assessment(),
              coverage_matrix: [],
              renderer_capability_gaps: [],
              visual_scene: @model.empty_visual_scene_analysis(),
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
            scene_context,
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
/// Compare with cooperative cancellation and checkpoint-budget interruption.
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
