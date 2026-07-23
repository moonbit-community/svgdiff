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
fn percent_hex_value(character : Char) -> Int? {
  if character >= '0' && character <= '9' {
    Some(character.to_int() - '0'.to_int())
  } else if character >= 'a' && character <= 'f' {
    Some(10 + character.to_int() - 'a'.to_int())
  } else if character >= 'A' && character <= 'F' {
    Some(10 + character.to_int() - 'A'.to_int())
  } else {
    None
  }
}

///|
pub fn decode_local_fragment(value : String) -> String {
  let output = StringBuilder::new()
  let mut index = 0
  while index < value.length() {
    let character = value[index].unsafe_to_char()
    if character == '%' && index + 2 < value.length() {
      match
        (
          percent_hex_value(value[index + 1].unsafe_to_char()),
          percent_hex_value(value[index + 2].unsafe_to_char()),
        ) {
        (Some(high), Some(low)) => {
          output.write_char((high * 16 + low).unsafe_to_char())
          index += 3
          continue
        }
        _ => ()
      }
    }
    output.write_char(character)
    index += 1
  }
  output.to_string()
}

///|
pub fn local_href_target(value : String) -> String? {
  let normalized = value.trim().to_owned()
  if normalized.length() <= 1 || normalized[0].unsafe_to_char() != '#' {
    return None
  }
  Some(
    decode_local_fragment(
      normalized.view(start_offset=1, end_offset=normalized.length()).to_owned(),
    ),
  )
}

///|
pub fn ascii_url_start(value : String, index : Int) -> Bool {
  if index + 3 >= value.length() {
    return false
  }
  let u = value[index].unsafe_to_char()
  let r = value[index + 1].unsafe_to_char()
  let l = value[index + 2].unsafe_to_char()
  (u == 'u' || u == 'U') &&
  (r == 'r' || r == 'R') &&
  (l == 'l' || l == 'L') &&
  value[index + 3].unsafe_to_char() == '('
}

///|
pub fn ascii_reference_whitespace(character : Char) -> Bool {
  character == ' ' ||
  character == '\t' ||
  character == '\n' ||
  character == '\r' ||
  character == '\u000c'
}

///|
pub(all) struct ParsedResourceLocator {
  kind : String
  locator : String
  target_id : String?
}

///|
pub fn parse_resource_locator(value : String) -> ParsedResourceLocator {
  let locator = value.trim().to_owned()
  if locator == "" || locator == "#" {
    return { kind: "invalid", locator, target_id: None }
  }
  if locator.has_prefix("#") {
    return {
      kind: "local",
      locator,
      target_id: Some(
        decode_local_fragment(locator.view(start_offset=1).to_owned()),
      ),
    }
  }
  if locator.to_lower().has_prefix("data:") {
    { kind: "data", locator, target_id: None }
  } else {
    { kind: "external", locator, target_id: None }
  }
}

///|
pub fn resource_url_locators(value : String) -> Array[ParsedResourceLocator] {
  let locators : Array[ParsedResourceLocator] = []
  let mut index = 0
  while index < value.length() {
    if !ascii_url_start(value, index) {
      index += 1
      continue
    }
    let start = index + 4
    let mut cursor = start
    while cursor < value.length() && value[cursor].unsafe_to_char() != ')' {
      cursor += 1
    }
    if cursor >= value.length() {
      locators.push({
        kind: "invalid",
        locator: value.view(start_offset=start).to_owned().trim().to_owned(),
        target_id: None,
      })
      break
    }
    let mut locator = value
      .view(start_offset=start, end_offset=cursor)
      .to_owned()
      .trim()
      .to_owned()
    if locator.length() >= 2 &&
      (
        (locator.has_prefix("'") && locator.has_suffix("'")) ||
        (locator.has_prefix("\"") && locator.has_suffix("\""))
      ) {
      locator = locator
        .view(start_offset=1, end_offset=locator.length() - 1)
        .to_owned()
        .trim()
        .to_owned()
    } else if locator.has_prefix("'") ||
      locator.has_suffix("'") ||
      locator.has_prefix("\"") ||
      locator.has_suffix("\"") {
      locators.push({ kind: "invalid", locator, target_id: None })
      index = cursor + 1
      continue
    }
    locators.push(parse_resource_locator(locator))
    index = cursor + 1
  }
  locators
}
