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
pub(all) struct ImageData {
  width : Int
  height : Int
  data : Bytes
} derive(Eq)

///|
pub(all) enum RasterColorCondition {
  SrgbCompatible
  EmbeddedColorProfile(String)
  HdrOrHighBitDepth(String)
} derive(Debug, Eq)

///|
pub(all) struct RasterColorMetadata {
  width : Int
  height : Int
  condition : RasterColorCondition
} derive(Debug, Eq)

///|
priv enum ColorType {
  Grayscale
  Rgb
  Indexed
  GrayscaleAlpha
  Rgba
}

///|
impl Show for ColorType with fn output(self, logger) {
  logger.write_string(
    match self {
      Grayscale => "Grayscale"
      Rgb => "Rgb"
      Indexed => "Indexed"
      GrayscaleAlpha => "GrayscaleAlpha"
      Rgba => "Rgba"
    },
  )
}

///|
priv struct IhdrData {
  width : Int
  height : Int
  bit_depth : Int
  color_type : ColorType
}

///|
pub(all) suberror DecodeError {
  InvalidSignature(String)
  InvalidChunkCrc(String)
  MissingChunk(String)
  UnsupportedFeature(String)
  CorruptData(String)
  DecodeLimitExceeded(String)
}

///|
pub impl Show for DecodeError with fn output(self, logger) {
  match self {
    InvalidSignature(s) => logger.write_string("InvalidSignature: " + s)
    InvalidChunkCrc(s) => logger.write_string("InvalidChunkCrc: " + s)
    MissingChunk(s) => logger.write_string("MissingChunk: " + s)
    UnsupportedFeature(s) => logger.write_string("UnsupportedFeature: " + s)
    CorruptData(s) => logger.write_string("CorruptData: " + s)
    DecodeLimitExceeded(s) => logger.write_string("DecodeLimitExceeded: " + s)
  }
}

///|
fn color_type_from_png(value : Int) -> ColorType raise DecodeError {
  match value {
    0 => Grayscale
    2 => Rgb
    3 => Indexed
    4 => GrayscaleAlpha
    6 => Rgba
    _ => raise UnsupportedFeature("unknown color type: " + value.to_string())
  }
}

///|
fn bytes_per_pixel(ct : ColorType, bit_depth : Int) -> Int {
  let channels = match ct {
    Grayscale => 1
    Rgb => 3
    Indexed => 1
    GrayscaleAlpha => 2
    Rgba => 4
  }
  let bits = channels * bit_depth
  if bits < 8 {
    1
  } else {
    bits / 8
  }
}
