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
fn png_iccp_valid(data : Bytes) -> Bool {
  let mut separator : Int? = None
  for index in 0..<data.length() {
    if data[index] == b'\x00' {
      separator = Some(index)
      break
    }
  }
  match separator {
    Some(index) =>
      index > 0 &&
      index <= 79 &&
      index + 2 < data.length() &&
      data[index + 1] == b'\x00'
    None => false
  }
}

///|
fn png_bit_depth_valid(bit_depth : Int, color_type : Int) -> Bool {
  match color_type {
    0 =>
      bit_depth == 1 ||
      bit_depth == 2 ||
      bit_depth == 4 ||
      bit_depth == 8 ||
      bit_depth == 16
    2 | 4 | 6 => bit_depth == 8 || bit_depth == 16
    3 => bit_depth == 1 || bit_depth == 2 || bit_depth == 4 || bit_depth == 8
    _ => false
  }
}

///|
fn png_chromaticities_are_srgb(data : Bytes) -> Bool {
  let srgb : FixedArray[UInt] = [
    31270U, 32900U, 64000U, 33000U, 30000U, 60000U, 15000U, 6000U,
  ]
  for index in 0..<srgb.length() {
    if read_u32be(data, index * 4) != srgb[index] {
      return false
    }
  }
  true
}

///|
pub fn inspect_png_color_metadata(
  raw : Bytes,
) -> RasterColorMetadata raise DecodeError {
  let chunks = parse_chunks(raw)
  if chunks.is_empty() {
    raise MissingChunk("IHDR")
  }
  guard chunks[0] is { chunk_type: "IHDR", data } else {
    raise MissingChunk("IHDR must be first chunk")
  }
  if data.length() != 13 {
    raise CorruptData("IHDR must contain exactly 13 bytes")
  }
  let width = read_i32be(data, 0)
  let height = read_i32be(data, 4)
  if width <= 0 || height <= 0 {
    raise CorruptData("invalid dimensions")
  }
  let bit_depth = data[8].to_int()
  let color_type = data[9].to_int()
  if !png_bit_depth_valid(bit_depth, color_type) {
    raise CorruptData("invalid PNG bit depth or color type")
  }
  if data[10] != b'\x00' || data[11] != b'\x00' {
    raise CorruptData("invalid PNG compression or filter method")
  }
  if data[12] != b'\x00' && data[12] != b'\x01' {
    raise CorruptData("invalid PNG interlace method")
  }
  let mut profile_reason : String? = None
  let mut hdr_reason : String? = if bit_depth > 8 {
    Some("png_\{bit_depth}_bit_samples")
  } else {
    None
  }
  for chunk in chunks {
    match chunk.chunk_type {
      "sRGB" =>
        if chunk.data.length() != 1 || chunk.data[0].to_int() > 3 {
          raise CorruptData("invalid PNG sRGB chunk")
        }
      "iCCP" => {
        if !png_iccp_valid(chunk.data) {
          raise CorruptData("invalid PNG iCCP chunk")
        }
        if profile_reason is None {
          profile_reason = Some("png_iCCP")
        }
      }
      "gAMA" => {
        if chunk.data.length() != 4 || read_u32be(chunk.data, 0) == 0U {
          raise CorruptData("invalid PNG gAMA chunk")
        }
        if read_u32be(chunk.data, 0) != 45455U && profile_reason is None {
          profile_reason = Some("png_gAMA")
        }
      }
      "cHRM" => {
        if chunk.data.length() != 32 {
          raise CorruptData("invalid PNG cHRM chunk")
        }
        if !png_chromaticities_are_srgb(chunk.data) && profile_reason is None {
          profile_reason = Some("png_cHRM")
        }
      }
      "cICP" => {
        if chunk.data.length() != 4 {
          raise CorruptData("invalid PNG cICP chunk")
        }
        let transfer = chunk.data[1].to_int()
        if transfer == 16 || transfer == 18 {
          if hdr_reason is None {
            hdr_reason = Some("png_cICP_hdr")
          }
        } else if profile_reason is None {
          profile_reason = Some("png_cICP")
        }
      }
      "mDCv" => {
        if chunk.data.length() != 24 {
          raise CorruptData("invalid PNG mDCv chunk")
        }
        if hdr_reason is None {
          hdr_reason = Some("png_mDCv")
        }
      }
      "cLLi" => {
        if chunk.data.length() != 8 {
          raise CorruptData("invalid PNG cLLi chunk")
        }
        if hdr_reason is None {
          hdr_reason = Some("png_cLLi")
        }
      }
      _ => ()
    }
  }
  let condition = match hdr_reason {
    Some(reason) => HdrOrHighBitDepth(reason)
    None =>
      match profile_reason {
        Some(reason) => EmbeddedColorProfile(reason)
        _ => SrgbCompatible
      }
  }
  { width, height, condition }
}

///|
fn jpeg_segment_has_icc_profile(
  data : Bytes,
  payload_start : Int,
  payload_end : Int,
) -> Bool raise DecodeError {
  let signature : FixedArray[Byte] = [
    b'I', b'C', b'C', b'_', b'P', b'R', b'O', b'F', b'I', b'L', b'E', b'\x00',
  ]
  if payload_end - payload_start < signature.length() {
    return false
  }
  for index in 0..<signature.length() {
    if data[payload_start + index] != signature[index] {
      return false
    }
  }
  if payload_end - payload_start < 14 {
    raise CorruptData("invalid JPEG ICC APP2 segment")
  }
  true
}

///|
fn jpeg_start_of_frame_marker(marker : Int) -> Bool {
  marker == 0xC0 ||
  marker == 0xC1 ||
  marker == 0xC2 ||
  marker == 0xC3 ||
  marker == 0xC5 ||
  marker == 0xC6 ||
  marker == 0xC7 ||
  marker == 0xC9 ||
  marker == 0xCA ||
  marker == 0xCB ||
  marker == 0xCD ||
  marker == 0xCE ||
  marker == 0xCF
}

///|
pub fn inspect_jpeg_color_metadata(
  data : Bytes,
) -> RasterColorMetadata raise DecodeError {
  if data.length() < 2 || data[0].to_int() != 0xFF || data[1].to_int() != 0xD8 {
    raise InvalidSignature("not a JPEG file")
  }
  let mut position = 2
  let mut width : Int? = None
  let mut height : Int? = None
  let mut precision : Int? = None
  let mut embedded_icc = false
  while position + 1 < data.length() {
    if data[position].to_int() != 0xFF {
      position += 1
      continue
    }
    let marker = data[position + 1].to_int()
    position += 2
    if marker == 0xD9 {
      break
    }
    if marker == 0x00 || marker == 0xFF {
      continue
    }
    if (marker >= 0xD0 && marker <= 0xD7) || marker == 0x01 {
      continue
    }
    if position + 1 >= data.length() {
      raise CorruptData("truncated JPEG segment length")
    }
    let segment_length = read_u16be_at(data, position)
    if segment_length < 2 || segment_length > data.length() - position {
      raise CorruptData("invalid JPEG segment length")
    }
    let segment_end = position + segment_length
    if marker == 0xE2 &&
      jpeg_segment_has_icc_profile(data, position + 2, segment_end) {
      embedded_icc = true
    }
    if jpeg_start_of_frame_marker(marker) {
      if segment_length < 8 {
        raise CorruptData("truncated JPEG start-of-frame segment")
      }
      precision = Some(data[position + 2].to_int())
      height = Some(read_u16be_at(data, position + 3))
      width = Some(read_u16be_at(data, position + 5))
      if width == Some(0) || height == Some(0) {
        raise CorruptData("invalid JPEG dimensions")
      }
    }
    position = segment_end
  }
  guard width is Some(image_width) else {
    raise MissingChunk("JPEG start-of-frame marker")
  }
  guard height is Some(image_height) else {
    raise MissingChunk("JPEG start-of-frame marker")
  }
  let condition = match precision {
    Some(value) if value > 8 => HdrOrHighBitDepth("jpeg_\{value}_bit_samples")
    _ if embedded_icc => EmbeddedColorProfile("jpeg_icc_app2")
    _ => SrgbCompatible
  }
  { width: image_width, height: image_height, condition }
}
