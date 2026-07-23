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

// Whitebox tests run within the package scope.
// Use them to validate internal helpers or invariants.
// Keep them focused; public behavior belongs in `_test.mbt`.

///|
test "HTML preview injects the Comparison Viewport as a missing root viewBox" {
  assert_eq(
    preview_source(
      "<?xml version='1.0'?><!-- source --><svg width='16' height='16'><rect/></svg>",
      16, 16,
    ),
    "<?xml version='1.0'?><!-- source --><svg width='16' height='16' viewBox=\"0 0 16 16\"><rect/></svg>",
  )
  assert_eq(
    preview_source("<svg width='16' height='16'/>", 16, 16),
    "<svg width='16' height='16' viewBox=\"0 0 16 16\"/>",
  )
}

///|
test "HTML preview preserves an authored root viewBox and malformed source" {
  let with_view_box = "<svg width='16' height='16' viewBox='0 0 8 8'><rect/></svg>"
  assert_eq(preview_source(with_view_box, 16, 16), with_view_box)
  let malformed = "<svg width='16'><rect></svg>"
  assert_eq(preview_source(malformed, 16, 16), malformed)
}
