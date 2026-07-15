///|
priv enum RectComputedFact {
  RectNumber(Double)
  RectColor(Int, Int, Int, Int)
}

///|
fn first_rect_node(node : @svg.SVGNode) -> @svg.SVGNode? {
  match node.shape {
    Rect(..) => Some(node)
    _ =>
      for child in node.children {
        match first_rect_node(child) {
          Some(rect) => return Some(rect)
          None => ()
        }
      } nobreak {
        None
      }
  }
}

///|
fn rect_computed_fact(
  document : @svg.SVGDocument,
  property : String,
) -> RectComputedFact? {
  match first_rect_node(document.root) {
    Some(node) =>
      match (property, node.shape) {
        ("x", Rect(x~, ..)) => Some(RectNumber(x))
        ("y", Rect(y~, ..)) => Some(RectNumber(y))
        ("width", Rect(width~, ..)) => Some(RectNumber(width))
        ("height", Rect(height~, ..)) => Some(RectNumber(height))
        ("fill", _) =>
          match node.fill {
            SolidColor(color) =>
              Some(RectColor(color.r, color.g, color.b, color.a))
            _ => None
          }
        ("opacity", _) => Some(RectNumber(node.opacity))
        _ => None
      }
    None => None
  }
}

///|
fn rect_computed_facts_equal(
  before : RectComputedFact,
  after : RectComputedFact,
) -> Bool {
  match (before, after) {
    (RectNumber(before), RectNumber(after)) => before == after
    (
      RectColor(before_r, before_g, before_b, before_a),
      RectColor(after_r, after_g, after_b, after_a),
    ) =>
      before_r == after_r &&
      before_g == after_g &&
      before_b == after_b &&
      before_a == after_a
    _ => false
  }
}

///|
fn rect_parameter_delta_css_px(
  property : String,
  before : RectComputedFact,
  after : RectComputedFact,
) -> Double? {
  match (property, before, after) {
    ("x" | "y" | "width" | "height", RectNumber(before), RectNumber(after)) =>
      Some(after - before)
    _ => None
  }
}

///|
fn rect_difference_domain(property : String) -> String {
  match property {
    "x" | "y" => "geometry.position"
    "width" | "height" => "geometry.size"
    "fill" => "paint.fill"
    "opacity" => "paint.opacity"
    _ => "document.unsupported"
  }
}

///|
fn rect_relation_reason(property : String, equivalent : Bool) -> String {
  match (property, equivalent) {
    ("x" | "y", true) => "same_resolved_position"
    ("x" | "y", false) => "resolved_positions_differ"
    ("width" | "height", true) => "same_resolved_size"
    ("width" | "height", false) => "resolved_sizes_differ"
    ("fill", true) => "same_resolved_color"
    ("fill", false) => "resolved_colors_differ"
    ("opacity", true) => "same_resolved_opacity"
    ("opacity", false) => "resolved_opacities_differ"
    (_, true) => "same_resolved_fact"
    _ => "resolved_facts_differ"
  }
}

///|
fn declared_value_or_empty(fact : DeclaredVisualFact?) -> String {
  match fact {
    Some(fact) => fact.declared_value
    None => ""
  }
}

///|
fn add_diagnostic(
  diagnostics : Array[Diagnostic],
  code : String,
  subject_id : String,
  affected_evidence_layers : Array[String],
) -> String {
  for diagnostic in diagnostics {
    if diagnostic.code == code && diagnostic.subject_id == subject_id {
      return diagnostic.id
    }
  }
  let id = "diagnostic:\{code}:\{subject_id}"
  diagnostics.push(
    unlocated_diagnostic(id, code, subject_id, affected_evidence_layers),
  )
  id
}

///|
fn diagnostic_ids(diagnostics : Array[Diagnostic]) -> Array[String] {
  [
    for diagnostic in diagnostics => diagnostic.id
  ]
}

///|
fn rect_coverage_report(
  profile : ComparisonProfile,
  code : String,
) -> StructuredReport {
  let subject_id = "rect:0"
  let diagnostic_id = "diagnostic:\{code}:\{subject_id}"
  {
    schema_version: "1.21",
    analysis_status: "partial",
    coverage_matrix: [],
    renderer_capability_gaps: [],
    profile,
    subject_alignments: [],
    changed_facts: [],
    source_resolutions: [],
    atomic_differences: [],
    events: [],
    diagnostics: [
      {
        id: diagnostic_id,
        code,
        subject_id,
        affected_evidence_layers: [
          "source_semantics", "computed_appearance", "rendered_evidence",
        ],
        source_locations: [],
      },
    ],
  }
}

///|
fn compare_rect_declared_facts(
  before_facts : RectDeclaredFacts,
  after_facts : RectDeclaredFacts,
  before_document : @svg.SVGDocument,
  after_document : @svg.SVGDocument,
  profile : ComparisonProfile,
) -> StructuredReport {
  let subject_id = if after_facts.subject_id != "rect:0" {
    after_facts.subject_id
  } else {
    before_facts.subject_id
  }
  let diagnostics : Array[Diagnostic] = []
  for code in before_facts.coverage_codes {
    ignore(
      add_diagnostic(diagnostics, code, subject_id, [
        "source_semantics", "computed_appearance",
      ]),
    )
  }
  for code in after_facts.coverage_codes {
    ignore(
      add_diagnostic(diagnostics, code, subject_id, [
        "source_semantics", "computed_appearance",
      ]),
    )
  }
  let differences : Array[AtomicDifference] = []
  for property in rect_property_order() {
    let source_fact_before = declared_fact(before_facts, property)
    let source_fact_after = declared_fact(after_facts, property)
    if !declared_fact_changed(source_fact_before, source_fact_after) {
      continue
    }
    let before_computed = rect_computed_fact(before_document, property)
    let after_computed = rect_computed_fact(after_document, property)
    let relation = if !diagnostics.is_empty() {
      {
        status: "indeterminate",
        reason_code: "rect_analysis_coverage_incomplete",
        missing_side: None,
        diagnostic_ids: diagnostic_ids(diagnostics),
      }
    } else {
      match (before_computed, after_computed) {
        (Some(before), Some(after)) => {
          let equivalent = rect_computed_facts_equal(before, after)
          {
            status: if equivalent {
              "equivalent"
            } else {
              "different"
            },
            reason_code: rect_relation_reason(property, equivalent),
            missing_side: None,
            diagnostic_ids: [],
          }
        }
        _ => {
          let id = add_diagnostic(
            diagnostics,
            "computed_rect_fact_unavailable",
            subject_id,
            ["computed_appearance"],
          )
          {
            status: "indeterminate",
            reason_code: "computed_rect_fact_unavailable",
            missing_side: None,
            diagnostic_ids: [id],
          }
        }
      }
    }
    let evidence_layers : Array[String] = ["source_semantics"]
    if relation.status == "different" {
      evidence_layers.push("computed_appearance")
    }
    let parameter_delta_css_px = match (before_computed, after_computed) {
      (Some(before), Some(after)) =>
        rect_parameter_delta_css_px(property, before, after)
      _ => None
    }
    differences.push({
      id: "diff:entity:\{subject_id}:\{property}",
      subject_role: "entity",
      subject_alignment_id: None,
      domain: rect_difference_domain(property),
      source_before: declared_value_or_empty(source_fact_before),
      source_after: declared_value_or_empty(source_fact_after),
      source_fact_before,
      source_fact_after,
      changed_fact_ids: [],
      evidence_layers,
      computed_relation: relation,
      parameter_delta_css_px,
      presence_magnitude: None,
      magnitude: empty_difference_magnitude(),
      domain_ordering: empty_domain_ordering(),
    })
  }
  let events : Array[VisualEvent] = []
  if !differences.is_empty() {
    let rendered = rendered_difference(before_document, after_document, profile)
    if rendered.changed_pixels > 0 {
      for difference in differences {
        difference.evidence_layers.push("rendered_evidence")
      }
    }
    events.push({
      id: "event:\{subject_id}",
      primary_subject_id: subject_id,
      atomic_difference_ids: [
        for difference in differences => difference.id
      ],
      rendered_outcome: computed_rendered_evidence(rendered),
      difference_regions: [],
    })
  }
  {
    schema_version: "1.21",
    analysis_status: if diagnostics.is_empty() {
      "complete"
    } else {
      "partial"
    },
    coverage_matrix: [],
    renderer_capability_gaps: [],
    profile,
    subject_alignments: [],
    changed_facts: [],
    source_resolutions: [],
    atomic_differences: differences,
    events,
    diagnostics,
  }
}

///|
fn solid_rect_change_report(
  before_svg : String,
  after_svg : String,
  before_document : @svg.SVGDocument,
  after_document : @svg.SVGDocument,
  profile : ComparisonProfile,
) -> StructuredReport? {
  match
    (
      extract_pattern_document(before_svg, profile),
      extract_pattern_document(after_svg, profile),
    ) {
    (Some(before), Some(after)) if !before.patterns.is_empty() ||
      !after.patterns.is_empty() => return None
    _ => ()
  }
  let before_subjects = extract_source_subjects_with_profile_or_raise(
    before_svg, profile,
  ) catch {
    _ => return None
  }
  let after_subjects = extract_source_subjects_with_profile_or_raise(
    after_svg, profile,
  ) catch {
    _ => return None
  }
  if before_subjects.any(subject => {
      source_subject_fact(subject, "fill")
      .map(fact => paint_value_uses_url(fact.declared_value))
      .unwrap_or(false)
    }) ||
    after_subjects.any(subject => {
      source_subject_fact(subject, "fill")
      .map(fact => paint_value_uses_url(fact.declared_value))
      .unwrap_or(false)
    }) {
    return None
  }
  guard before_subjects is [{ kind: "rect", .. }] &&
    after_subjects is [{ kind: "rect", .. }] else {
    return None
  }
  match
    (
      extract_rect_declared_facts(before_svg),
      extract_rect_declared_facts(after_svg),
    ) {
    (Failed, _) | (_, Failed) =>
      Some(rect_coverage_report(profile, "xml_source_parse_failed"))
    (Parsed(Some(before_facts)), Parsed(Some(after_facts))) =>
      Some(
        compare_rect_declared_facts(
          before_facts, after_facts, before_document, after_document, profile,
        ),
      )
    (Parsed(None), Parsed(None)) => None
    _ =>
      Some(rect_coverage_report(profile, "single_rect_alignment_unsupported"))
  }
}
