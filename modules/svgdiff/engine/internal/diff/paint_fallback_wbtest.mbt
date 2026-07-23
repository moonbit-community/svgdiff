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
fn paint_difference(
  report : StructuredReport,
  domain : String,
) -> AtomicDifference? {
  for difference in report.atomic_differences {
    if difference.domain == domain {
      return Some(difference)
    }
  }
  None
}

///|
test "active paint server makes its fallback computed-inactive" {
  let before = "<svg><defs><linearGradient id='g'><stop stop-color='red'/></linearGradient></defs><rect id='box' width='8' height='8' fill='url(#g) red'/></svg>"
  let after = before.replace_all(old="url(#g) red", new="url(#g) blue")
  let report = compare(before, after, ComparisonProfile::v1_default())
  guard paint_difference(report, "paint.fill") is Some(difference) else {
    fail("expected fill difference")
  }
  assert_eq(difference.source_before, "url(#g) red")
  assert_eq(difference.source_after, "url(#g) blue")
  assert_eq(difference.computed_relation.status, "equivalent")
  assert_true(difference.evidence_layers.contains("source_semantics"))
  assert_true(!difference.evidence_layers.contains("computed_appearance"))
}

///|
test "missing and wrong-kind local servers select their fallback" {
  let missing = "<svg><rect id='box' width='8' height='8' fill='url(#missing) red'/></svg>"
  let direct = "<svg><rect id='box' width='8' height='8' fill='#ff0000'/></svg>"
  let missing_report = compare(missing, direct, ComparisonProfile::v1_default())
  guard paint_difference(missing_report, "paint.fill") is Some(missing_diff) else {
    fail("expected missing fallback difference")
  }
  assert_eq(missing_report.analysis_status, "complete")
  assert_eq(missing_diff.computed_relation.status, "equivalent")
  let wrong_kind = "<svg><defs><g id='paint'/></defs><rect id='box' width='8' height='8' fill='URL( \"#paint\" ) red'/></svg>"
  let wrong_report = compare(
    wrong_kind,
    direct,
    ComparisonProfile::v1_default(),
  )
  guard paint_difference(wrong_report, "paint.fill") is Some(wrong_diff) else {
    fail("expected wrong-kind fallback difference")
  }
  assert_eq(wrong_report.analysis_status, "complete")
  assert_eq(wrong_diff.computed_relation.status, "equivalent")
}

///|
test "active currentColor fallback retains dependency and opacity semantics" {
  let before = "<svg id='root' color='red'><rect id='box' width='8' height='8' fill='url(#missing) currentColor' fill-opacity='.5'/></svg>"
  let after = before.replace_all(old="color='red'", new="color='blue'")
  let report = compare(before, after, ComparisonProfile::v1_default())
  guard paint_difference(report, "paint.fill") is Some(difference) else {
    fail("expected currentColor fallback difference")
  }
  assert_eq(difference.computed_relation.status, "different")
  assert_true(
    report.changed_facts.any(fact => {
      fact.subject_id == "root" &&
      fact.property == "color" &&
      fact.affected_subject_ids.contains("box")
    }),
  )
  let alpha_before = "<svg><rect id='box' width='8' height='8' fill='url(#missing) rgba(255,0,0,.5)' fill-opacity='.5'/></svg>"
  let alpha_after = "<svg><rect id='box' width='8' height='8' fill='rgba(255,0,0,.25)'/></svg>"
  let alpha_report = compare(
    alpha_before,
    alpha_after,
    ComparisonProfile::v1_default(),
  )
  guard paint_difference(alpha_report, "paint.fill") is Some(alpha_diff) else {
    fail("expected alpha fallback difference")
  }
  assert_eq(alpha_diff.computed_relation.status, "equivalent")
}

///|
test "inactive currentColor fallback does not create paint fan-out" {
  let before = "<svg id='root' color='red'><defs><linearGradient id='g'><stop stop-color='black'/></linearGradient></defs><rect id='box' width='8' height='8' fill='url(#g) currentColor'/></svg>"
  let after = before.replace_all(old="color='red'", new="color='blue'")
  let report = compare(before, after, ComparisonProfile::v1_default())
  assert_true(
    report.atomic_differences.all(difference => {
      difference.domain != "paint.fill"
    }),
  )
  assert_true(
    report.changed_facts.all(fact => {
      fact.property != "color" || !fact.affected_subject_ids.contains("box")
    }),
  )
}

///|
test "custom property may supply an active paint fallback" {
  let before = "<svg id='root' style='color:red;--paint:url(#missing) currentColor'><rect id='box' width='8' height='8' fill='var(--paint)'/></svg>"
  let after = before.replace_all(old="color:red", new="color:blue")
  let report = compare(before, after, ComparisonProfile::v1_default())
  guard paint_difference(report, "paint.fill") is Some(difference) else {
    fail("expected custom-property fallback difference")
  }
  assert_eq(difference.computed_relation.status, "different")
  assert_true(
    report.changed_facts.any(fact => {
      fact.subject_id == "root" &&
      fact.property == "color" &&
      fact.affected_subject_ids.contains("box")
    }),
  )
}

///|
test "stroke fallback and absent fallback select deterministic paint" {
  let fallback = "<svg><line id='edge' x1='1' y1='4' x2='7' y2='4' fill='none' stroke='url(#missing) red'/></svg>"
  let direct = "<svg><line id='edge' x1='1' y1='4' x2='7' y2='4' fill='none' stroke='#ff0000'/></svg>"
  let report = compare(fallback, direct, ComparisonProfile::v1_default())
  guard paint_difference(report, "paint.stroke") is Some(difference) else {
    fail("expected stroke fallback difference")
  }
  assert_eq(difference.computed_relation.status, "equivalent")
  let absent = fallback.replace_all(
    old="url(#missing) red",
    new="url(#missing)",
  )
  let none = fallback.replace_all(old="url(#missing) red", new="none")
  let absent_report = compare(absent, none, ComparisonProfile::v1_default())
  guard paint_difference(absent_report, "paint.stroke") is Some(absent_diff) else {
    fail("expected absent fallback difference")
  }
  assert_eq(absent_diff.computed_relation.status, "equivalent")
}

///|
test "external context and malformed paint values stay guarded" {
  for
    value in ["url(other.svg#g) red", "context-fill", "url(#missing) red blue"] {
    let source = "<svg><rect width='8' height='8' fill='\{value}'/></svg>"
    let report = compare(source, source, ComparisonProfile::v1_default())
    assert_eq(report.analysis_status, "partial")
    assert_true(
      report.diagnostics.any(diagnostic => {
        diagnostic.code == "paint_value_semantics_unsupported" &&
        !diagnostic.source_locations.is_empty()
      }),
    )
  }
}
