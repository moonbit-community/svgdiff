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
test "embedded raster data URLs accept case-insensitive PNG base64" {
  guard parse_embedded_raster_data_url(" DATA:IMAGE/PNG;BASE64,AAE= ")
    is EmbeddedRasterDataUrlAccepted(value) else {
    fail("expected accepted data URL")
  }
  assert_eq(value.media_type, "image/png")
  assert_eq(value.encoding, "base64")
  assert_eq(value.bytes, b"\x00\x01")
}

///|
test "embedded raster data URLs accept JPEG percent-encoded bytes and parameters" {
  guard parse_embedded_raster_data_url("data:image/jpeg;profile=test,%FF%00A")
    is EmbeddedRasterDataUrlAccepted(value) else {
    fail("expected accepted data URL")
  }
  assert_eq(value.media_type, "image/jpeg")
  assert_eq(value.encoding, "percent_encoded")
  assert_eq(value.bytes, b"\xFF\x00A")
}

///|
test "embedded raster data URLs distinguish non-data unsupported and invalid locators" {
  assert_true(
    parse_embedded_raster_data_url("asset.png") is NotEmbeddedRasterDataUrl,
  )
  assert_true(
    parse_embedded_raster_data_url("data:text/plain,hello")
    is EmbeddedRasterDataUrlUnsupported("data_url_media_type_unsupported"),
  )
  assert_true(
    parse_embedded_raster_data_url("data:,hello")
    is EmbeddedRasterDataUrlUnsupported("data_url_media_type_required"),
  )
  assert_true(
    parse_embedded_raster_data_url("data:image/png;base64,A===")
    is EmbeddedRasterDataUrlInvalid("data_url_base64_invalid"),
  )
  assert_true(
    parse_embedded_raster_data_url("data:image/png,%0G")
    is EmbeddedRasterDataUrlInvalid("data_url_percent_encoding_invalid"),
  )
  assert_true(
    parse_embedded_raster_data_url("data:image/png;base64;name=x,AA==")
    is EmbeddedRasterDataUrlInvalid("data_url_base64_marker_invalid"),
  )
}
