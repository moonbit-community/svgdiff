///|
priv struct SourceSubject {
  reference : SubjectReference
  signature : String
  hierarchy_signature : String
  kind : String
  values : Array[(String, String)]
  facts : Array[DeclaredVisualFact]
}

///|
fn visual_subject_kind(kind : String) -> Bool {
  match kind {
    "rect" | "circle" | "ellipse" | "line" | "polyline" | "polygon" => true
    _ => false
  }
}

///|
fn alignment_property_order() -> Array[String] {
  [
    "x", "y", "width", "height", "rx", "ry", "cx", "cy", "r", "x1", "y1", "x2", "y2",
    "points", "fill", "stroke", "stroke-width", "opacity",
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
) -> SourceSubject {
  let facts : Array[DeclaredVisualFact] = []
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
  let values : Array[(String, String)] = []
  for fact in facts {
    values.push((fact.property, fact.declared_value.to_lower()))
  }
  values.sort_by(fn(left, right) { left.0.compare(right.0) })
  let mut signature = "\{element.name.local_name}|hierarchy=\{hierarchy_signature}"
  for item in values {
    let (name, value) = item
    signature = "\{signature}|\{name}=\{value}"
  }
  {
    reference: { source_index, kind: element.name.local_name, authored_id },
    signature,
    hierarchy_signature,
    kind: element.name.local_name,
    values,
    facts,
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
fn extract_source_subjects_or_raise(
  input : String,
) -> Array[SourceSubject] raise {
  let subjects : Array[SourceSubject] = []
  let hierarchy : Array[String] = []
  let reader = @xml.NamespaceReader::from_string(input)
  for event in reader.read_events_until_eof() {
    match event.kind {
      Start(element) => {
        let kind = element.name.local_name
        if kind == "svg" || kind == "g" {
          hierarchy.push(hierarchy_element_signature(input, element))
        } else if visual_subject_kind(kind) {
          subjects.push(
            subject_from_element(
              input,
              element,
              subjects.length(),
              joined_hierarchy_signature(hierarchy),
            ),
          )
        }
      }
      Empty(element) =>
        if visual_subject_kind(element.name.local_name) {
          subjects.push(
            subject_from_element(
              input,
              element,
              subjects.length(),
              joined_hierarchy_signature(hierarchy),
            ),
          )
        }
      End(name) =>
        if name.local_name == "svg" || name.local_name == "g" {
          ignore(hierarchy.pop())
        }
      _ => ()
    }
  }
  subjects
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
) -> SubjectAlignment {
  {
    id: "alignment:\{index}",
    relation,
    before: alignment_refs(before),
    after: alignment_refs(after),
    basis,
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
fn minimum_cost_subject_pairs(
  before_indices : Array[Int],
  after_indices : Array[Int],
  before : Array[SourceSubject],
  after : Array[SourceSubject],
) -> Array[(Int, Int)] {
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
fn align_source_subjects(
  before : Array[SourceSubject],
  after : Array[SourceSubject],
) -> Array[SubjectAlignment] {
  let alignments : Array[SubjectAlignment] = []
  let before_used = Array::make(before.length(), false)
  let after_used = Array::make(after.length(), false)
  for before_index, before_subject in before {
    for after_index, after_subject in after {
      if !before_used[before_index] &&
        !after_used[after_index] &&
        before_subject.signature == after_subject.signature {
        before_used[before_index] = true
        after_used[after_index] = true
        alignments.push(
          make_alignment(
            alignments.length(),
            "correspondence",
            [before_subject],
            [after_subject],
            "exact_visual_signature",
          ),
        )
        break
      }
    }
  }
  for before_index, before_subject in before {
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
        ),
      )
    }
  }
  for after_index, after_subject in after {
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
      pair in minimum_cost_subject_pairs(
        before_indices, after_indices, before, after,
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
        ),
      )
    }
  }
  alignments
}

///|
fn subject_alignments_for_sources(
  before_svg : String,
  after_svg : String,
) -> Array[SubjectAlignment] {
  try
    (
      extract_source_subjects_or_raise(before_svg),
      extract_source_subjects_or_raise(after_svg),
    )
  catch {
    _ => []
  } noraise {
    (before, after) => align_source_subjects(before, after)
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
) -> StructuredReport {
  attach_difference_magnitudes(
    attach_cause_envelopes(
      attach_difference_regions(
        attach_subject_alignments(
          apply_preflight_diagnostics(report, diagnostics),
          alignments,
        ),
        before_svg,
        after_svg,
        alignments,
      ),
    ),
  )
}
