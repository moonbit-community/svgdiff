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
fn gradient_test_subject(source : String, id : String) -> SourceSubject raise {
  let subjects = extract_source_subjects_with_profile_or_raise(
    source,
    ComparisonProfile::v1_default(),
  )
  for subject in subjects {
    if subject.reference.authored_id == Some(id) {
      return subject
    }
  }
  fail("missing gradient test subject")
}

///|
fn resolved_test_gradient(
  source : String,
  gradient_id : String,
  subject_id : String,
) -> ComputedGradient raise {
  let profile = ComparisonProfile::v1_default()
  let document = extract_gradient_document_or_raise(source, profile)
  let subject = gradient_test_subject(source, subject_id)
  guard resolve_gradient_by_id(document, gradient_id, Some(subject))
    is GradientResolved(gradient) else {
    fail("gradient must resolve")
  }
  gradient
}

///|
test "linear gradient resolves defaults every stop and monotonic offsets" {
  let source = "<svg width='16' height='16'><defs><linearGradient id='g'><stop offset='50%' stop-color='red'/><stop offset='.25' stop-color='rgba(0,0,255,.5)' stop-opacity='50%'/></linearGradient></defs><rect id='box' x='2' y='3' width='8' height='4' fill='url(#g)'/></svg>"
  let gradient = resolved_test_gradient(source, "g", "box")
  assert_eq(gradient.kind, "linearGradient")
  assert_eq(gradient.units, "objectBoundingBox")
  assert_eq(gradient.spread_method, "pad")
  assert_eq(computed_gradient_number(gradient.fields, "x1"), 0.0)
  assert_eq(computed_gradient_number(gradient.fields, "x2"), 1.0)
  assert_eq(gradient.stops.length(), 2)
  assert_eq(gradient.stops[0].offset, 0.5)
  assert_eq(gradient.stops[1].offset, 0.5)
  assert_eq(gradient.stops[1].effective_alpha, 0.25)
  assert_eq(gradient.paint_mode, "linear")
  assert_eq(gradient.coordinate_transform.signature(), "matrix(8,0,0,4,2,3)")
}

///|
test "radial gradient defaults focus to resolved center in user space" {
  let source = "<svg width='16' height='8'><defs><radialGradient id='g' gradientUnits='userSpaceOnUse' cx='25%' cy='50%' r='25%' spreadMethod='reflect'><stop stop-color='red'/><stop offset='1' stop-color='blue'/></radialGradient></defs><circle id='dot' cx='4' cy='4' r='3' fill='url(#g)'/></svg>"
  let gradient = resolved_test_gradient(source, "g", "dot")
  assert_eq(gradient.kind, "radialGradient")
  assert_eq(gradient.units, "userSpaceOnUse")
  assert_eq(gradient.spread_method, "reflect")
  assert_eq(computed_gradient_number(gradient.fields, "cx"), 4.0)
  assert_eq(computed_gradient_number(gradient.fields, "cy"), 8.0)
  assert_eq(computed_gradient_number(gradient.fields, "fx"), 4.0)
  assert_eq(computed_gradient_number(gradient.fields, "fy"), 8.0)
  assert_eq(computed_gradient_number(gradient.fields, "r"), 4.0)
  assert_eq(gradient.paint_mode, "radial")
}

///|
test "template chain supplies attributes and cloned stops inherit from host" {
  let source = "<svg width='16' height='16' color='black'><defs><linearGradient id='base' x2='50%' spreadMethod='repeat' color='red'><stop offset='0' stop-color='currentColor'/><stop offset='1' stop-color='blue'/></linearGradient><radialGradient id='middle' href='#base'/><linearGradient id='use' href='#middle' color='green'/></defs><rect id='box' width='8' height='8' fill='url(#use)'/></svg>"
  let gradient = resolved_test_gradient(source, "use", "box")
  assert_eq(gradient.template_chain, ["use", "middle", "base"])
  assert_eq(computed_gradient_number(gradient.fields, "x2"), 0.5)
  assert_eq(gradient.spread_method, "repeat")
  assert_eq(gradient.stops.length(), 2)
  assert_eq(gradient.stops[0].color.renderer_hex(), "#008000")
  assert_eq(
    gradient.stops[0].color_fact.unwrap().authored_value,
    "currentColor",
  )
}

///|
test "unqualified href wins over legacy xlink href" {
  let source = "<svg xmlns:xlink='http://www.w3.org/1999/xlink'><defs><linearGradient id='a' x2='25%'><stop stop-color='red'/></linearGradient><linearGradient id='b' x2='75%'><stop stop-color='blue'/></linearGradient><linearGradient id='g' xlink:href='#a' href='#b'/></defs><rect id='box' width='8' height='8' fill='url(#g)'/></svg>"
  let gradient = resolved_test_gradient(source, "g", "box")
  assert_eq(gradient.template_chain, ["g", "b"])
  assert_eq(computed_gradient_number(gradient.fields, "x2"), 0.75)
  assert_eq(gradient.stops[0].color.renderer_hex(), "#0000ff")
}

///|
test "zero one and degenerate gradients expose their paint mode" {
  let zero = "<svg><defs><linearGradient id='g'/></defs><rect id='box' width='8' height='8' fill='url(#g)'/></svg>"
  let one = "<svg><defs><linearGradient id='g'><stop stop-color='red'/></linearGradient></defs><rect id='box' width='8' height='8' fill='url(#g)'/></svg>"
  let degenerate = "<svg><defs><linearGradient id='g' x1='1' x2='1'><stop stop-color='red'/><stop offset='1' stop-color='blue'/></linearGradient></defs><rect id='box' width='8' height='8' fill='url(#g)'/></svg>"
  assert_eq(
    resolved_test_gradient(zero, "g", "box").paint_mode,
    "none_no_stops",
  )
  assert_eq(
    resolved_test_gradient(one, "g", "box").paint_mode,
    "solid_single_stop",
  )
  assert_eq(
    resolved_test_gradient(degenerate, "g", "box").paint_mode,
    "solid_degenerate_linear_last_stop",
  )
}

///|
test "invalid gradient syntax stays incomplete with precise issues" {
  let source = "<svg><defs><radialGradient id='g' gradientUnits='bad' spreadMethod='bad' r='-1' gradientTransform='translate(,)'><stop offset='bad' stop-color='red'/></radialGradient></defs><rect id='box' width='8' height='8' fill='url(#g)'/></svg>"
  let profile = ComparisonProfile::v1_default()
  let document = extract_gradient_document_or_raise(source, profile)
  let subject = gradient_test_subject(source, "box")
  guard resolve_gradient_by_id(document, "g", Some(subject))
    is GradientResolved(gradient) else {
    fail("gradient must remain structurally resolvable")
  }
  assert_false(gradient.complete)
  for
    code in [
      "gradient_units_syntax_unsupported", "gradient_spread_method_syntax_unsupported",
      "gradient_length_syntax_unsupported", "gradient_transform_syntax_unsupported",
      "gradient_offset_syntax_unsupported",
    ] {
    assert_true(document.issues.any(issue => issue.code == code))
  }
}
