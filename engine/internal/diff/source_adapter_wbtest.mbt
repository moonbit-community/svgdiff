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
test "source adapter preserves authored direct text" {
  let source = "<svg><text>A&amp;B</text></svg>"
  assert_eq(source_text_content(source), Some("A&amp;B"))
}

///|
test "source adapter rejects malformed XML" {
  assert_eq(source_text_content("<svg><text>x</text></svg>trailing"), None)
  assert_eq(source_text_content("<svg><text>missing end"), None)
}
