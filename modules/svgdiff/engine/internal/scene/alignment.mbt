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
fn object_alignment_candidates(
  before : VisualScene,
  after : VisualScene,
) -> Array[AlignmentCandidate] {
  let candidates : Array[AlignmentCandidate] = []
  for before_index, before_object in before.objects {
    for after_index, after_object in after.objects {
      let common = multiset_common_count(
        before_object.summary.semantic_text,
        after_object.summary.semantic_text,
      )
      if common == 0 {
        continue
      }
      let total = before_object.summary.semantic_text
        .length()
        .max(after_object.summary.semantic_text.length())
      candidates.push({
        before_index,
        after_index,
        common_text: common,
        total_text: total,
      })
    }
  }
  candidates.sort_by(fn(left, right) {
    let left_scaled = left.common_text * right.total_text
    let right_scaled = right.common_text * left.total_text
    if left_scaled != right_scaled {
      right_scaled - left_scaled
    } else if left.common_text != right.common_text {
      right.common_text - left.common_text
    } else if left.before_index != right.before_index {
      left.before_index - right.before_index
    } else {
      left.after_index - right.after_index
    }
  })
  candidates
}

///|
fn exact_scene_object_signature(object : SceneObject) -> String {
  let primitive_signatures = object.primitive_signatures.copy()
  primitive_signatures.sort()
  let style_signatures = object.style_signatures.copy()
  style_signatures.sort()
  let bounds = match object.summary.bounds {
    Some(value) => "\{value.x},\{value.y},\{value.width},\{value.height}"
    None => "none"
  }
  "text=\{scene_text_signature(object.summary.semantic_text)}|primitives=\{primitive_signatures.join(";")}|styles=\{style_signatures.join(";")}|bounds=\{bounds}"
}

///|
fn align_scene_objects(
  before : VisualScene,
  after : VisualScene,
) -> Array[@model.VisualObjectAlignment] {
  let alignments : Array[@model.VisualObjectAlignment] = []
  let before_used = Array::make(before.objects.length(), false)
  let after_used = Array::make(after.objects.length(), false)
  for before_index, before_object in before.objects {
    guard !before_used[before_index] && before_object.identity is Some(identity) else {
      continue
    }
    let before_class = [
      for index, object in before.objects if !before_used[index] &&
      object.identity == Some(identity) => index
    ]
    let after_class = [
      for index, object in after.objects if !after_used[index] &&
      object.identity == Some(identity) => index
    ]
    if after_class.is_empty() {
      continue
    }
    for index in before_class {
      before_used[index] = true
    }
    for index in after_class {
      after_used[index] = true
    }
    let one_to_one = before_class.length() == 1 && after_class.length() == 1
    alignments.push({
      id: "object-alignment:\{alignments.length()}",
      relation: if one_to_one {
        "correspondence"
      } else {
        "equivalence_class"
      },
      before_object_ids: [
        for index in before_class => before.objects[index].summary.id
      ],
      after_object_ids: [
        for index in after_class => after.objects[index].summary.id
      ],
      basis: "authored_identity/v1",
      ambiguity: if one_to_one {
        "none"
      } else {
        "set_to_set"
      },
    })
  }
  for before_index, before_object in before.objects {
    if before_used[before_index] {
      continue
    }
    let signature = exact_scene_object_signature(before_object)
    let before_class = [
      for index, object in before.objects if !before_used[index] &&
      exact_scene_object_signature(object) == signature => index
    ]
    let after_class = [
      for index, object in after.objects if !after_used[index] &&
      exact_scene_object_signature(object) == signature => index
    ]
    if after_class.is_empty() || before_class.length() != after_class.length() {
      continue
    }
    for index in before_class {
      before_used[index] = true
    }
    for index in after_class {
      after_used[index] = true
    }
    let one_to_one = before_class.length() == 1
    alignments.push({
      id: "object-alignment:\{alignments.length()}",
      relation: if one_to_one {
        "correspondence"
      } else {
        "equivalence_class"
      },
      before_object_ids: [
        for index in before_class => before.objects[index].summary.id
      ],
      after_object_ids: [
        for index in after_class => after.objects[index].summary.id
      ],
      basis: "exact_visual_object_signature/v1",
      ambiguity: if one_to_one {
        "none"
      } else {
        "set_to_set"
      },
    })
  }
  for before_index, before_object in before.objects {
    if before_used[before_index] ||
      before_object.summary.semantic_text.is_empty() {
      continue
    }
    let signature = scene_text_signature(before_object.summary.semantic_text)
    let before_class = [
      for index, object in before.objects if !before_used[index] &&
      scene_text_signature(object.summary.semantic_text) == signature => index
    ]
    let after_class = [
      for index, object in after.objects if !after_used[index] &&
      scene_text_signature(object.summary.semantic_text) == signature => index
    ]
    if after_class.is_empty() {
      continue
    }
    for index in before_class {
      before_used[index] = true
    }
    for index in after_class {
      after_used[index] = true
    }
    let one_to_one = before_class.length() == 1 && after_class.length() == 1
    alignments.push({
      id: "object-alignment:\{alignments.length()}",
      relation: if one_to_one {
        "correspondence"
      } else {
        "equivalence_class"
      },
      before_object_ids: [
        for index in before_class => before.objects[index].summary.id
      ],
      after_object_ids: [
        for index in after_class => after.objects[index].summary.id
      ],
      basis: "exact_semantic_text_multiset/v1",
      ambiguity: if one_to_one {
        "none"
      } else {
        "set_to_set"
      },
    })
  }
  let semantic_candidates = object_alignment_candidates(before, after)
  for candidate in semantic_candidates {
    if before_used[candidate.before_index] || after_used[candidate.after_index] {
      continue
    }
    if candidate.common_text * 2 < candidate.total_text {
      continue
    }
    let ambiguous = semantic_candidates.any(other => {
      (
        other.before_index == candidate.before_index ||
        other.after_index == candidate.after_index
      ) &&
      (
        other.before_index != candidate.before_index ||
        other.after_index != candidate.after_index
      ) &&
      other.common_text * candidate.total_text ==
      candidate.common_text * other.total_text &&
      other.common_text == candidate.common_text
    })
    if ambiguous {
      continue
    }
    before_used[candidate.before_index] = true
    after_used[candidate.after_index] = true
    let before_id = before.objects[candidate.before_index].summary.id
    let after_id = after.objects[candidate.after_index].summary.id
    alignments.push({
      id: "object-alignment:\{alignments.length()}",
      relation: "correspondence",
      before_object_ids: [before_id],
      after_object_ids: [after_id],
      basis: "semantic_text_overlap/v1",
      ambiguity: "not_calibrated",
    })
  }
  let geometric_candidates : Array[GeometricCandidate] = []
  for before_index, before_object in before.objects {
    if before_used[before_index] {
      continue
    }
    for after_index, after_object in after.objects {
      if after_used[after_index] {
        continue
      }
      guard before_object.summary.bounds is Some(left) &&
        after_object.summary.bounds is Some(right) else {
        continue
      }
      let scale = (left.width.max(right.width) + left.height.max(right.height)).max(
        1.0,
      )
      let center_delta = (left.x +
        left.width * 0.5 -
        right.x -
        right.width * 0.5).abs() +
        (left.y + left.height * 0.5 - right.y - right.height * 0.5).abs()
      let size_delta = (left.width - right.width).abs() +
        (left.height - right.height).abs()
      let same_kind = before_object.summary.primitive_kinds ==
        after_object.summary.primitive_kinds
      if !same_kind {
        continue
      }
      let score = center_delta / scale + size_delta / scale
      let threshold = 0.75
      if score <= threshold {
        geometric_candidates.push({
          before_index,
          after_index,
          score,
          basis: "geometry_and_kind/v1",
        })
      }
    }
  }
  geometric_candidates.sort_by(fn(left, right) {
    if left.score < right.score {
      -1
    } else if left.score > right.score {
      1
    } else if left.before_index != right.before_index {
      left.before_index - right.before_index
    } else {
      left.after_index - right.after_index
    }
  })
  for candidate in geometric_candidates {
    if before_used[candidate.before_index] || after_used[candidate.after_index] {
      continue
    }
    let ambiguous = geometric_candidates.any(other => {
      (
        other.before_index == candidate.before_index ||
        other.after_index == candidate.after_index
      ) &&
      (
        other.before_index != candidate.before_index ||
        other.after_index != candidate.after_index
      ) &&
      (other.score - candidate.score).abs() < 0.02
    })
    if ambiguous {
      continue
    }
    before_used[candidate.before_index] = true
    after_used[candidate.after_index] = true
    alignments.push({
      id: "object-alignment:\{alignments.length()}",
      relation: "correspondence",
      before_object_ids: [before.objects[candidate.before_index].summary.id],
      after_object_ids: [after.objects[candidate.after_index].summary.id],
      basis: candidate.basis,
      ambiguity: "none",
    })
  }
  let remaining_before = [
    for index, object in before.objects if !before_used[index] => {
      object.summary.id
    }
  ]
  let remaining_after = [
    for index, object in after.objects if !after_used[index] => {
      object.summary.id
    }
  ]
  match (remaining_before, remaining_after) {
    ([], []) => ()
    (before_ids, []) =>
      for object_id in before_ids {
        alignments.push({
          id: "object-alignment:\{alignments.length()}",
          relation: "deletion",
          before_object_ids: [object_id],
          after_object_ids: [],
          basis: "unmatched_object",
          ambiguity: "none",
        })
      }
    ([], after_ids) =>
      for object_id in after_ids {
        alignments.push({
          id: "object-alignment:\{alignments.length()}",
          relation: "insertion",
          before_object_ids: [],
          after_object_ids: [object_id],
          basis: "unmatched_object",
          ambiguity: "none",
        })
      }
    (before_ids, after_ids) =>
      alignments.push({
        id: "object-alignment:\{alignments.length()}",
        relation: "unresolved",
        before_object_ids: before_ids,
        after_object_ids: after_ids,
        basis: "no_acceptable_unambiguous_candidate",
        ambiguity: "abstained",
      })
  }
  alignments
}

///|
fn object_by_id(scene : VisualScene, id : String) -> SceneObject? {
  for object in scene.objects {
    if object.summary.id == id {
      return Some(object)
    }
  }
  None
}

///|
fn alignment_bounds_changed(
  before : VisualScene,
  after : VisualScene,
  alignment : @model.VisualObjectAlignment,
) -> Bool {
  guard alignment.before_object_ids is [before_id] &&
    alignment.after_object_ids is [after_id] else {
    return false
  }
  match (object_by_id(before, before_id), object_by_id(after, after_id)) {
    (Some(before_object), Some(after_object)) =>
      match (before_object.summary.bounds, after_object.summary.bounds) {
        (Some(left), Some(right)) =>
          left.x != right.x ||
          left.y != right.y ||
          left.width != right.width ||
          left.height != right.height
        (None, None) => false
        _ => true
      }
    _ => false
  }
}

///|
fn aligned_bounds_changed(
  before : VisualScene,
  after : VisualScene,
  alignments : Array[@model.VisualObjectAlignment],
) -> Bool {
  alignments.any(alignment => alignment_bounds_changed(before, after, alignment))
}

///|
fn shared_axis_aligned_transform(
  before : VisualScene,
  after : VisualScene,
  alignments : Array[@model.VisualObjectAlignment],
) -> Bool {
  let pairs : Array[(@model.VisualObjectBounds, @model.VisualObjectBounds)] = []
  for alignment in alignments {
    guard alignment.before_object_ids is [before_id] &&
      alignment.after_object_ids is [after_id] else {
      continue
    }
    match (object_by_id(before, before_id), object_by_id(after, after_id)) {
      (Some(left), Some(right)) =>
        match (left.summary.bounds, right.summary.bounds) {
          (Some(left_bounds), Some(right_bounds)) if left_bounds.width > 0.0 &&
            left_bounds.height > 0.0 => pairs.push((left_bounds, right_bounds))
          _ => ()
        }
      _ => ()
    }
  }
  if pairs.length() < 2 {
    return false
  }
  let (first_before, first_after) = pairs[0]
  let scale_x = first_after.width / first_before.width
  let scale_y = first_after.height / first_before.height
  let translate_x = first_after.x - first_before.x * scale_x
  let translate_y = first_after.y - first_before.y * scale_y
  pairs.all(pair => {
    let (left, right) = pair
    (right.x - left.x * scale_x - translate_x).abs() <= 0.01 &&
    (right.y - left.y * scale_y - translate_y).abs() <= 0.01 &&
    (right.width - left.width * scale_x).abs() <= 0.01 &&
    (right.height - left.height * scale_y).abs() <= 0.01
  })
}

///|
fn alignment_content(
  scene : VisualScene,
  object_ids : Array[String],
) -> Array[String] {
  let values : Array[String] = []
  for object_id in object_ids {
    match object_by_id(scene, object_id) {
      Some(object) => values.push_iter(object.summary.semantic_text.iter())
      None => ()
    }
  }
  values.sort()
  values
}

///|
fn alignment_content_changed(
  before : VisualScene,
  after : VisualScene,
  alignment : @model.VisualObjectAlignment,
) -> Bool {
  if alignment.relation != "correspondence" &&
    alignment.relation != "equivalence_class" {
    return false
  }
  alignment_content(before, alignment.before_object_ids) !=
  alignment_content(after, alignment.after_object_ids)
}

///|
fn alignment_representation(
  scene : VisualScene,
  object_ids : Array[String],
) -> Array[String] {
  let signatures : Array[String] = []
  for object_id in object_ids {
    match object_by_id(scene, object_id) {
      Some(object) => {
        signatures.push_iter(
          object.summary.primitive_kinds.map(kind => "kind:\{kind}").iter(),
        )
        signatures.push_iter(
          object.summary.symbolic_text.map(text => "symbol:\{text}").iter(),
        )
      }
      None => ()
    }
  }
  signatures.sort()
  signatures
}

///|
fn alignment_representation_changed(
  before : VisualScene,
  after : VisualScene,
  alignment : @model.VisualObjectAlignment,
) -> Bool {
  if alignment.relation != "correspondence" &&
    alignment.relation != "equivalence_class" {
    return false
  }
  alignment_representation(before, alignment.before_object_ids) !=
  alignment_representation(after, alignment.after_object_ids)
}

///|
fn aligned_representation_changed(
  before : VisualScene,
  after : VisualScene,
  alignments : Array[@model.VisualObjectAlignment],
) -> Bool {
  alignments.any(alignment => {
    alignment_representation_changed(before, after, alignment)
  })
}

///|
fn alignment_style_signatures(
  scene : VisualScene,
  object_ids : Array[String],
) -> Array[String] {
  let signatures : Array[String] = []
  for object_id in object_ids {
    match object_by_id(scene, object_id) {
      Some(object) => signatures.push_iter(object.style_signatures.iter())
      None => ()
    }
  }
  signatures.sort()
  signatures
}

///|
fn aligned_style_changed(
  before : VisualScene,
  after : VisualScene,
  alignments : Array[@model.VisualObjectAlignment],
) -> Bool {
  alignments.any(alignment => alignment_style_changed(before, after, alignment))
}

///|
fn alignment_style_changed(
  before : VisualScene,
  after : VisualScene,
  alignment : @model.VisualObjectAlignment,
) -> Bool {
  if alignment.relation != "correspondence" &&
    alignment.relation != "equivalence_class" {
    return false
  }
  alignment_style_signatures(before, alignment.before_object_ids) !=
  alignment_style_signatures(after, alignment.after_object_ids)
}
