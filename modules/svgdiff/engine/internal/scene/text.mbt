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
fn normalized_scene_text(value : String) -> String {
  value
  .trim()
  .to_owned()
  .replace_all(old="&lt;", new="<")
  .replace_all(old="&gt;", new=">")
  .replace_all(old="&amp;", new="&")
  .replace_all(old="&quot;", new="\"")
  .replace_all(old="&apos;", new="'")
}

///|
fn symbolic_scene_text(value : String) -> Bool {
  let text = normalized_scene_text(value)
  if text.length() != 1 {
    return false
  }
  match text[0] {
    'A'..='Z' => true
    _ => false
  }
}

///|
fn scene_text_signature(values : Array[String]) -> String {
  let sorted = values.copy()
  sorted.sort()
  sorted.join("\u{1f}")
}

///|
fn multiset_common_count(left : Array[String], right : Array[String]) -> Int {
  let used = Array::make(right.length(), false)
  let mut count = 0
  for value in left {
    for index, candidate in right {
      if !used[index] && value == candidate {
        used[index] = true
        count += 1
        break
      }
    }
  }
  count
}
