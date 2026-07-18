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
    "{\"version\":1,\"before_svg\":\"<svg width='16' height='16'><rect x='2' y='2' width='8' height='8' fill='red'/></svg>\",\"after_svg\":\"<svg width='16' height='16'><rect x='2' y='2' width='8' height='8' fill='blue'/></svg>\"}",
  )
  @debug.assert_eq(compare(length), status_ok)
  @debug.assert_eq(result_error_kind(), error_none)
  match @json.parse(read_test_result()) {
    { "schema_version": "1.45", "analysis_status": "complete", .. } => ()
    _ => fail("expected a complete Structured Report")
  }
}

///|
test "wasm ABI applies explicit viewport dimensions" {
  let length = write_test_request(
    "{\"version\":1,\"before_svg\":\"<svg/>\",\"after_svg\":\"<svg/>\",\"viewport_width\":32,\"viewport_height\":24}",
  )
  @debug.assert_eq(compare(length), status_ok)
  match @json.parse(read_test_result()) {
    { "profile": { "viewport_width": 32, "viewport_height": 24, .. }, .. } => ()
    _ => fail("expected request viewport in the report profile")
  }
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
    "{\"version\":2,\"before_svg\":\"<svg/>\",\"after_svg\":\"<svg/>\"}",
  )
  @debug.assert_eq(compare(invalid_version), status_error)
  @debug.assert_eq(result_error_kind(), error_unsupported_version)
  let unknown_field = write_test_request(
    "{\"version\":1,\"before_svg\":\"<svg/>\",\"after_svg\":\"<svg/>\",\"path\":\"before.svg\"}",
  )
  @debug.assert_eq(compare(unknown_field), status_error)
  @debug.assert_eq(result_error_kind(), error_invalid_request)
  assert_true(read_test_result().contains("unknown request field"))
}
