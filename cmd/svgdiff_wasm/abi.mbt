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
/// Browser-facing wasm1 ABI.
///
/// JavaScript writes one versioned JSON request into the exported transfer
/// arena, calls `compare`, and reads the UTF-8 result body from the same arena.

///|
let abi_version_number : Int = 1

///|
let transfer_start : Int = 1048576

///|
let transfer_size : Int = 41943040

///|
let status_ok : Int = 0

///|
let status_error : Int = 1

///|
let error_none : Int = 0

///|
let error_request_length : Int = 1

///|
let error_invalid_utf8 : Int = 2

///|
let error_invalid_json : Int = 3

///|
let error_unsupported_version : Int = 4

///|
let error_invalid_request : Int = 5

///|
let error_result_too_large : Int = 6

///|
let error_checkpoint_budget : Int = 7

///|
priv struct WasmResultState {
  mut length : Int
  mut error_kind : Int
  mut required_length : Int
}

///|
let wasm_result_state : WasmResultState = {
  length: 0,
  error_kind: error_none,
  required_length: 0,
}

///|
pub fn abi_version() -> Int {
  abi_version_number
}

///|
pub fn transfer_ptr() -> Int {
  transfer_start
}

///|
pub fn transfer_capacity() -> Int {
  transfer_size
}

///|
pub fn result_len() -> Int {
  wasm_result_state.length
}

///|
pub fn result_error_kind() -> Int {
  wasm_result_state.error_kind
}

///|
pub fn result_required_len() -> Int {
  wasm_result_state.required_length
}

///|
pub fn compare(request_len : Int) -> Int {
  reset_result_state()
  let request_text = match read_request(request_len) {
    Ok(text) => text
    Err(failure) => return finish_error(failure.error_kind, failure.message)
  }
  let request_json = @json.parse(request_text) catch {
    error => return finish_error(error_invalid_json, error.to_string())
  }
  let request = match decode_compare_request(request_json) {
    Ok(request) => request
    Err(failure) => return finish_error(failure.error_kind, failure.message)
  }
  let profile = {
    ..@svgdiff.ComparisonProfile::v1_default(),
    viewport_width: request.viewport_width,
    viewport_height: request.viewport_height,
    perceptual_background: request.perceptual_background,
    flip_viewing_conditions: request.flip_viewing_conditions,
    flip_error_threshold: request.flip_error_threshold,
  }
  let should_cancel : () -> Bool = () => false
  let report = @svgdiff.compare_with_control(
    request.before_svg,
    request.after_svg,
    profile,
    { should_cancel, max_checkpoints: Some(request.max_checkpoints) },
  ) catch {
    CheckpointBudgetExceeded(max_checkpoints~) =>
      return finish_error(
        error_checkpoint_budget,
        "deterministic checkpoint budget \{max_checkpoints} exhausted",
      )
    Cancelled =>
      return finish_error(error_checkpoint_budget, "comparison cancelled")
  }
  finish_success(report.to_compact_json_string())
}

///|
fn reset_result_state() -> Unit {
  wasm_result_state.length = 0
  wasm_result_state.error_kind = error_none
  wasm_result_state.required_length = 0
}

///|
fn read_request(request_len : Int) -> Result[String, WasmFailure] {
  if request_len < 0 || request_len > transfer_size {
    return Err({
      error_kind: error_request_length,
      message: "request length must be between 0 and \{transfer_size} bytes",
    })
  }
  let bytes : Array[Byte] = []
  for index in 0..<request_len {
    bytes.push(wasm_load_u8(transfer_start + index).to_byte())
  }
  try @utf8.decode(Bytes::from_array(bytes)) catch {
    _ =>
      Err({
        error_kind: error_invalid_utf8,
        message: "request must be valid UTF-8",
      })
  } noraise {
    text => Ok(text)
  }
}

///|
fn finish_success(body : String) -> Int {
  finish_result(body, error_none)
}

///|
fn finish_error(error_kind : Int, message : String) -> Int {
  finish_result(message, error_kind)
}

///|
fn finish_result(body : String, error_kind : Int) -> Int {
  let bytes = @utf8.encode(body)
  wasm_result_state.required_length = bytes.length()
  if bytes.length() > transfer_size {
    let required_length = bytes.length()
    let fallback = @utf8.encode(
      "result requires \{required_length} bytes, exceeding transfer capacity \{transfer_size}",
    )
    write_transfer_bytes(fallback)
    wasm_result_state.length = fallback.length()
    wasm_result_state.error_kind = error_result_too_large
    wasm_result_state.required_length = required_length
    return status_error
  }
  write_transfer_bytes(bytes)
  wasm_result_state.length = bytes.length()
  wasm_result_state.error_kind = error_kind
  if error_kind == error_none {
    status_ok
  } else {
    status_error
  }
}

///|
fn write_transfer_bytes(bytes : Bytes) -> Unit {
  for index in 0..<bytes.length() {
    wasm_store_u8(transfer_start + index, bytes[index].to_int())
  }
}

///|
extern "wasm" fn wasm_load_u8(ptr : Int) -> Int =
  #|(func (param i32) (result i32)
  #|  (i32.load8_u (local.get 0)))

///|
extern "wasm" fn wasm_store_u8(ptr : Int, value : Int) -> Unit =
  #|(func (param i32 i32)
  #|  (i32.store8 (local.get 0) (local.get 1)))
