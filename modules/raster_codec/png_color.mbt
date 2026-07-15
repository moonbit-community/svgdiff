///|
/// Convert a defiltered scanline to RGBA8 pixels.
/// Returns RGBA bytes (4 bytes per pixel).
fn scanline_to_rgba(
  row : Bytes,
  color_type : ColorType,
  bit_depth : Int,
  palette : Bytes?,
) -> Bytes raise DecodeError {
  match (color_type, bit_depth) {
    (Rgba, 8) =>
      // Already RGBA8 — return as-is (zero-copy)
      row
    (Rgb, 8) => {
      let pixel_count = row.length() / 3
      let buf = FixedArray::make(pixel_count * 4, b'\x00')
      for i in 0..<pixel_count {
        buf[i * 4] = row[i * 3]
        buf[i * 4 + 1] = row[i * 3 + 1]
        buf[i * 4 + 2] = row[i * 3 + 2]
        buf[i * 4 + 3] = b'\xFF'
      }
      Bytes::from_array(buf)
    }
    (Grayscale, 8) => {
      let pixel_count = row.length()
      let buf = FixedArray::make(pixel_count * 4, b'\x00')
      for i in 0..<pixel_count {
        let v = row[i]
        buf[i * 4] = v
        buf[i * 4 + 1] = v
        buf[i * 4 + 2] = v
        buf[i * 4 + 3] = b'\xFF'
      }
      Bytes::from_array(buf)
    }
    (GrayscaleAlpha, 8) => {
      let pixel_count = row.length() / 2
      let buf = FixedArray::make(pixel_count * 4, b'\x00')
      for i in 0..<pixel_count {
        let v = row[i * 2]
        let a = row[i * 2 + 1]
        buf[i * 4] = v
        buf[i * 4 + 1] = v
        buf[i * 4 + 2] = v
        buf[i * 4 + 3] = a
      }
      Bytes::from_array(buf)
    }
    (Indexed, 8) =>
      match palette {
        None => raise MissingChunk("PLTE")
        Some(plte) => {
          let pixel_count = row.length()
          let buf = FixedArray::make(pixel_count * 4, b'\x00')
          let plte_entries = plte.length() / 3
          for i in 0..<pixel_count {
            let idx = row[i].to_int()
            if idx >= plte_entries {
              raise CorruptData(
                "palette index out of range: " + idx.to_string(),
              )
            }
            buf[i * 4] = plte[idx * 3]
            buf[i * 4 + 1] = plte[idx * 3 + 1]
            buf[i * 4 + 2] = plte[idx * 3 + 2]
            buf[i * 4 + 3] = b'\xFF'
          }
          Bytes::from_array(buf)
        }
      }
    _ =>
      raise UnsupportedFeature(
        "unsupported color type/bit depth: " +
        color_type.to_string() +
        "/" +
        bit_depth.to_string(),
      )
  }
}
