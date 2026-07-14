///|
priv struct SourceSubject {
  reference : SubjectReference
  signature : String
  hierarchy_signature : String
  kind : String
  values : Array[(String, String)]
  facts : Array[DeclaredVisualFact]
  geometry_invalid_facts : Array[DeclaredVisualFact]
  geometry_complete : Bool
  fillable_interior : Bool
  renders_geometry : Bool
  stroke_invalid_facts : Array[DeclaredVisualFact]
  stroke_complete : Bool
  stroke_paint_present : Bool
  stroke_path_present : Bool
  stroke_active : Bool
  stroke_conservative_expansion : Double
  stroke_non_scaling : Bool
  path_segments : Array[PathSegmentEvidence]
  path_data_complete : Bool
  transform_chain : Array[SourceTransformSite]
  cumulative_transform : AffineTransform
  transform_complete : Bool
}

///|
fn visual_subject_kind(kind : String) -> Bool {
  match kind {
    "rect" | "circle" | "ellipse" | "line" | "polyline" | "polygon" | "path" =>
      true
    _ => false
  }
}

///|
fn alignment_property_order() -> Array[String] {
  [
    "x", "y", "width", "height", "rx", "ry", "cx", "cy", "r", "x1", "y1", "x2", "y2",
    "points", "fill", "stroke", "stroke-width", "stroke-linecap", "stroke-linejoin",
    "stroke-miterlimit", "stroke-dasharray", "stroke-dashoffset", "vector-effect",
    "opacity",
  ]
}

///|
fn subject_value(subject : SourceSubject, property : String) -> String? {
  for item in subject.values {
    let (name, value) = item
    if name == property {
      return Some(value)
    }
  }
  None
}

///|
fn subject_from_element(
  input : String,
  element : @xml.NamespaceElement,
  source_index : Int,
  hierarchy_signature : String,
  transform_chain : Array[SourceTransformSite],
) -> SourceSubject {
  let facts : Array[DeclaredVisualFact] = []
  let path_segments : Array[PathSegmentEvidence] = []
  let mut path_data_complete = true
  let mut authored_id : String? = None
  let mut style_attribute : @xml.NamespaceAttribute? = None
  for attribute in element.attributes {
    let name = attribute.name.local_name
    if name == "id" {
      let value = attribute.value.trim().to_owned()
      if value != "" {
        authored_id = Some(value)
      }
    } else if name == "style" {
      style_attribute = Some(attribute)
    } else if name == "transform" {
      upsert_declared_fact(facts, presentation_fact(input, name, attribute))
    } else if element.name.local_name == "path" && name == "d" {
      upsert_declared_fact(facts, presentation_fact(input, name, attribute))
      let authored = source_slice(input, attribute.value_span)
      match
        parse_path_attribute_data(authored, attribute.value_span.start.offset) {
        Valid(segments) => {
          path_segments.push_iter(segments.iter())
          path_data_complete = true
        }
        Invalid => path_data_complete = false
      }
    } else if alignment_property_order().contains(name) {
      upsert_declared_fact(facts, presentation_fact(input, name, attribute))
    }
  }
  match style_attribute {
    Some(attribute) => {
      let style = inline_style_facts(input, attribute)
      for fact in style.facts {
        upsert_declared_fact(facts, fact)
      }
    }
    None => ()
  }
  let geometry = resolve_basic_shape_geometry(element.name.local_name, facts)
  let stroke = resolve_stroke_geometry(facts)
  let values : Array[(String, String)] = []
  for fact in facts {
    if fact.property == "transform" {
      continue
    }
    if !basic_shape_geometry_property(element.name.local_name, fact.property) &&
      !stroke_geometry_property(fact.property) {
      values.push(
        (
          fact.property,
          if fact.property == "d" {
            fact.declared_value
          } else {
            fact.declared_value.to_lower()
          },
        ),
      )
    }
  }
  for value in geometry.values {
    values.push(value)
  }
  for value in stroke.values {
    values.push(value)
  }
  let stroke_paint_present = resolved_stroke_paint_present(facts)
  let stroke_path_present = resolved_stroke_path_present(
    element.name.local_name,
    geometry,
    path_segments,
    stroke,
  )
  let stroke_width = stroke_geometry_number(stroke, "stroke-width")
  let (cumulative_transform, transform_complete, has_transform) = cumulative_transform(
    transform_chain,
  )
  if transform_complete && has_transform {
    values.push(("transform", cumulative_transform.signature()))
  }
  values.sort_by(fn(left, right) { left.0.compare(right.0) })
  let mut signature = "\{element.name.local_name}|hierarchy=\{hierarchy_signature}"
  for item in values {
    let (name, value) = item
    if name != "d" && name != "transform" {
      signature = "\{signature}|\{name}=\{value}"
    }
  }
  if element.name.local_name == "path" {
    signature = "\{signature}|path=\{path_segments_signature(path_segments)}|path-complete=\{path_data_complete}"
  }
  {
    reference: { source_index, kind: element.name.local_name, authored_id },
    signature,
    hierarchy_signature,
    kind: element.name.local_name,
    values,
    facts,
    geometry_invalid_facts: geometry.invalid_facts,
    geometry_complete: geometry.complete,
    fillable_interior: geometry.fillable_interior,
    renders_geometry: geometry.renders_geometry,
    stroke_invalid_facts: stroke.invalid_facts,
    stroke_complete: stroke.complete,
    stroke_paint_present,
    stroke_path_present,
    stroke_active: stroke_paint_present &&
    stroke_path_present &&
    stroke_width > 0.0,
    stroke_conservative_expansion: resolved_stroke_expansion(
      element.name.local_name,
      geometry,
      stroke,
    ),
    stroke_non_scaling: resolved_stroke_value(stroke, "vector-effect") ==
    "non-scaling-stroke",
    path_segments,
    path_data_complete,
    transform_chain,
    cumulative_transform,
    transform_complete,
  }
}

///|
fn hierarchy_element_signature(
  input : String,
  element : @xml.NamespaceElement,
) -> String {
  let facts : Array[DeclaredVisualFact] = []
  let mut style_attribute : @xml.NamespaceAttribute? = None
  for attribute in element.attributes {
    let property = attribute.name.local_name
    if property == "style" {
      style_attribute = Some(attribute)
    } else if inherited_visual_properties().contains(property) {
      upsert_declared_fact(facts, presentation_fact(input, property, attribute))
    }
  }
  match style_attribute {
    Some(attribute) => {
      let style = inline_style_facts(input, attribute)
      for fact in style.facts {
        if inherited_visual_properties().contains(fact.property) {
          upsert_declared_fact(facts, fact)
        }
      }
    }
    None => ()
  }
  facts.sort_by(fn(left, right) { left.property.compare(right.property) })
  let mut signature = element.name.local_name
  for fact in facts {
    signature = "\{signature}|\{fact.property}=\{fact.declared_value.to_lower()}"
  }
  signature
}

///|
fn joined_hierarchy_signature(stack : Array[String]) -> String {
  let mut signature = ""
  for segment in stack {
    if signature == "" {
      signature = segment
    } else {
      signature = "\{signature}/\{segment}"
    }
  }
  signature
}

///|
fn extract_source_subjects_with_profile_or_raise(
  input : String,
  profile : ComparisonProfile,
) -> Array[SourceSubject] raise {
  let subjects : Array[SourceSubject] = []
  let hierarchy : Array[String] = []
  let transforms : Array[SourceTransformSite] = []
  let viewport_contexts : Array[ViewportContext] = []
  let mut node_index = 0
  let reader = @xml.NamespaceReader::from_string(input)
  for event in reader.read_events_until_eof() {
    match event.kind {
      Start(element) => {
        let kind = element.name.local_name
        let parent_viewport = viewport_contexts.last()
        let (transform, child_viewport) = source_transform_site_with_viewport(
          input, element, node_index, profile, parent_viewport,
        )
        node_index += 1
        transforms.push(transform)
        if kind == "svg" || kind == "g" {
          hierarchy.push(hierarchy_element_signature(input, element))
        }
        if kind == "svg" {
          match child_viewport {
            Some(context) => viewport_contexts.push(context)
            None => ()
          }
        }
        if visual_subject_kind(kind) {
          subjects.push(
            subject_from_element(
              input,
              element,
              subjects.length(),
              joined_hierarchy_signature(hierarchy),
              transforms.copy(),
            ),
          )
        }
      }
      Empty(element) => {
        let transform_chain = transforms.copy()
        let (transform, _) = source_transform_site_with_viewport(
          input,
          element,
          node_index,
          profile,
          viewport_contexts.last(),
        )
        transform_chain.push(transform)
        node_index += 1
        if visual_subject_kind(element.name.local_name) {
          subjects.push(
            subject_from_element(
              input,
              element,
              subjects.length(),
              joined_hierarchy_signature(hierarchy),
              transform_chain,
            ),
          )
        }
      }
      End(name) => {
        ignore(transforms.pop())
        if name.local_name == "svg" || name.local_name == "g" {
          ignore(hierarchy.pop())
        }
        if name.local_name == "svg" {
          ignore(viewport_contexts.pop())
        }
      }
      _ => ()
    }
  }
  subjects
}

///|
fn extract_source_subjects_or_raise(
  input : String,
) -> Array[SourceSubject] raise {
  extract_source_subjects_with_profile_or_raise(
    input,
    ComparisonProfile::v1_default(),
  )
}

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
fn subject_distance(left : SourceSubject, right : SourceSubject) -> Double {
  let mut distance = if left.hierarchy_signature == right.hierarchy_signature {
    0.0
  } else {
    1000000.0
  }
  for property in alignment_property_order() {
    let left_value = subject_value(left, property)
    let right_value = subject_value(right, property)
    if left_value != right_value {
      match
        (
          parse_alignment_number(left_value),
          parse_alignment_number(right_value),
        ) {
        (Some(left_number), Some(right_number)) =>
          distance += (left_number - right_number).abs()
        _ => distance += 1000000.0
      }
    }
  }
  if left.kind == "path" && right.kind == "path" {
    if left.path_data_complete != right.path_data_complete {
      distance += 1000000.0
    }
    distance += normalized_path_distance(
      left.path_segments,
      right.path_segments,
    )
  }
  distance
}

///|
fn sort_subject_indices(
  indices : Array[Int],
  subjects : Array[SourceSubject],
) -> Unit {
  indices.sort_by(fn(left, right) {
    let signature_order = subjects[left].signature.compare(
      subjects[right].signature,
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
          )
        } else {
          subject_distance(
            before[rows[current_row - 1]],
            after[columns[candidate - 1]],
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
  pairs
}

///|
fn align_source_subjects_with_guard(
  before : Array[SourceSubject],
  after : Array[SourceSubject],
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
    let candidates = [
      for after_index, after_subject in after if !after_used[after_index] &&
      before_subject.signature == after_subject.signature => after_index
    ]
    if !candidates.is_empty() {
      let after_index = candidates[0]
      let mut before_signature_count = 0
      let mut after_signature_count = 0
      for subject in before {
        if subject.signature == before_subject.signature {
          before_signature_count += 1
        }
      }
      for subject in after {
        if subject.signature == before_subject.signature {
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
        before_indices, after_indices, before, after, comparison_guard,
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
          "minimum_property_distance",
          {
            let selected_score = subject_distance(
              before[before_index],
              after[after_index],
            )
            let compatible = if before_indices.length() > after_indices.length() {
              before_indices.length()
            } else {
              after_indices.length()
            }
            let mut equal_scores = 0
            if before_indices.length() > after_indices.length() {
              for index in before_indices {
                if subject_distance(before[index], after[after_index]) ==
                  selected_score {
                  equal_scores += 1
                }
              }
            } else {
              for index in after_indices {
                if subject_distance(before[before_index], after[index]) ==
                  selected_score {
                  equal_scores += 1
                }
              }
            }
            alignment_evidence(
              "property_distance",
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

///|
fn subject_alignments_for_sources_with_guard(
  before_svg : String,
  after_svg : String,
  comparison_guard : ComparisonGuard,
) -> Array[SubjectAlignment] raise ComparisonInterrupted {
  let subjects = try
    Some(
      (
        extract_source_subjects_or_raise(before_svg),
        extract_source_subjects_or_raise(after_svg),
      ),
    )
  catch {
    _ => None
  } noraise {
    value => value
  }
  match subjects {
    Some((before, after)) =>
      align_source_subjects_with_guard(before, after, comparison_guard)
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
    coverage_matrix: report.coverage_matrix,
    renderer_capability_gaps: report.renderer_capability_gaps,
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
fn finish_report(
  report : StructuredReport,
  diagnostics : Array[Diagnostic],
  alignments : Array[SubjectAlignment],
  before_svg : String,
  after_svg : String,
  limits : ResourceLimits,
  comparison_guard : ComparisonGuard,
) -> StructuredReport raise ComparisonInterrupted {
  comparison_guard.checkpoint()
  let (report, extra_alignments) = attach_group_opacity_differences(
    report, before_svg, after_svg,
  )
  let combined_alignments = alignments.copy()
  combined_alignments.push_iter(extra_alignments.iter())
  comparison_guard.checkpoint()
  let report = apply_preflight_diagnostics(report, diagnostics)
  comparison_guard.checkpoint()
  let report = attach_subject_alignments(report, combined_alignments)
  comparison_guard.checkpoint()
  let report = attach_transform_differences(
    report, before_svg, after_svg, combined_alignments,
  )
  comparison_guard.checkpoint()
  let report = attach_resource_transform_differences(
    report, before_svg, after_svg,
  )
  comparison_guard.checkpoint()
  let report = match
    attach_difference_regions(
      report,
      before_svg,
      after_svg,
      combined_alignments,
      limits.max_regions,
      comparison_guard,
    ) {
    RegionsAttached(report) => report
    AttachmentRegionLimitExceeded =>
      return failed_resource_report(report.profile, [
        resource_limit_diagnostic("regions", None, None),
      ])
  }
  comparison_guard.checkpoint()
  let report = attach_cause_envelopes(report)
  comparison_guard.checkpoint()
  let report = attach_difference_magnitudes(report)
  comparison_guard.checkpoint()
  let report = attach_feature_coverage(report, before_svg, after_svg)
  comparison_guard.checkpoint()
  let report = enforce_coverage_proof(report, before_svg, after_svg)
  comparison_guard.checkpoint()
  let report = attach_renderer_capability_gaps(report)
  comparison_guard.checkpoint()
  let report = attach_diagnostic_fact_locations(report)
  comparison_guard.checkpoint()
  report
}
