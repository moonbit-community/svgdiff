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
fn write_test_request(request : String) -> Int {
  let bytes = @utf8.encode(request)
  for index in 0..<bytes.length() {
    wasm_store_u8(transfer_start + index, bytes[index].to_int())
  }
  bytes.length()
}

///|
fn read_test_result() -> String raise {
  let bytes : Array[Byte] = []
  for index in 0..<result_len() {
    bytes.push(wasm_load_u8(transfer_start + index).to_byte())
  }
  @utf8.decode(Bytes::from_array(bytes)) catch {
    _ => fail("result must be valid UTF-8")
  }
}

///|
test "wasm ABI compares two in-memory SVG strings" {
  @debug.assert_eq(abi_version(), 1)
  @debug.assert_eq(transfer_ptr(), 1048576)
  @debug.assert_eq(transfer_capacity(), 41943040)
  let length = write_test_request(
    "{\"version\":1,\"before_svg\":\"<svg width='16' height='16'><rect x='2' y='2' width='8' height='8' fill='red'/></svg>\",\"after_svg\":\"<svg width='16' height='16'><rect x='2' y='2' width='8' height='8' fill='blue'/></svg>\",\"viewport_width\":16,\"viewport_height\":16,\"perceptual_background\":\"#ffffff\",\"flip_pixels_per_degree\":60,\"flip_error_threshold\":0.05,\"max_checkpoints\":1000000}",
  )
  @debug.assert_eq(compare(length), status_ok)
  @debug.assert_eq(result_error_kind(), error_none)
  match @json.parse(read_test_result()) {
    {
      "report": { "schema_version": "5.0", "analysis_status": "complete", .. },
      "difference_rgba_base64": String(difference),
      ..
    } => assert_true(difference.length() > 0)
    _ =>
      fail(
        "expected a complete Structured Report and canonical Difference raster",
      )
  }
}

///|
test "wasm ABI applies explicit viewport dimensions" {
  let length = write_test_request(
    "{\"version\":1,\"before_svg\":\"<svg/>\",\"after_svg\":\"<svg/>\",\"viewport_width\":32,\"viewport_height\":24,\"perceptual_background\":\"#336699\",\"flip_pixels_per_degree\":60,\"flip_error_threshold\":0.05,\"max_checkpoints\":1000000}",
  )
  @debug.assert_eq(compare(length), status_ok)
  match @json.parse(read_test_result()) {
    {
      "report": {
        "comparison": {
          "viewport": { "width": 32, "height": 24, .. },
          "perceptual_background": { "red": 51, "green": 102, "blue": 153, .. },
          "flip_pixels_per_degree": 60,
          "flip_error_threshold": 0.05,
          ..
        },
        ..
      },
      ..
    } => ()
    _ => fail("expected request viewport in the report profile")
  }
}

///|
test "wasm ABI requires the complete request shape" {
  let incomplete = write_test_request(
    "{\"version\":1,\"before_svg\":\"<svg/>\",\"after_svg\":\"<svg/>\"}",
  )
  @debug.assert_eq(compare(incomplete), status_error)
  @debug.assert_eq(result_error_kind(), error_invalid_request)
  assert_true(read_test_result().contains("missing required field"))
}

///|
test "wasm ABI accepts an explicit raw transparent profile" {
  let request = write_test_request(
    "{\"version\":1,\"before_svg\":\"<svg/>\",\"after_svg\":\"<svg/>\",\"viewport_width\":16,\"viewport_height\":16,\"perceptual_background\":null,\"flip_pixels_per_degree\":null,\"flip_error_threshold\":null,\"max_checkpoints\":1000000}",
  )
  @debug.assert_eq(compare(request), status_ok)
  let result = read_test_result()
  match @json.parse(result) {
    {
      "report": {
        "comparison": { "viewport": { "width": 16, "height": 16, .. }, .. },
        ..
      },
      ..
    } => ()
    _ => fail("expected an explicit raw transparent comparison profile")
  }
  assert_false(result.contains("perceptual_background"))
  assert_false(result.contains("flip_pixels_per_degree"))
  assert_false(result.contains("flip_error_threshold"))
}

///|
test "wasm ABI enforces deterministic checkpoint work" {
  let request = write_test_request(
    "{\"version\":1,\"before_svg\":\"<svg><rect/></svg>\",\"after_svg\":\"<svg><rect fill='red'/></svg>\",\"viewport_width\":16,\"viewport_height\":16,\"perceptual_background\":null,\"flip_pixels_per_degree\":null,\"flip_error_threshold\":null,\"max_checkpoints\":1}",
  )
  @debug.assert_eq(compare(request), status_error)
  @debug.assert_eq(result_error_kind(), error_checkpoint_budget)
  assert_true(read_test_result().contains("checkpoint budget 1 exhausted"))
}

///|
test "wasm ABI rejects malformed host requests without trapping" {
  @debug.assert_eq(compare(-1), status_error)
  @debug.assert_eq(result_error_kind(), error_request_length)
  wasm_store_u8(transfer_start, 255)
  @debug.assert_eq(compare(1), status_error)
  @debug.assert_eq(result_error_kind(), error_invalid_utf8)
  let invalid_json = write_test_request("{")
  @debug.assert_eq(compare(invalid_json), status_error)
  @debug.assert_eq(result_error_kind(), error_invalid_json)
  let invalid_version = write_test_request(
    "{\"version\":99,\"before_svg\":\"<svg/>\",\"after_svg\":\"<svg/>\",\"viewport_width\":16,\"viewport_height\":16,\"perceptual_background\":null,\"flip_pixels_per_degree\":null,\"flip_error_threshold\":null,\"max_checkpoints\":1000000}",
  )
  @debug.assert_eq(compare(invalid_version), status_error)
  @debug.assert_eq(result_error_kind(), error_unsupported_version)
  let unknown_field = write_test_request(
    "{\"version\":1,\"before_svg\":\"<svg/>\",\"after_svg\":\"<svg/>\",\"viewport_width\":16,\"viewport_height\":16,\"perceptual_background\":null,\"flip_pixels_per_degree\":null,\"flip_error_threshold\":null,\"max_checkpoints\":1000000,\"path\":\"before.svg\"}",
  )
  @debug.assert_eq(compare(unknown_field), status_error)
  @debug.assert_eq(result_error_kind(), error_invalid_request)
  assert_true(read_test_result().contains("unknown request field"))
}
