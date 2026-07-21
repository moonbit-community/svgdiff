///|
fn parse_alignment_number(value : String?) -> Double? {
  let source = match value {
    Some(value) => value.trim()
    None => return None
  }
  if source == "" {
    return None
  }
  let mut index = 0
  let mut sign = 1.0
  if source[0] == '-' {
    sign = -1.0
    index = 1
  } else if source[0] == '+' {
    index = 1
  }
  let mut result = 0.0
  let mut digits = 0
  while index < source.length() && source[index] >= '0' && source[index] <= '9' {
    result = result * 10.0 + (source[index].to_int() - 48).to_double()
    digits += 1
    index += 1
  }
  if index < source.length() && source[index] == '.' {
    index += 1
    let mut scale = 0.1
    while index < source.length() &&
          source[index] >= '0' &&
          source[index] <= '9' {
      result += (source[index].to_int() - 48).to_double() * scale
      scale *= 0.1
      digits += 1
      index += 1
    }
  }
  if digits == 0 || index != source.length() {
    None
  } else {
    Some(result * sign)
  }
}

///|
fn same_rect_style(left : SourceSubject, right : SourceSubject) -> Bool {
  subject_value(left, "fill") == subject_value(right, "fill") &&
  subject_value(left, "stroke") == subject_value(right, "stroke") &&
  subject_value(left, "stroke-width") == subject_value(right, "stroke-width") &&
  subject_value(left, "opacity") == subject_value(right, "opacity")
}

///|
fn rect_parts_cover(
  whole : SourceSubject,
  parts : Array[SourceSubject],
) -> Bool {
  if whole.kind != "rect" || parts.length() < 2 {
    return false
  }
  let whole_x = parse_alignment_number(subject_value(whole, "x"))
  let whole_y = parse_alignment_number(subject_value(whole, "y"))
  let whole_width = parse_alignment_number(subject_value(whole, "width"))
  let whole_height = parse_alignment_number(subject_value(whole, "height"))
  match (whole_x, whole_y, whole_width, whole_height) {
    (Some(x), Some(y), Some(width), Some(height)) => {
      let sorted = parts.copy()
      sorted.sort_by(fn(left, right) {
        let left_x = parse_alignment_number(subject_value(left, "x")).unwrap_or(
          0.0,
        )
        let right_x = parse_alignment_number(subject_value(right, "x")).unwrap_or(
          0.0,
        )
        left_x.compare(right_x)
      })
      let mut cursor = x
      for part in sorted {
        if part.kind != "rect" || !same_rect_style(whole, part) {
          return false
        }
        match
          (
            parse_alignment_number(subject_value(part, "x")),
            parse_alignment_number(subject_value(part, "y")),
            parse_alignment_number(subject_value(part, "width")),
            parse_alignment_number(subject_value(part, "height")),
          ) {
          (Some(part_x), Some(part_y), Some(part_width), Some(part_height)) => {
            if (part_x - cursor).abs() > 0.000000001 ||
              (part_y - y).abs() > 0.000000001 ||
              (part_height - height).abs() > 0.000000001 {
              return false
            }
            cursor += part_width
          }
          _ => return false
        }
      }
      (cursor - (x + width)).abs() <= 0.000000001
    }
    _ => false
  }
}

///|
fn alignment_refs(subjects : Array[SourceSubject]) -> Array[SubjectReference] {
  [
    for subject in subjects => subject.reference
  ]
}

///|
fn make_alignment(
  index : Int,
  relation : String,
  before : Array[SourceSubject],
  after : Array[SourceSubject],
  basis : String,
  evidence : AlignmentEvidence,
) -> SubjectAlignment {
  {
    id: "alignment:\{index}",
    subject_role: "entity",
    relation,
    before: alignment_refs(before),
    after: alignment_refs(after),
    basis,
    evidence,
  }
}

///|
fn alignment_evidence(
  score_kind : String,
  selected_score : Double?,
  candidate_count : Int,
  equal_score_candidate_count : Int,
  ambiguity : String,
) -> AlignmentEvidence {
  {
    score_kind,
    selected_score,
    candidate_count,
    equal_score_candidate_count,
    ambiguity,
    confidence: None,
    confidence_status: "not_calibrated",
  }
}

///|
fn make_structural_alignment(
  index : Int,
  relation : String,
  before : Array[StructuralAlignmentSubject],
  after : Array[StructuralAlignmentSubject],
  basis : String,
  evidence : AlignmentEvidence,
) -> SubjectAlignment {
  let subject_role = structural_alignment_role(before, after)
  {
    id: "alignment:\{index}",
    subject_role,
    relation,
    before: [
      for subject in before => subject.reference
    ],
    after: [
      for subject in after => subject.reference
    ],
    basis: if subject_role == "resource" {
      resource_alignment_basis(basis)
    } else {
      basis
    },
    evidence: if subject_role == "resource" {
      {
        ..evidence,
        score_kind: resource_alignment_score_kind(evidence.score_kind),
      }
    } else {
      evidence
    },
  }
}

///|
fn structural_selection_evidence(
  score_kind : String,
  candidate_count : Int,
) -> AlignmentEvidence {
  alignment_evidence(
    score_kind,
    None,
    candidate_count,
    candidate_count,
    if candidate_count == 1 {
      "unique"
    } else {
      "tied"
    },
  )
}

///|
fn align_structural_subjects_with_guard(
  before : Array[StructuralAlignmentSubject],
  after : Array[StructuralAlignmentSubject],
  start_index : Int,
  comparison_guard : ComparisonGuard,
) -> Array[SubjectAlignment] raise ComparisonInterrupted {
  let alignments : Array[SubjectAlignment] = []
  let before_used = Array::make(before.length(), false)
  let after_used = Array::make(after.length(), false)
  for before_index, before_subject in before {
    comparison_guard.checkpoint()
    if before_used[before_index] {
      continue
    }
    let before_candidates : Array[Int] = []
    let after_candidates : Array[Int] = []
    for index, subject in before {
      if !before_used[index] &&
        subject.reference.kind == before_subject.reference.kind &&
        subject.semantic_signature == before_subject.semantic_signature {
        before_candidates.push(index)
      }
    }
    for index, subject in after {
      if !after_used[index] &&
        subject.reference.kind == before_subject.reference.kind &&
        subject.semantic_signature == before_subject.semantic_signature {
        after_candidates.push(index)
      }
    }
    if after_candidates.is_empty() ||
      before_candidates.length() != after_candidates.length() {
      continue
    }
    let before_class : Array[StructuralAlignmentSubject] = []
    let after_class : Array[StructuralAlignmentSubject] = []
    for index in before_candidates {
      before_used[index] = true
      before_class.push(before[index])
    }
    for index in after_candidates {
      after_used[index] = true
      after_class.push(after[index])
    }
    alignments.push(
      make_structural_alignment(
        start_index + alignments.length(),
        "correspondence",
        before_class,
        after_class,
        "structural_semantic_signature",
        structural_selection_evidence(
          "structural_semantic_signature",
          before_candidates.length(),
        ),
      ),
    )
  }
  for before_index, before_subject in before {
    comparison_guard.checkpoint()
    if before_used[before_index] {
      continue
    }
    guard before_subject.reference.authored_id is Some(authored_id) else {
      continue
    }
    let candidates : Array[Int] = []
    for after_index, after_subject in after {
      if !after_used[after_index] &&
        after_subject.reference.kind == before_subject.reference.kind &&
        after_subject.reference.authored_id == Some(authored_id) {
        candidates.push(after_index)
      }
    }
    if candidates.is_empty() {
      continue
    }
    let after_index = candidates[0]
    let mut before_count = 0
    let mut after_count = 0
    for subject in before {
      if subject.reference.kind == before_subject.reference.kind &&
        subject.reference.authored_id == Some(authored_id) {
        before_count += 1
      }
    }
    for subject in after {
      if subject.reference.kind == before_subject.reference.kind &&
        subject.reference.authored_id == Some(authored_id) {
        after_count += 1
      }
    }
    let candidate_count = if before_count > after_count {
      before_count
    } else {
      after_count
    }
    before_used[before_index] = true
    after_used[after_index] = true
    alignments.push(
      make_structural_alignment(
        start_index + alignments.length(),
        "correspondence",
        [before_subject],
        [after[after_index]],
        "structural_authored_id",
        structural_selection_evidence("structural_authored_id", candidate_count),
      ),
    )
  }
  for before_index, before_subject in before {
    comparison_guard.checkpoint()
    if before_used[before_index] {
      continue
    }
    let candidates : Array[Int] = []
    for after_index, after_subject in after {
      if !after_used[after_index] &&
        after_subject.reference.kind == before_subject.reference.kind &&
        after_subject.path_signature == before_subject.path_signature {
        candidates.push(after_index)
      }
    }
    if candidates.is_empty() {
      continue
    }
    let after_index = candidates[0]
    before_used[before_index] = true
    after_used[after_index] = true
    alignments.push(
      make_structural_alignment(
        start_index + alignments.length(),
        "correspondence",
        [before_subject],
        [after[after_index]],
        "structural_path",
        structural_selection_evidence("structural_path", candidates.length()),
      ),
    )
  }
  let unmatched_kinds : Array[String] = []
  for index, subject in before {
    if !before_used[index] && !unmatched_kinds.contains(subject.reference.kind) {
      unmatched_kinds.push(subject.reference.kind)
    }
  }
  for index, subject in after {
    if !after_used[index] && !unmatched_kinds.contains(subject.reference.kind) {
      unmatched_kinds.push(subject.reference.kind)
    }
  }
  unmatched_kinds.sort()
  for kind in unmatched_kinds {
    comparison_guard.checkpoint()
    let before_indices : Array[Int] = []
    let after_indices : Array[Int] = []
    for index, subject in before {
      if !before_used[index] && subject.reference.kind == kind {
        before_indices.push(index)
      }
    }
    for index, subject in after {
      if !after_used[index] && subject.reference.kind == kind {
        after_indices.push(index)
      }
    }
    let pair_count = if before_indices.length() < after_indices.length() {
      before_indices.length()
    } else {
      after_indices.length()
    }
    let candidate_count = if before_indices.length() > after_indices.length() {
      before_indices.length()
    } else {
      after_indices.length()
    }
    for pair_index in 0..<pair_count {
      let before_index = before_indices[pair_index]
      let after_index = after_indices[pair_index]
      before_used[before_index] = true
      after_used[after_index] = true
      alignments.push(
        make_structural_alignment(
          start_index + alignments.length(),
          "correspondence",
          [before[before_index]],
          [after[after_index]],
          "stable_kind_order",
          structural_selection_evidence("stable_kind_order", candidate_count),
        ),
      )
    }
  }
  for index, subject in before {
    if !before_used[index] {
      alignments.push(
        make_structural_alignment(
          start_index + alignments.length(),
          "deletion",
          [subject],
          [],
          "unmatched_structural_subject",
          alignment_evidence("unmatched", None, 0, 0, "not_assessed"),
        ),
      )
    }
  }
  for index, subject in after {
    if !after_used[index] {
      alignments.push(
        make_structural_alignment(
          start_index + alignments.length(),
          "insertion",
          [],
          [subject],
          "unmatched_structural_subject",
          alignment_evidence("unmatched", None, 0, 0, "not_assessed"),
        ),
      )
    }
  }
  alignments
}

///|
fn subject_distance(
  left : SourceSubject,
  right : SourceSubject,
  profile : ComparisonProfile,
) -> Double {
  subject_alignment_feature_distance(left, right, profile)
}

///|
fn sort_subject_indices(
  indices : Array[Int],
  subjects : Array[SourceSubject],
) -> Unit {
  indices.sort_by(fn(left, right) {
    let signature_order = exact_subject_alignment_signature(subjects[left]).compare(
      exact_subject_alignment_signature(subjects[right]),
    )
    if signature_order != 0 {
      signature_order
    } else {
      left - right
    }
  })
}

///|
fn minimum_cost_subject_pairs_with_guard(
  before_indices : Array[Int],
  after_indices : Array[Int],
  before : Array[SourceSubject],
  after : Array[SourceSubject],
  profile : ComparisonProfile,
  comparison_guard : ComparisonGuard,
) -> Array[(Int, Int)] raise ComparisonInterrupted {
  if before_indices.is_empty() || after_indices.is_empty() {
    return []
  }
  let transposed = before_indices.length() > after_indices.length()
  let rows = if transposed { after_indices } else { before_indices }
  let columns = if transposed { before_indices } else { after_indices }
  let row_count = rows.length()
  let column_count = columns.length()
  let row_potential = Array::make(row_count + 1, 0.0)
  let column_potential = Array::make(column_count + 1, 0.0)
  let matching = Array::make(column_count + 1, 0)
  let predecessor = Array::make(column_count + 1, 0)
  for row in 1..<=row_count {
    comparison_guard.checkpoint()
    matching[0] = row
    let minimum = Array::make(column_count + 1, 1.7976931348623157e308)
    let used = Array::make(column_count + 1, false)
    let mut column = 0
    while true {
      used[column] = true
      let current_row = matching[column]
      let mut delta = 1.7976931348623157e308
      let mut next_column = 0
      for candidate in 1..<=column_count {
        if used[candidate] {
          continue
        }
        let cost = if transposed {
          subject_distance(
            before[columns[candidate - 1]],
            after[rows[current_row - 1]],
            profile,
          )
        } else {
          subject_distance(
            before[rows[current_row - 1]],
            after[columns[candidate - 1]],
            profile,
          )
        }
        let reduced = cost -
          row_potential[current_row] -
          column_potential[candidate]
        if reduced < minimum[candidate] {
          minimum[candidate] = reduced
          predecessor[candidate] = column
        }
        if minimum[candidate] < delta {
          delta = minimum[candidate]
          next_column = candidate
        }
      }
      for candidate in 0..<=column_count {
        if used[candidate] {
          row_potential[matching[candidate]] += delta
          column_potential[candidate] -= delta
        } else {
          minimum[candidate] -= delta
        }
      }
      column = next_column
      if matching[column] == 0 {
        break
      }
    }
    while true {
      let previous = predecessor[column]
      matching[column] = matching[previous]
      column = previous
      if column == 0 {
        break
      }
    }
  }
  let pairs : Array[(Int, Int)] = []
  for column in 1..<=column_count {
    if matching[column] == 0 {
      continue
    }
    if transposed {
      pairs.push((columns[column - 1], rows[matching[column] - 1]))
    } else {
      pairs.push((rows[matching[column] - 1], columns[column - 1]))
    }
  }
  pairs.sort_by(fn(left, right) {
    let (left_before, left_after) = left
    let (right_before, right_after) = right
    let before_order = left_before - right_before
    if before_order != 0 {
      before_order
    } else {
      left_after - right_after
    }
  })
  pairs
}

///|
fn align_source_subjects_with_guard(
  before : Array[SourceSubject],
  after : Array[SourceSubject],
  profile : ComparisonProfile,
  comparison_guard : ComparisonGuard,
) -> Array[SubjectAlignment] raise ComparisonInterrupted {
  let alignments : Array[SubjectAlignment] = []
  let before_used = Array::make(before.length(), false)
  let after_used = Array::make(after.length(), false)
  for before_index, before_subject in before {
    comparison_guard.checkpoint()
    guard before_subject.reference.instance_context is Some(before_instance) else {
      continue
    }
    for after_index, after_subject in after {
      if after_used[after_index] || before_subject.kind != after_subject.kind {
        continue
      }
      guard after_subject.reference.instance_context is Some(after_instance) else {
        continue
      }
      if before_instance.use_path == after_instance.use_path {
        before_used[before_index] = true
        after_used[after_index] = true
        alignments.push(
          make_alignment(
            alignments.length(),
            "correspondence",
            [before_subject],
            [after_subject],
            "use_instance_path",
            alignment_evidence("structural_rule", None, 0, 0, "not_assessed"),
          ),
        )
        break
      }
    }
  }
  for before_index, before_subject in before {
    comparison_guard.checkpoint()
    if before_used[before_index] {
      continue
    }
    let signature = repeated_subject_equivalence_signature(before_subject)
    let before_candidates : Array[Int] = []
    let after_candidates : Array[Int] = []
    for index, subject in before {
      if !before_used[index] &&
        repeated_subject_equivalence_signature(subject) == signature {
        before_candidates.push(index)
      }
    }
    for index, subject in after {
      if !after_used[index] &&
        repeated_subject_equivalence_signature(subject) == signature {
        after_candidates.push(index)
      }
    }
    if before_candidates.length() > 1 &&
      before_candidates.length() == after_candidates.length() {
      let before_class : Array[SourceSubject] = []
      let after_class : Array[SourceSubject] = []
      for index in before_candidates {
        before_used[index] = true
        before_class.push(before[index])
      }
      for index in after_candidates {
        after_used[index] = true
        after_class.push(after[index])
      }
      alignments.push(
        make_alignment(
          alignments.length(),
          "correspondence",
          before_class,
          after_class,
          "exact_visual_equivalence_class",
          alignment_evidence(
            "exact_visual_signature",
            Some(0.0),
            before_candidates.length(),
            before_candidates.length(),
            "tied",
          ),
        ),
      )
      continue
    }
    let candidates = [
      for after_index, after_subject in after if !after_used[after_index] &&
      exact_subject_alignment_signature(before_subject) ==
      exact_subject_alignment_signature(after_subject) => after_index
    ]
    if !candidates.is_empty() {
      let after_index = candidates[0]
      let mut before_signature_count = 0
      let mut after_signature_count = 0
      for subject in before {
        if exact_subject_alignment_signature(subject) ==
          exact_subject_alignment_signature(before_subject) {
          before_signature_count += 1
        }
      }
      for subject in after {
        if exact_subject_alignment_signature(subject) ==
          exact_subject_alignment_signature(before_subject) {
          after_signature_count += 1
        }
      }
      let equal_score_candidate_count = if before_signature_count >
        after_signature_count {
        before_signature_count
      } else {
        after_signature_count
      }
      before_used[before_index] = true
      after_used[after_index] = true
      alignments.push(
        make_alignment(
          alignments.length(),
          "correspondence",
          [before_subject],
          [after[after_index]],
          "exact_visual_signature",
          alignment_evidence(
            "exact_visual_signature",
            Some(0.0),
            equal_score_candidate_count,
            equal_score_candidate_count,
            if equal_score_candidate_count == 1 {
              "unique"
            } else {
              "tied"
            },
          ),
        ),
      )
    }
  }
  for before_index, before_subject in before {
    comparison_guard.checkpoint()
    if before_used[before_index] || before_subject.kind != "rect" {
      continue
    }
    let candidates : Array[SourceSubject] = []
    let candidate_indices : Array[Int] = []
    for after_index, after_subject in after {
      if !after_used[after_index] &&
        after_subject.kind == "rect" &&
        same_rect_style(before_subject, after_subject) {
        candidates.push(after_subject)
        candidate_indices.push(after_index)
      }
    }
    if rect_parts_cover(before_subject, candidates) {
      before_used[before_index] = true
      for index in candidate_indices {
        after_used[index] = true
      }
      alignments.push(
        make_alignment(
          alignments.length(),
          "split",
          [before_subject],
          candidates,
          "equivalent_rect_coverage",
          alignment_evidence("structural_rule", None, 0, 0, "not_assessed"),
        ),
      )
    }
  }
  for after_index, after_subject in after {
    comparison_guard.checkpoint()
    if after_used[after_index] || after_subject.kind != "rect" {
      continue
    }
    let candidates : Array[SourceSubject] = []
    let candidate_indices : Array[Int] = []
    for before_index, before_subject in before {
      if !before_used[before_index] &&
        before_subject.kind == "rect" &&
        same_rect_style(after_subject, before_subject) {
        candidates.push(before_subject)
        candidate_indices.push(before_index)
      }
    }
    if rect_parts_cover(after_subject, candidates) {
      after_used[after_index] = true
      for index in candidate_indices {
        before_used[index] = true
      }
      alignments.push(
        make_alignment(
          alignments.length(),
          "merge",
          candidates,
          [after_subject],
          "equivalent_rect_coverage",
          alignment_evidence("structural_rule", None, 0, 0, "not_assessed"),
        ),
      )
    }
  }
  let unmatched_kinds : Array[String] = []
  for index, subject in before {
    if !before_used[index] && !unmatched_kinds.contains(subject.kind) {
      unmatched_kinds.push(subject.kind)
    }
  }
  for index, subject in after {
    if !after_used[index] && !unmatched_kinds.contains(subject.kind) {
      unmatched_kinds.push(subject.kind)
    }
  }
  unmatched_kinds.sort()
  for kind in unmatched_kinds {
    let before_indices : Array[Int] = []
    for index, subject in before {
      if !before_used[index] && subject.kind == kind {
        before_indices.push(index)
      }
    }
    let after_indices : Array[Int] = []
    for index, subject in after {
      if !after_used[index] && subject.kind == kind {
        after_indices.push(index)
      }
    }
    sort_subject_indices(before_indices, before)
    sort_subject_indices(after_indices, after)
    for
      pair in minimum_cost_subject_pairs_with_guard(
        before_indices, after_indices, before, after, profile, comparison_guard,
      ) {
      let (before_index, after_index) = pair
      before_used[before_index] = true
      after_used[after_index] = true
      alignments.push(
        make_alignment(
          alignments.length(),
          "correspondence",
          [before[before_index]],
          [after[after_index]],
          "minimum_rendered_geometry_distance",
          {
            let selected_score = subject_distance(
              before[before_index],
              after[after_index],
              profile,
            )
            let compatible = if before_indices.length() > after_indices.length() {
              before_indices.length()
            } else {
              after_indices.length()
            }
            let mut equal_scores = 0
            if before_indices.length() > after_indices.length() {
              for index in before_indices {
                if subject_distance(before[index], after[after_index], profile) ==
                  selected_score {
                  equal_scores += 1
                }
              }
            } else {
              for index in after_indices {
                if subject_distance(before[before_index], after[index], profile) ==
                  selected_score {
                  equal_scores += 1
                }
              }
            }
            alignment_evidence(
              "rendered_geometry_feature_distance_v1",
              Some(selected_score),
              compatible,
              equal_scores,
              if equal_scores == 1 {
                "unique"
              } else {
                "tied"
              },
            )
          },
        ),
      )
    }
  }
  for index, subject in before {
    if !before_used[index] {
      alignments.push(
        make_alignment(
          alignments.length(),
          "deletion",
          [subject],
          [],
          "unmatched_subject",
          alignment_evidence("unmatched", None, 0, 0, "not_assessed"),
        ),
      )
    }
  }
  for index, subject in after {
    if !after_used[index] {
      alignments.push(
        make_alignment(
          alignments.length(),
          "insertion",
          [],
          [subject],
          "unmatched_subject",
          alignment_evidence("unmatched", None, 0, 0, "not_assessed"),
        ),
      )
    }
  }
  alignments
}
