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
fn source_slice(input : String, span : @xml.SourceSpan) -> String {
  let view = input.view(
    start_offset=span.start.offset,
    end_offset=span.end.offset,
  )
  "\{view}"
}

///|
fn source_text_content_or_raise(input : String) -> String? raise {
  let reader = @xml.NamespaceReader::from_string(input)
  let mut in_text = false
  let mut nested_depth = 0
  let mut text = ""
  for event in reader.read_events_until_eof() {
    match event.kind {
      Start(element) =>
        if in_text {
          nested_depth += 1
        } else if element.name.local_name == "text" {
          in_text = true
        }
      Empty(element) =>
        if !in_text && element.name.local_name == "text" {
          return Some("")
        }
      Text(_) if in_text && nested_depth == 0 =>
        text += source_slice(input, event.span)
      End(_) if in_text && nested_depth == 0 => return Some(text)
      End(_) if in_text => nested_depth -= 1
      _ => ()
    }
  }
  None
}

///|
fn source_text_content(input : String) -> String? {
  try source_text_content_or_raise(input) catch {
    _ => None
  } noraise {
    value => value
  }
}

///|
fn find_svg_node(node : @svg.SVGNode, id : String) -> @svg.SVGNode? {
  if node.id == id {
    return Some(node)
  }
  for child in node.children {
    match find_svg_node(child, id) {
      Some(found) => return Some(found)
      None => ()
    }
  } nobreak {
    None
  }
}

///|
fn rect_presence_footprint(
  document : @svg.SVGDocument,
  id : String,
  profile : ComparisonProfile,
) -> PresenceMagnitude? {
  match find_svg_node(document.root(), id) {
    Some(node) =>
      match node.shape {
        Rect(x=_, y=_, width~, height~, rx=_, ry=_) => {
          let bounds_area = width * height
          let viewport_area = profile.viewport_width.to_double() *
            profile.viewport_height.to_double()
          let painted_area = if node.opacity == 0.0 { 0.0 } else { bounds_area }
          Some({
            affected_entity_count: 1,
            bounds_area_css_px2: bounds_area,
            bounds_viewport_fraction: bounds_area / viewport_area,
            painted_area_css_px2: painted_area,
            painted_viewport_fraction: painted_area / viewport_area,
          })
        }
        _ => None
      }
    None => None
  }
}

///|
fn deferred_font_report(
  before_svg : String,
  after_svg : String,
  profile : ComparisonProfile,
) -> StructuredReport? {
  match (source_text_content(before_svg), source_text_content(after_svg)) {
    (Some(source_before), Some(source_after)) if source_before != source_after => {
      let diagnostic_id = "diagnostic:font-analysis-deferred:label"
      let difference_id = "diff:entity:label:text"
      Some({
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
        atomic_differences: [
          {
            id: difference_id,
            subject_role: "entity",
            subject_alignment_id: None,
            domain: "text.content",
            source_before,
            source_after,
            source_fact_before: None,
            source_fact_after: None,
            changed_fact_ids: [],
            evidence_layers: ["source_semantics"],
            computed_relation: {
              status: "indeterminate",
              reason_code: "font_analysis_deferred",
              missing_side: None,
              diagnostic_ids: [diagnostic_id],
            },
            parameter_delta_css_px: None,
            presence_magnitude: None,
            magnitude: empty_difference_magnitude(),
            domain_ordering: empty_domain_ordering(),
          },
        ],
        events: [
          {
            id: "event:label",
            primary_subject_id: "label",
            atomic_difference_ids: [difference_id],
            rendered_outcome: not_computed_rendered_evidence(
              "font_analysis_deferred",
            ),
            difference_regions: [],
          },
        ],
        diagnostics: [
          {
            id: diagnostic_id,
            code: "font_analysis_deferred",
            subject_id: "label",
            affected_evidence_layers: [
              "computed_appearance", "rendered_evidence",
            ],
            source_locations: element_diagnostic_locations(
              before_svg, "before", "text",
            ) +
            element_diagnostic_locations(after_svg, "after", "text"),
          },
        ],
      })
    }
    _ => None
  }
}

///|
fn presence_change_report(
  before_document : @svg.SVGDocument,
  after_document : @svg.SVGDocument,
  profile : ComparisonProfile,
) -> StructuredReport? {
  let before_footprint = rect_presence_footprint(
    before_document, "box", profile,
  )
  let after_footprint = rect_presence_footprint(after_document, "box", profile)
  match (before_footprint, after_footprint) {
    (None, Some(presence_magnitude)) => {
      let difference_id = "diff:entity:box:presence"
      let rendered = rendered_difference(
        before_document, after_document, profile,
      )
      Some({
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
        atomic_differences: [
          {
            id: difference_id,
            subject_role: "entity",
            subject_alignment_id: None,
            domain: "presence.insertion",
            source_before: "",
            source_after: "rect#box",
            source_fact_before: None,
            source_fact_after: None,
            changed_fact_ids: [],
            evidence_layers: ["source_semantics", "computed_appearance"],
            computed_relation: {
              status: "not_applicable",
              reason_code: "before_fact_absent",
              missing_side: Some("before"),
              diagnostic_ids: [],
            },
            parameter_delta_css_px: None,
            presence_magnitude: Some(presence_magnitude),
            magnitude: empty_difference_magnitude(),
            domain_ordering: empty_domain_ordering(),
          },
        ],
        events: [
          {
            id: "event:box",
            primary_subject_id: "box",
            atomic_difference_ids: [difference_id],
            rendered_outcome: computed_rendered_evidence(rendered),
            difference_regions: [],
          },
        ],
        diagnostics: [],
      })
    }
    (Some(presence_magnitude), None) => {
      let difference_id = "diff:entity:box:presence"
      let rendered = rendered_difference(
        before_document, after_document, profile,
      )
      Some({
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
        atomic_differences: [
          {
            id: difference_id,
            subject_role: "entity",
            subject_alignment_id: None,
            domain: "presence.deletion",
            source_before: "rect#box",
            source_after: "",
            source_fact_before: None,
            source_fact_after: None,
            changed_fact_ids: [],
            evidence_layers: ["source_semantics", "computed_appearance"],
            computed_relation: {
              status: "not_applicable",
              reason_code: "after_fact_absent",
              missing_side: Some("after"),
              diagnostic_ids: [],
            },
            parameter_delta_css_px: None,
            presence_magnitude: Some(presence_magnitude),
            magnitude: empty_difference_magnitude(),
            domain_ordering: empty_domain_ordering(),
          },
        ],
        events: [
          {
            id: "event:box",
            primary_subject_id: "box",
            atomic_difference_ids: [difference_id],
            rendered_outcome: computed_rendered_evidence(rendered),
            difference_regions: [],
          },
        ],
        diagnostics: [],
      })
    }
    _ => None
  }
}
