///|
pub(all) enum ResizeMethod {
  Nearest
  Bilinear
  Bicubic
} derive(Eq, Debug)

///|
pub(all) struct ImageData {
  width : Int32
  height : Int32
  data : Bytes
} derive(Eq, Debug)

///|
pub enum ColorType {
  Grayscale
  Rgb
  Indexed
  GrayscaleAlpha
  Rgba
} derive(Eq, Debug)

///|
pub(all) struct IhdrData {
  width : Int32
  height : Int32
  bit_depth : Int32
  color_type : ColorType
  compression : Int32
  filter : Int32
  interlace : Int32
} derive(Eq, Debug)

///|
pub(all) enum ImageFormat {
  Png
  Bmp
} derive(Eq, Debug)

///|
pub(all) struct StreamImageInfo {
  format : ImageFormat
  width : Int32
  height : Int32
} derive(Eq, Debug)

///|
pub(all) suberror DecodeError {
  InvalidSignature(String)
  InvalidChunkCrc(String)
  MissingChunk(String)
  UnsupportedFeature(String)
  CorruptData(String)
}

///|
pub impl Show for DecodeError with fn output(self, logger) {
  match self {
    InvalidSignature(s) => logger.write_string("InvalidSignature: " + s)
    InvalidChunkCrc(s) => logger.write_string("InvalidChunkCrc: " + s)
    MissingChunk(s) => logger.write_string("MissingChunk: " + s)
    UnsupportedFeature(s) => logger.write_string("UnsupportedFeature: " + s)
    CorruptData(s) => logger.write_string("CorruptData: " + s)
  }
}

///|
pub(all) suberror EncodeError {
  InvalidDimensions(String)
  InvalidData(String)
}

///|
pub impl Show for EncodeError with fn output(self, logger) {
  match self {
    InvalidDimensions(s) => logger.write_string("InvalidDimensions: " + s)
    InvalidData(s) => logger.write_string("InvalidData: " + s)
  }
}

///|
fn color_type_from_png(value : Int32) -> ColorType raise DecodeError {
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
fn color_type_to_png(ct : ColorType) -> Int32 {
  match ct {
    Grayscale => 0
    Rgb => 2
    Indexed => 3
    GrayscaleAlpha => 4
    Rgba => 6
  }
}

///|
fn bytes_per_pixel(ct : ColorType, bit_depth : Int32) -> Int32 {
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

///|
test "color_type_from_png" {
  assert_eq(color_type_from_png(0), Grayscale)
  assert_eq(color_type_from_png(2), Rgb)
  assert_eq(color_type_from_png(3), Indexed)
  assert_eq(color_type_from_png(4), GrayscaleAlpha)
  assert_eq(color_type_from_png(6), Rgba)
}

///|
test "color_type_to_png" {
  assert_eq(color_type_to_png(Grayscale), 0)
  assert_eq(color_type_to_png(Rgb), 2)
  assert_eq(color_type_to_png(Indexed), 3)
  assert_eq(color_type_to_png(GrayscaleAlpha), 4)
  assert_eq(color_type_to_png(Rgba), 6)
}

///|
test "bytes_per_pixel" {
  assert_eq(bytes_per_pixel(Grayscale, 8), 1)
  assert_eq(bytes_per_pixel(Rgb, 8), 3)
  assert_eq(bytes_per_pixel(Rgba, 8), 4)
  assert_eq(bytes_per_pixel(GrayscaleAlpha, 8), 2)
  assert_eq(bytes_per_pixel(Indexed, 8), 1)
}

///|
pub extend ColorType with Debug::{to_repr}

///|
pub extend ColorType with Eq::{not_equal, equal}

///|
pub extend DecodeError with Show::{to_string, output}

///|
pub extend EncodeError with Show::{to_string, output}

///|
pub extend IhdrData with Debug::{to_repr}

///|
pub extend IhdrData with Eq::{not_equal, equal}

///|
pub extend ImageData with Debug::{to_repr}

///|
pub extend ImageData with Eq::{not_equal, equal}

///|
pub extend ImageFormat with Debug::{to_repr}

///|
pub extend ImageFormat with Eq::{not_equal, equal}

///|
pub extend ResizeMethod with Debug::{to_repr}

///|
pub extend ResizeMethod with Eq::{not_equal, equal}

///|
pub extend StreamImageInfo with Debug::{to_repr}

///|
pub extend StreamImageInfo with Eq::{not_equal, equal}
