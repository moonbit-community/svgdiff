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
pub fn parse_alignment_number(value : String?) -> Double? {
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
