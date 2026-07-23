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
/// A cursor over one source string for SVG-style finite numbers.
pub(all) struct NumberParser {
  data : String
  mut position : Int
}

///|
fn number_is_whitespace(unit : UInt16) -> Bool {
  unit == ' ' || unit == '\t' || unit == '\n' || unit == '\r'
}

///|
fn number_is_digit(unit : UInt16) -> Bool {
  unit >= '0' && unit <= '9'
}

///|
/// Advance past XML/SVG whitespace and report whether any was consumed.
pub fn NumberParser::skip_whitespace(self : NumberParser) -> Bool {
  let start = self.position
  while self.position < self.data.length() &&
        number_is_whitespace(self.data[self.position]) {
    self.position += 1
  }
  self.position > start
}

///|
/// Parse one finite SVG-style number, restoring the cursor on failure.
pub fn NumberParser::parse_number(self : NumberParser) -> Double? {
  let start = self.position
  if self.position < self.data.length() &&
    (self.data[self.position] == '+' || self.data[self.position] == '-') {
    self.position += 1
  }
  let mut digits = 0
  while self.position < self.data.length() &&
        number_is_digit(self.data[self.position]) {
    self.position += 1
    digits += 1
  }
  if self.position < self.data.length() && self.data[self.position] == '.' {
    self.position += 1
    while self.position < self.data.length() &&
          number_is_digit(self.data[self.position]) {
      self.position += 1
      digits += 1
    }
  }
  if digits == 0 {
    self.position = start
    return None
  }
  if self.position < self.data.length() &&
    (self.data[self.position] == 'e' || self.data[self.position] == 'E') {
    self.position += 1
    if self.position < self.data.length() &&
      (self.data[self.position] == '+' || self.data[self.position] == '-') {
      self.position += 1
    }
    let exponent_start = self.position
    while self.position < self.data.length() &&
          number_is_digit(self.data[self.position]) {
      self.position += 1
    }
    if self.position == exponent_start {
      self.position = start
      return None
    }
  }
  let value = try
    @string.parse_double(
      self.data.view(start_offset=start, end_offset=self.position),
    )
  catch {
    _ => {
      self.position = start
      return None
    }
  } noraise {
    value => value
  }
  if value.is_inf() || value.is_nan() {
    self.position = start
    None
  } else {
    Some(value)
  }
}
