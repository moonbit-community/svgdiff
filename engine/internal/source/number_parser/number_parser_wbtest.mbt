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
test "number parser accepts compact, fractional, and exponent forms" {
  let parser : NumberParser = { data: "-1.25e+2.5", position: 0 }
  assert_eq(parser.parse_number(), Some(-125.0))
  assert_eq(parser.parse_number(), Some(0.5))
  assert_eq(parser.position, 10)
}

///|
test "number parser restores its cursor after an invalid exponent" {
  let parser : NumberParser = { data: "1e+", position: 0 }
  assert_eq(parser.parse_number(), None)
  assert_eq(parser.position, 0)
}
