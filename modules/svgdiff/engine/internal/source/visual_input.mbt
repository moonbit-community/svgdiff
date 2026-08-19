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
fn report_span_slice(input : String, span : ReportSourceSpan) -> String {
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
