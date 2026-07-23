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
let png_signature : FixedArray[Byte] = [
  b'\x89', b'\x50', b'\x4E', b'\x47', b'\x0D', b'\x0A', b'\x1A', b'\x0A',
]

///|
fn read_u32be(data : Bytes, offset : Int) -> UInt {
  let b0 = data[offset].to_int() & 0xFF
  let b1 = data[offset + 1].to_int() & 0xFF
  let b2 = data[offset + 2].to_int() & 0xFF
  let b3 = data[offset + 3].to_int() & 0xFF
  (b0 << 24).lor(b1 << 16).lor(b2 << 8).lor(b3).reinterpret_as_uint()
}

///|
fn read_i32be(data : Bytes, offset : Int) -> Int {
  let b0 = data[offset].to_int() & 0xFF
  let b1 = data[offset + 1].to_int() & 0xFF
  let b2 = data[offset + 2].to_int() & 0xFF
  let b3 = data[offset + 3].to_int() & 0xFF
  (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
}

///|
fn chunk_type_str(data : Bytes, offset : Int) -> String {
  String::from_array([
    data[offset].to_int().unsafe_to_char(),
    data[offset + 1].to_int().unsafe_to_char(),
    data[offset + 2].to_int().unsafe_to_char(),
    data[offset + 3].to_int().unsafe_to_char(),
  ])
}

///|
fn parse_ihdr(data : Bytes) -> IhdrData raise DecodeError {
  if data.length() != 13 {
    raise CorruptData("IHDR must contain exactly 13 bytes")
  }
  let width = read_i32be(data, 0)
  let height = read_i32be(data, 4)
  let bit_depth = data[8].to_int()
  let ct = color_type_from_png(data[9].to_int())
  let compression = data[10].to_int()
  let filter = data[11].to_int()
  let interlace = data[12].to_int()
  if width <= 0 || height <= 0 {
    raise CorruptData("invalid dimensions")
  }
  if compression != 0 || filter != 0 {
    raise UnsupportedFeature("unsupported PNG compression or filter method")
  }
  if interlace != 0 {
    raise UnsupportedFeature("interlaced PNG not supported")
  }
  if bit_depth != 8 {
    raise UnsupportedFeature("only 8-bit PNG samples are supported")
  }
  { width, height, bit_depth, color_type: ct }
}

///|
priv struct PngChunk {
  chunk_type : String
  data : Bytes
}

///|
fn parse_chunks(raw : Bytes) -> Array[PngChunk] raise DecodeError {
  if raw.length() < 8 {
    raise InvalidSignature("not a PNG file")
  }
  // Verify signature
  for i in 0..<8 {
    if raw[i] != png_signature[i] {
      raise InvalidSignature("not a PNG file")
    }
  }
  let chunks : Array[PngChunk] = []
  let mut pos = 8
  let mut saw_iend = false
  while pos + 12 <= raw.length() {
    let length = read_u32be(raw, pos).reinterpret_as_int()
    let ct = chunk_type_str(raw, pos + 4)
    if pos + 12 + length > raw.length() {
      raise CorruptData("chunk extends beyond file")
    }
    // CRC covers chunk type + data
    let crc_data_len = 4 + length
    let crc_buf = FixedArray::make(crc_data_len, b'\x00')
    crc_buf.blit_from_bytes(0, raw, pos + 4, crc_data_len)
    let computed_crc = @zlib.crc32_fixed(crc_buf)
    let stored_crc = read_u32be(raw, pos + 8 + length)
    if computed_crc != stored_crc {
      raise InvalidChunkCrc(ct)
    }
    // Extract chunk data
    let chunk_data = if length > 0 {
      let buf = FixedArray::make(length, b'\x00')
      buf.blit_from_bytes(0, raw, pos + 8, length)
      Bytes::from_array(buf)
    } else {
      Bytes::new(0)
    }
    chunks.push({ chunk_type: ct, data: chunk_data })
    pos = pos + 12 + length
    if ct == "IEND" {
      saw_iend = true
      break
    }
  }
  if !saw_iend || pos != raw.length() {
    raise CorruptData("PNG must end exactly after IEND")
  }
  chunks
}

///|
fn parse_png_ihdr(chunks : Array[PngChunk]) -> IhdrData raise DecodeError {
  if chunks.is_empty() {
    raise MissingChunk("IHDR")
  }
  match chunks[0] {
    { chunk_type: "IHDR", data } => parse_ihdr(data)
    _ => raise MissingChunk("IHDR must be first chunk")
  }
}

///|
fn collect_png_image_data(
  chunks : Array[PngChunk],
  ihdr : IhdrData,
) -> (Array[Bytes], Bytes?) raise DecodeError {
  let idat_parts : Array[Bytes] = []
  let mut palette : Bytes? = None
  let mut idat_started = false
  let mut idat_closed = false
  for chunk in chunks {
    if idat_started && chunk.chunk_type != "IDAT" && chunk.chunk_type != "IEND" {
      idat_closed = true
    }
    match chunk.chunk_type {
      "IHDR" | "IEND" => ()
      "IDAT" => {
        if idat_closed {
          raise CorruptData("PNG IDAT chunks must be consecutive")
        }
        idat_started = true
        idat_parts.push(chunk.data)
      }
      "PLTE" => {
        if palette is Some(_) || idat_started {
          raise CorruptData("invalid PNG palette position")
        }
        if chunk.data.length() == 0 ||
          chunk.data.length() > 768 ||
          chunk.data.length() % 3 != 0 {
          raise CorruptData("invalid PNG palette length")
        }
        palette = Some(chunk.data)
      }
      "sRGB" =>
        if chunk.data.length() != 1 || chunk.data[0].to_int() > 3 {
          raise CorruptData("invalid PNG sRGB chunk")
        }
      "tEXt" | "zTXt" | "iTXt" | "tIME" => ()
      "tRNS"
      | "gAMA"
      | "cHRM"
      | "iCCP"
      | "cICP"
      | "mDCv"
      | "cLLi"
      | "eXIf"
      | "pHYs"
      | "sBIT"
      | "bKGD"
      | "hIST"
      | "sPLT"
      | "acTL"
      | "fcTL"
      | "fdAT" =>
        raise UnsupportedFeature(
          "PNG chunk semantics unsupported: " + chunk.chunk_type,
        )
      _ =>
        raise UnsupportedFeature("unsupported PNG chunk: " + chunk.chunk_type)
    }
  }
  if idat_parts.is_empty() {
    raise MissingChunk("IDAT")
  }
  match ihdr.color_type {
    Indexed if palette is None => raise MissingChunk("PLTE")
    Grayscale | GrayscaleAlpha if palette is Some(_) =>
      raise CorruptData("palette is forbidden for grayscale PNG")
    _ => ()
  }
  (idat_parts, palette)
}

///|
fn decode_png_scanlines(
  ihdr : IhdrData,
  idat_parts : Array[Bytes],
  palette : Bytes?,
  max_decompressed_size : Int,
  on_row : (Int, Bytes) -> Unit,
) -> Unit raise DecodeError {
  // Concatenate IDAT data
  let total_idat_len = idat_parts.fold(init=0, fn(acc, b) { acc + b.length() })
  let idat_buf = FixedArray::make(total_idat_len, b'\x00')
  let mut offset = 0
  for part in idat_parts {
    idat_buf.blit_from_bytes(offset, part, 0, part.length())
    offset += part.length()
  }
  let compressed = Bytes::from_array(idat_buf)
  // Decompress
  let decompressed = @zlib.zlib_decompress(
    compressed,
    max_size=max_decompressed_size,
  ) catch {
    _ => raise CorruptData("zlib decompression failed")
  }
  // Reconstruct image
  let bpp = bytes_per_pixel(ihdr.color_type, ihdr.bit_depth)
  let stride = ihdr.width * bpp
  let expected_len = ihdr.height * (1 + stride)
  if decompressed.length() != expected_len {
    raise CorruptData(
      "decompressed size mismatch: expected " +
      expected_len.to_string() +
      " got " +
      decompressed.length().to_string(),
    )
  }
  // Process each scanline
  let mut prev_row = Bytes::new(stride)
  for y in 0..<ihdr.height {
    let row_offset = y * (1 + stride)
    let filter_type = decompressed[row_offset].to_int()
    // Extract filtered row data
    let filtered = FixedArray::make(stride, b'\x00')
    filtered.blit_from_bytes(0, decompressed, row_offset + 1, stride)
    let filtered_bytes = Bytes::from_array(filtered)
    let reconstructed = reconstruct_row(
      filter_type, filtered_bytes, prev_row, bpp,
    )
    // Convert to RGBA
    let rgba_row = scanline_to_rgba(
      reconstructed,
      ihdr.color_type,
      ihdr.bit_depth,
      palette,
    )
    on_row(y, rgba_row)
    prev_row = reconstructed
  }
}

///|
pub fn decode_png_bounded(
  raw : Bytes,
  max_dimension~ : Int,
  max_pixels~ : Int,
) -> ImageData raise DecodeError {
  let chunks = parse_chunks(raw)
  let ihdr = parse_png_ihdr(chunks)
  if ihdr.width > max_dimension || ihdr.height > max_dimension {
    raise DecodeLimitExceeded("embedded_raster_dimension")
  }
  if ihdr.width * ihdr.height > max_pixels {
    raise DecodeLimitExceeded("embedded_raster_pixels")
  }
  let (idat_parts, palette) = collect_png_image_data(chunks, ihdr)
  let max_decompressed_size = ihdr.height *
    (1 + ihdr.width * bytes_per_pixel(ihdr.color_type, ihdr.bit_depth))
  let rgba_buf = FixedArray::make(ihdr.width * ihdr.height * 4, b'\x00')
  decode_png_scanlines(ihdr, idat_parts, palette, max_decompressed_size, fn(
    y,
    row,
  ) {
    let dst_offset = y * ihdr.width * 4
    rgba_buf.blit_from_bytes(dst_offset, row, 0, ihdr.width * 4)
  })
  { width: ihdr.width, height: ihdr.height, data: Bytes::from_array(rgba_buf) }
}
