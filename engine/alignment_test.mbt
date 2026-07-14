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
  assert_eq(report.analysis_status, "complete")
  assert_eq(report.atomic_differences.length(), 0)
  assert_true(
    report.subject_alignments.all(alignment => {
      alignment.relation == "correspondence" &&
      alignment.before.length() == 1 &&
      alignment.after.length() == 1 &&
      alignment.basis == "exact_visual_signature"
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
      alignment.relation == "deletion" && alignment.after.is_empty()
    }),
  )
  assert_true(
    report.subject_alignments.any(alignment => {
      alignment.relation == "insertion" && alignment.before.is_empty()
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
      alignment.after.length() == 2
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
      alignment.basis == "minimum_property_distance"
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
      alignment.basis == "minimum_property_distance"
    }),
  )
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
test "a visual merge is represented set to set and serialized" {
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
  match @json.parse(report.to_json_string()) {
    { "subject_alignments": [{ "relation": "merge", .. }], .. } => ()
    _ => fail("expected serialized set-to-set alignment")
  }
}
