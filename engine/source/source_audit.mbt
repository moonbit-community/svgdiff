///|
let svg_namespace_uri = "http://www.w3.org/2000/svg"

///|
fn svg_nonvisual_content_element(name : @xml.XmlName) -> Bool {
  let admitted_namespace = name.namespace_uri is None ||
    name.namespace_uri == Some(svg_namespace_uri)
  admitted_namespace &&
  (
    name.local_name == "title" ||
    name.local_name == "desc" ||
    name.local_name == "metadata"
  )
}

///|
fn report_span(span : @xml.SourceSpan) -> ReportSourceSpan {
  { start_offset: span.start.offset, end_offset: span.end.offset }
}

///|
pub fn report_span_slice(input : String, span : ReportSourceSpan) -> String {
  "\{input.view(start_offset=span.start_offset, end_offset=span.end_offset)}"
}

///|
fn nonvisual_content_spans_or_raise(
  input : String,
) -> Array[ReportSourceSpan] raise {
  let spans : Array[ReportSourceSpan] = []
  let reader = @xml.NamespaceReader::from_string(input)
  let mut nonvisual_depth = 0
  let mut content_start = 0
  for event in reader.read_events_until_eof() {
    match event.kind {
      Start(element) if nonvisual_depth == 0 &&
        svg_nonvisual_content_element(element.name) => {
        nonvisual_depth = 1
        content_start = event.span.end.offset
      }
      Start(_) if nonvisual_depth > 0 => nonvisual_depth += 1
      End(_) if nonvisual_depth > 0 => {
        nonvisual_depth -= 1
        if nonvisual_depth == 0 {
          spans.push({
            start_offset: content_start,
            end_offset: event.span.start.offset,
          })
        }
      }
      _ => ()
    }
  }
  spans
}

///|
pub fn visual_semantic_input(input : String) -> String {
  let spans = nonvisual_content_spans_or_raise(input) catch {
    _ => return input
  }
  if spans.is_empty() {
    return input
  }
  let output = StringBuilder::new()
  let mut cursor = 0
  for span in spans {
    output.write_string(
      report_span_slice(input, {
        start_offset: cursor,
        end_offset: span.start_offset,
      }),
    )
    output.write_string(String::make(span.end_offset - span.start_offset, ' '))
    cursor = span.end_offset
  }
  output.write_string(
    report_span_slice(input, {
      start_offset: cursor,
      end_offset: input.length(),
    }),
  )
  output.to_string()
}

///|
priv struct SourceAuditPathFrame {
  path : String
  child_names : Array[String]
  child_counts : Array[Int]
}

///|
fn source_audit_expanded_name(name : @xml.XmlName) -> String {
  match name.namespace_uri {
    Some(namespace_uri) => "{\{namespace_uri}}\{name.local_name}"
    None => name.local_name
  }
}

///|
fn source_audit_child_path(
  frame : SourceAuditPathFrame,
  name : @xml.XmlName,
) -> String {
  let expanded = source_audit_expanded_name(name)
  let mut index = 0
  while index < frame.child_names.length() {
    if frame.child_names[index] == expanded {
      frame.child_counts[index] += 1
      return "\{frame.path}/\{expanded}[\{frame.child_counts[index]}]"
    }
    index += 1
  }
  frame.child_names.push(expanded)
  frame.child_counts.push(1)
  "\{frame.path}/\{expanded}[1]"
}

///|
fn source_audit_metadata_attribute(attribute : @xml.NamespaceAttribute) -> Bool {
  attribute.name.prefix is None &&
  (
    attribute.name.local_name.has_prefix("aria-") ||
    attribute.name.local_name.has_prefix("data-")
  )
}

///|
/// One exact authored fact in the optional nonvisual source audit.
pub(all) struct SourceAuditFact {
  kind : String
  path : String
  name : String
  authored_value : String
  source_span : ReportSourceSpan
} derive(ToJson)

///|
/// One changed, inserted, or deleted nonvisual source fact.
pub(all) struct SourceAuditDifference {
  id : String
  kind : String
  path : String
  name : String
  before : SourceAuditFact?
  after : SourceAuditFact?
} derive(ToJson)

///|
/// A bounded parse failure from one side of a source-only audit.
pub(all) struct SourceAuditDiagnostic {
  code : String
  source_role : String
  source_span : ReportSourceSpan?
} derive(ToJson)

///|
/// An independently versioned source-only nonvisual metadata audit.
pub(all) struct SourceAuditReport {
  audit_schema_version : String
  analysis_status : String
  differences : Array[SourceAuditDifference]
  diagnostics : Array[SourceAuditDiagnostic]
} derive(ToJson)

///|
/// Serialize this source audit as indented JSON.
pub fn SourceAuditReport::to_json_string(self : SourceAuditReport) -> String {
  ToJson::to_json(self).stringify(indent=2)
}

///|
/// Serialize this source audit without presentation whitespace.
pub fn SourceAuditReport::to_compact_json_string(
  self : SourceAuditReport,
) -> String {
  ToJson::to_json(self).stringify()
}

///|
priv struct OpenSourceAuditContent {
  kind : String
  path : String
  name : String
  start_offset : Int
}

///|
fn collect_nonvisual_source_facts_or_raise(
  input : String,
) -> Array[SourceAuditFact] raise {
  let facts : Array[SourceAuditFact] = []
  let frames : Array[SourceAuditPathFrame] = [
    { path: "", child_names: [], child_counts: [] },
  ]
  let reader = @xml.NamespaceReader::from_string(input)
  let mut nonvisual_depth = 0
  let mut open_content : OpenSourceAuditContent? = None
  for event in reader.read_events_until_eof() {
    match event.kind {
      Start(element) => {
        let path = source_audit_child_path(
          frames[frames.length() - 1],
          element.name,
        )
        if nonvisual_depth == 0 {
          if svg_nonvisual_content_element(element.name) {
            nonvisual_depth = 1
            open_content = Some({
              kind: "element_content",
              path,
              name: source_audit_expanded_name(element.name),
              start_offset: event.span.end.offset,
            })
          } else {
            for attribute in element.attributes {
              if source_audit_metadata_attribute(attribute) {
                let span = report_span(attribute.value_span)
                facts.push({
                  kind: "attribute",
                  path,
                  name: source_audit_expanded_name(attribute.name),
                  authored_value: report_span_slice(input, span),
                  source_span: span,
                })
              }
            }
          }
        } else {
          nonvisual_depth += 1
        }
        frames.push({ path, child_names: [], child_counts: [] })
      }
      Empty(element) => {
        let path = source_audit_child_path(
          frames[frames.length() - 1],
          element.name,
        )
        if nonvisual_depth == 0 {
          if svg_nonvisual_content_element(element.name) {
            let content_offset = event.span.end.offset - 2
            facts.push({
              kind: "element_content",
              path,
              name: source_audit_expanded_name(element.name),
              authored_value: "",
              source_span: {
                start_offset: content_offset,
                end_offset: content_offset,
              },
            })
          } else {
            for attribute in element.attributes {
              if source_audit_metadata_attribute(attribute) {
                let span = report_span(attribute.value_span)
                facts.push({
                  kind: "attribute",
                  path,
                  name: source_audit_expanded_name(attribute.name),
                  authored_value: report_span_slice(input, span),
                  source_span: span,
                })
              }
            }
          }
        }
      }
      End(_) => {
        if nonvisual_depth > 0 {
          nonvisual_depth -= 1
          if nonvisual_depth == 0 {
            match open_content {
              Some(content) => {
                let span : ReportSourceSpan = {
                  start_offset: content.start_offset,
                  end_offset: event.span.start.offset,
                }
                facts.push({
                  kind: content.kind,
                  path: content.path,
                  name: content.name,
                  authored_value: report_span_slice(input, span),
                  source_span: span,
                })
              }
              None => ()
            }
            open_content = None
          }
        }
        ignore(frames.pop())
      }
      _ => ()
    }
  }
  facts.sort_by(fn(left, right) {
    source_audit_fact_key(left).compare(source_audit_fact_key(right))
  })
  facts
}

///|
fn source_audit_fact_key(fact : SourceAuditFact) -> String {
  "\{fact.kind}\u{0}\{fact.path}\u{0}\{fact.name}"
}

///|
fn source_audit_fact_by_key(
  facts : Array[SourceAuditFact],
  key : String,
) -> SourceAuditFact? {
  for fact in facts {
    if source_audit_fact_key(fact) == key {
      return Some(fact)
    }
  }
  None
}

///|
priv enum SourceAuditCollection {
  SourceAuditCollected(Array[SourceAuditFact])
  SourceAuditParseFailed(SourceAuditDiagnostic)
}

///|
fn collect_nonvisual_source_facts(
  input : String,
  source_role : String,
) -> SourceAuditCollection {
  try collect_nonvisual_source_facts_or_raise(input) catch {
    @xml.At(error=_, span~) =>
      SourceAuditParseFailed({
        code: "svg_parse_failed",
        source_role,
        source_span: Some(report_span(span)),
      })
    _ =>
      SourceAuditParseFailed({
        code: "svg_parse_failed",
        source_role,
        source_span: None,
      })
  } noraise {
    facts => SourceAuditCollected(facts)
  }
}

///|
/// Audit nonvisual SVG metadata independently from visual comparison.
pub fn audit_nonvisual_metadata(
  before_svg : String,
  after_svg : String,
) -> SourceAuditReport {
  let before = collect_nonvisual_source_facts(before_svg, "before")
  let after = collect_nonvisual_source_facts(after_svg, "after")
  let diagnostics : Array[SourceAuditDiagnostic] = []
  let before_facts = match before {
    SourceAuditCollected(facts) => facts
    SourceAuditParseFailed(diagnostic) => {
      diagnostics.push(diagnostic)
      []
    }
  }
  let after_facts = match after {
    SourceAuditCollected(facts) => facts
    SourceAuditParseFailed(diagnostic) => {
      diagnostics.push(diagnostic)
      []
    }
  }
  if !diagnostics.is_empty() {
    return {
      audit_schema_version: "1.0",
      analysis_status: "failed",
      differences: [],
      diagnostics,
    }
  }
  let keys : Array[String] = []
  for fact in before_facts + after_facts {
    let key = source_audit_fact_key(fact)
    if !keys.contains(key) {
      keys.push(key)
    }
  }
  keys.sort()
  let differences : Array[SourceAuditDifference] = []
  for key in keys {
    let before_fact = source_audit_fact_by_key(before_facts, key)
    let after_fact = source_audit_fact_by_key(after_facts, key)
    if before_fact.map(fact => fact.authored_value) ==
      after_fact.map(fact => fact.authored_value) {
      continue
    }
    let template = match (before_fact, after_fact) {
      (Some(fact), _) | (_, Some(fact)) => fact
      _ => abort("source audit key has no fact")
    }
    differences.push({
      id: "source-audit:\{differences.length()}",
      kind: template.kind,
      path: template.path,
      name: template.name,
      before: before_fact,
      after: after_fact,
    })
  }
  {
    audit_schema_version: "1.0",
    analysis_status: "complete",
    differences,
    diagnostics: [],
  }
}
