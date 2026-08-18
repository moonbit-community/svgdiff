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
fn alignment_svg(body : String) -> String {
  "<svg width='20' height='20'>\{body}</svg>"
}

///|
test "reordered and renamed subjects align by visual facts" {
  let before = alignment_svg(
    "<rect id='left' x='1' y='2' width='3' height='4' fill='red'/><circle id='dot' cx='12' cy='8' r='2' fill='blue'/>",
  )
  let after = alignment_svg(
    "<circle id='renamed-dot' r='2' fill='blue' cy='8' cx='12'/><rect id='renamed-left' height='4' width='3' y='2' x='1' fill='red'/>",
  )
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.subject_alignments.length(), 2)
  assert_eq(report.analysis_status, "partial")
  assert_true(
    report.diagnostics.any(diagnostic => {
      diagnostic.code == "renderer_curved_shape_raster_unproven"
    }),
  )
  assert_eq(report.atomic_differences.length(), 0)
  assert_true(
    report.subject_alignments.all(alignment => {
      alignment.relation == "correspondence" &&
      alignment.before.length() == 1 &&
      alignment.after.length() == 1 &&
      alignment.basis == "exact_visual_signature" &&
      alignment.evidence.ambiguity == "unique" &&
      alignment.evidence.candidate_count == 1 &&
      alignment.evidence.equal_score_candidate_count == 1
    }),
  )
}

///|
test "insertions and deletions have an empty alignment side" {
  let before = alignment_svg(
    "<rect x='1' y='2' width='3' height='4'/><circle cx='12' cy='8' r='2'/>",
  )
  let after = alignment_svg(
    "<rect x='1' y='2' width='3' height='4'/><line x1='0' y1='0' x2='4' y2='4'/>",
  )
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_true(
    report.subject_alignments.any(alignment => {
      alignment.relation == "deletion" &&
      alignment.after.is_empty() &&
      alignment.evidence.ambiguity == "not_assessed"
    }),
  )
  assert_true(
    report.subject_alignments.any(alignment => {
      alignment.relation == "insertion" &&
      alignment.before.is_empty() &&
      alignment.evidence.ambiguity == "not_assessed"
    }),
  )
}

///|
test "one rectangle can align with a visual split" {
  let before = alignment_svg(
    "<rect x='0' y='0' width='10' height='4' fill='red'/>",
  )
  let after = alignment_svg(
    "<rect x='0' y='0' width='5' height='4' fill='red'/><rect x='5' y='0' width='5' height='4' fill='red'/>",
  )
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_true(
    report.subject_alignments.any(alignment => {
      alignment.relation == "split" &&
      alignment.before.length() == 1 &&
      alignment.after.length() == 2 &&
      alignment.evidence.ambiguity == "not_assessed"
    }),
  )
}

///|
test "similar subjects use deterministic minimum geometry distance" {
  let before = alignment_svg(
    "<rect x='0' y='0' width='2' height='2'/><rect x='10' y='0' width='2' height='2'/>",
  )
  let after = alignment_svg(
    "<rect x='11' y='0' width='2' height='2'/><rect x='1' y='0' width='2' height='2'/>",
  )
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_true(
    report.subject_alignments.any(alignment => {
      alignment.before.length() == 1 &&
      alignment.before[0].source_index == 0 &&
      alignment.after.length() == 1 &&
      alignment.after[0].source_index == 1 &&
      alignment.basis == "minimum_rendered_geometry_distance" &&
      alignment.evidence.ambiguity == "unique" &&
      alignment.evidence.candidate_count == 2 &&
      alignment.evidence.equal_score_candidate_count == 1
    }),
  )
}

///|
test "changed subjects use global rather than greedy minimum cost" {
  let before = alignment_svg(
    "<rect x='4' y='0' width='2' height='2'/><rect x='0' y='0' width='2' height='2'/>",
  )
  let after = alignment_svg(
    "<rect x='3' y='0' width='2' height='2'/><rect x='5' y='0' width='2' height='2'/>",
  )
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_true(
    report.subject_alignments.any(alignment => {
      alignment.before.length() == 1 &&
      alignment.before[0].source_index == 0 &&
      alignment.after.length() == 1 &&
      alignment.after[0].source_index == 1 &&
      alignment.basis == "minimum_rendered_geometry_distance"
    }),
  )
}

///|
test "duplicate exact signatures form one set-to-set equivalence class" {
  let before = alignment_svg(
    "<rect id='before-a' x='2' y='2' width='4' height='4' fill='red'/><rect id='before-b' x='2' y='2' width='4' height='4' fill='red'/>",
  )
  let after = alignment_svg(
    "<rect id='after-b' x='2' y='2' width='4' height='4' fill='red'/><rect id='after-a' x='2' y='2' width='4' height='4' fill='red'/>",
  )
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.subject_alignments.length(), 1)
  let alignment = report.subject_alignments[0]
  assert_eq(alignment.basis, "exact_visual_equivalence_class")
  assert_eq(alignment.before.length(), 2)
  assert_eq(alignment.after.length(), 2)
  assert_eq(alignment.evidence.score_kind, "exact_visual_signature")
  assert_true(alignment.evidence.selected_score == Some(0.0))
  assert_eq(alignment.evidence.candidate_count, 2)
  assert_eq(alignment.evidence.equal_score_candidate_count, 2)
  assert_eq(alignment.evidence.ambiguity, "tied")
  assert_true(alignment.evidence.confidence is None)
  assert_eq(alignment.evidence.confidence_status, "not_calibrated")
  assert_true(report.atomic_differences.is_empty())
  assert_true(report.events.is_empty())
}

///|
test "repeated visual equivalents retain source-semantic differences" {
  let before = alignment_svg(
    "<rect x='2' y='2' width='4' height='4' fill='red'/><rect x='2' y='2' width='4' height='4' fill='red'/>",
  )
  let after = alignment_svg(
    "<rect x='2' y='2' width='4' height='4' fill='#ff0000'/><rect x='2' y='2' width='4' height='4' fill='#ff0000'/>",
  )
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_true(
    report.subject_alignments.all(alignment => {
      alignment.basis != "exact_visual_equivalence_class"
    }),
  )
  let fill_differences = [
    for difference in report.atomic_differences if difference.domain ==
    "paint.fill" => difference
  ]
  assert_eq(fill_differences.length(), 2)
  assert_true(
    fill_differences.all(difference => {
      difference.source_before == "red" &&
      difference.source_after == "#ff0000" &&
      difference.computed_relation.status == "equivalent"
    }),
  )
}

///|
test "equal minimum costs retain stable signature and source order" {
  let before = alignment_svg(
    "<rect x='0' y='2' width='4' height='4' fill='red'/><rect x='2' y='2' width='4' height='4' fill='red'/>",
  )
  let after = alignment_svg(
    "<rect x='1' y='2' width='4' height='4' fill='red'/><rect x='1' y='2' width='4' height='4' fill='red'/>",
  )
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  let pairs = [
    for alignment in report.subject_alignments if alignment.basis ==
    "minimum_rendered_geometry_distance" => {
      (alignment.before[0].source_index, alignment.after[0].source_index)
    }
  ]
  assert_eq(pairs, [(0, 0), (1, 1)])
  for alignment in report.subject_alignments {
    assert_eq(
      alignment.evidence.score_kind,
      "rendered_geometry_feature_distance_v1",
    )
    assert_true(
      alignment.evidence.selected_score is Some(score) &&
      score >= 0.0 &&
      score <= 1.0,
    )
    assert_eq(alignment.evidence.candidate_count, 2)
    assert_eq(alignment.evidence.equal_score_candidate_count, 2)
    assert_eq(alignment.evidence.ambiguity, "tied")
    assert_true(alignment.evidence.confidence is None)
    assert_eq(alignment.evidence.confidence_status, "not_calibrated")
  }
}

///|
test "inherited hierarchy context participates in exact alignment" {
  let before = alignment_svg(
    "<g fill='red'><rect id='red-box' x='2' y='2' width='4' height='4'/></g><g fill='blue'><rect id='blue-box' x='2' y='2' width='4' height='4'/></g>",
  )
  let after = alignment_svg(
    "<g fill='blue'><rect id='renamed-blue' x='2' y='2' width='4' height='4'/></g><g fill='red'><rect id='renamed-red' x='2' y='2' width='4' height='4'/></g>",
  )
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_true(
    report.subject_alignments.any(alignment => {
      alignment.before.any(reference => reference.authored_id == Some("red-box")) &&
      alignment.after.any(reference => {
        reference.authored_id == Some("renamed-red")
      }) &&
      alignment.basis == "exact_visual_signature"
    }),
  )
}

///|
test "a visual merge stays internal to subject alignment" {
  let before = alignment_svg(
    "<rect x='0' y='0' width='5' height='4' fill='red'/><rect x='5' y='0' width='5' height='4' fill='red'/>",
  )
  let after = alignment_svg(
    "<rect x='0' y='0' width='10' height='4' fill='red'/>",
  )
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_true(
    report.subject_alignments.any(alignment => {
      alignment.relation == "merge" &&
      alignment.before.length() == 2 &&
      alignment.after.length() == 1
    }),
  )
  assert_true(report.to_json_string().find("subject_alignments") is None)
}

///|
test "path and group inventories align without shifting shape IDs" {
  let before = alignment_svg(
    "<g id='layer'><path id='curve' d='M 1 1 L 9 9' fill='none' stroke='red'/></g>",
  )
  let after = alignment_svg(
    "<g id='layer'><path id='curve' d='M1,1L9,9' fill='none' stroke='red'/></g>",
  )
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_true(
    report.subject_alignments.any(alignment => {
      alignment.id == "alignment:0" &&
      alignment.before[0].kind == "path" &&
      alignment.basis == "exact_visual_signature"
    }),
  )
  assert_true(
    report.subject_alignments.any(alignment => {
      alignment.id == "alignment:1" &&
      alignment.before[0].kind == "g" &&
      alignment.basis == "structural_authored_id"
    }),
  )
}

///|
test "text alignment owns source differences without claiming font evidence" {
  let before = alignment_svg(
    "<text id='label' x='1' y='12' font-family='Unresolved Font'>A</text>",
  )
  let after = alignment_svg(
    "<text id='label' x='1' y='12' font-family='Unresolved Font'>B</text>",
  )
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  let alignment = report.subject_alignments[0]
  assert_eq(alignment.before[0].kind, "text")
  assert_eq(alignment.basis, "structural_authored_id")
  assert_eq(alignment.evidence.ambiguity, "unique")
  assert_true(alignment.evidence.confidence is None)
  let difference = report.atomic_differences[0]
  assert_eq(difference.subject_alignment_id, Some(alignment.id))
  assert_eq(difference.computed_relation.status, "indeterminate")
  assert_eq(report.analysis_status, "partial")
}

///|
test "use hosts and their rendered leaf instances remain distinct" {
  let source = alignment_svg(
    "<defs><g id='tile'><rect id='shape' x='1' y='1' width='4' height='4'/></g></defs><use id='placement' href='#tile' x='2'/>",
  )
  let report = @engine.compare(
    source,
    source,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_true(
    report.subject_alignments.any(alignment => {
      alignment.basis == "use_instance_path" &&
      alignment.before[0].kind == "rect" &&
      alignment.before[0].instance_context is Some(_)
    }),
  )
  assert_true(
    report.subject_alignments.any(alignment => {
      alignment.basis == "structural_semantic_signature" &&
      alignment.before[0].kind == "use" &&
      alignment.before[0].authored_id == Some("placement") &&
      alignment.before[0].instance_context is None
    }),
  )
}

///|
test "resource definitions align independently and retain resource attribution" {
  let before = alignment_svg(
    "<defs><linearGradient id='paint'><stop offset='0' stop-color='red'/></linearGradient></defs><rect id='box' width='10' height='10' fill='url(#paint)'/>",
  )
  let after = alignment_svg(
    "<defs><linearGradient id='paint'><stop offset='0' stop-color='blue'/></linearGradient></defs><rect id='box' width='10' height='10' fill='url(#paint)'/>",
  )
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_true(
    report.subject_alignments.any(alignment => {
      alignment.before.any(reference => {
        reference.kind == "linearGradient" &&
        reference.authored_id == Some("paint")
      }) &&
      alignment.subject_role == "resource" &&
      alignment.basis == "resource_authored_id"
    }),
  )
  assert_true(
    report.atomic_differences
    .filter(difference => difference.subject_role == "resource")
    .all(difference => {
      difference.subject_alignment_id is Some(alignment_id) &&
      report.subject_alignments.any(alignment => {
        alignment.id == alignment_id && alignment.subject_role == "resource"
      })
    }),
  )
  assert_true(
    report.atomic_differences.any(difference => {
      difference.subject_role == "resource" &&
      difference.subject_alignment_id is Some(_)
    }),
  )
}

///|
test "repeated structural subjects form one semantic equivalence class" {
  let before = alignment_svg("<defs><g/><g/><filter id='removed'/></defs>")
  let after = alignment_svg("<symbol><g/><g/></symbol>")
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_true(
    report.subject_alignments.any(alignment => {
      alignment.before.length() == 2 &&
      alignment.after.length() == 2 &&
      alignment.before[0].kind == "g" &&
      alignment.basis == "structural_semantic_signature" &&
      alignment.evidence.candidate_count == 2 &&
      alignment.evidence.equal_score_candidate_count == 2 &&
      alignment.evidence.ambiguity == "tied"
    }),
  )
  assert_true(
    report.subject_alignments.any(alignment => {
      alignment.relation == "insertion" &&
      alignment.after.any(reference => reference.kind == "symbol")
    }),
  )
  assert_true(
    report.subject_alignments.any(alignment => {
      alignment.relation == "deletion" &&
      alignment.before.any(reference => reference.kind == "filter")
    }),
  )
}

///|
test "structural semantic signatures match reordered groups without IDs or order" {
  let before = alignment_svg(
    "<g aria-label='ignored' fill='red'><rect x='1' width='2' height='2'/></g><g fill='blue'><rect x='10' width='2' height='2'/></g>",
  )
  let after = alignment_svg(
    "<g fill='blue'><rect height='2' width='2' x='10'/></g><g data-note='ignored' fill='red'><rect height='2' x='1' width='2'/></g>",
  )
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  let groups = [
    for alignment in report.subject_alignments if alignment.before.length() == 1 &&
    alignment.after.length() == 1 &&
    alignment.before[0].kind == "g" => alignment
  ]
  assert_eq(groups.length(), 2)
  assert_true(
    groups.all(alignment => {
      alignment.basis == "structural_semantic_signature" &&
      alignment.evidence.ambiguity == "unique"
    }),
  )
  assert_true(
    groups[0].before[0].source_index < groups[1].before[0].source_index &&
    groups[0].after[0].source_index > groups[1].after[0].source_index,
  )
}

///|
test "structural semantic signatures preserve child order" {
  let before = alignment_svg(
    "<g id='layer'><rect fill='red'/><rect fill='blue'/></g>",
  )
  let after = alignment_svg(
    "<g id='layer'><rect fill='blue'/><rect fill='red'/></g>",
  )
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_true(
    report.subject_alignments.any(alignment => {
      alignment.before[0].kind == "g" &&
      alignment.basis == "structural_authored_id"
    }),
  )
}

///|
test "exact alignment distinguishes swapped cumulative transforms" {
  let before = alignment_svg(
    "<rect id='before-left' x='0' y='0' width='2' height='2'/><rect id='before-right' x='0' y='0' width='2' height='2' transform='translate(10 0)'/>",
  )
  let after = alignment_svg(
    "<rect id='after-right' x='0' y='0' width='2' height='2' transform='translate(10 0)'/><rect id='after-left' x='0' y='0' width='2' height='2'/>",
  )
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_true(
    report.subject_alignments.any(alignment => {
      alignment.before[0].authored_id == Some("before-left") &&
      alignment.after[0].authored_id == Some("after-left") &&
      alignment.basis == "exact_visual_signature"
    }),
  )
  assert_true(
    report.subject_alignments.any(alignment => {
      alignment.before[0].authored_id == Some("before-right") &&
      alignment.after[0].authored_id == Some("after-right") &&
      alignment.basis == "exact_visual_signature"
    }),
  )
}

///|
test "feature distance aligns compensated local geometry by final bounds" {
  let before = alignment_svg(
    "<rect id='before-left' x='0' y='0' width='2' height='2' transform='translate(10 0)'/><rect id='before-right' x='20' y='0' width='2' height='2'/>",
  )
  let after = alignment_svg(
    "<rect id='after-right' x='0' y='0' width='2' height='2' transform='translate(20 0)'/><rect id='after-left' x='10' y='0' width='2' height='2'/>",
  )
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_true(
    report.subject_alignments.any(alignment => {
      alignment.before[0].authored_id == Some("before-left") &&
      alignment.after[0].authored_id == Some("after-left") &&
      alignment.basis == "minimum_rendered_geometry_distance"
    }),
  )
  assert_true(
    report.subject_alignments.any(alignment => {
      alignment.before[0].authored_id == Some("before-right") &&
      alignment.after[0].authored_id == Some("after-right") &&
      alignment.basis == "minimum_rendered_geometry_distance"
    }),
  )
}

///|
test "alignment resolves geometry under the caller comparison viewport" {
  let before = alignment_svg(
    "<rect id='percentage' x='50%' y='0' width='2' height='2'/>",
  )
  let after = alignment_svg(
    "<rect id='absolute' x='100' y='0' width='2' height='2'/>",
  )
  let report = @engine.compare(before, after, {
    ..@engine.ComparisonProfile::v1_default(),
    viewport_width: 200,
  })
  assert_true(
    report.subject_alignments.any(alignment => {
      alignment.before[0].authored_id == Some("percentage") &&
      alignment.after[0].authored_id == Some("absolute") &&
      alignment.basis == "exact_visual_signature"
    }),
  )
}

///|
test "path feature distance compares control geometry in device space" {
  let before = alignment_svg(
    "<path id='before-left' d='M0 0 L2 2' transform='translate(10 0)'/><path id='before-right' d='M20 0 L22 2'/>",
  )
  let after = alignment_svg(
    "<path id='after-right' d='M0 0 L2 2' transform='translate(20 0)'/><path id='after-left' d='M10 0 L12 2'/>",
  )
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_true(
    report.subject_alignments.any(alignment => {
      alignment.before[0].authored_id == Some("before-left") &&
      alignment.after[0].authored_id == Some("after-left") &&
      alignment.basis == "minimum_rendered_geometry_distance"
    }),
  )
  assert_true(
    report.subject_alignments.any(alignment => {
      alignment.before[0].authored_id == Some("before-right") &&
      alignment.after[0].authored_id == Some("after-right") &&
      alignment.basis == "minimum_rendered_geometry_distance"
    }),
  )
}

///|
test "one-sided incomplete transform cannot receive zero feature distance" {
  let before = alignment_svg(
    "<rect id='incomplete' x='0' y='0' width='2' height='2' transform='translate('/>",
  )
  let after = alignment_svg(
    "<rect id='complete' x='0' y='0' width='2' height='2'/>",
  )
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "partial")
  guard report.subject_alignments[0].evidence.selected_score is Some(score) else {
    fail("expected assessed feature distance")
  }
  assert_true(score > 0.0 && score <= 1.0)
}
