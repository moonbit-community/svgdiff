///|
fn paeth_predictor(a : Int, b : Int, c : Int) -> Int {
  let p = a + b - c
  let pa = if p > a { p - a } else { a - p }
  let pb = if p > b { p - b } else { b - p }
  let pc = if p > c { p - c } else { c - p }
  if pa <= pb && pa <= pc {
    a
  } else if pb <= pc {
    b
  } else {
    c
  }
}

///|
/// Reconstruct a filtered scanline (decode side).
/// `filter_type`: 0=None, 1=Sub, 2=Up, 3=Average, 4=Paeth
fn reconstruct_row(
  filter_type : Int,
  row : Bytes,
  prev : Bytes,
  bpp : Int,
) -> Bytes raise DecodeError {
  let len = row.length()
  let buf = FixedArray::make(len, b'\x00')
  match filter_type {
    0 => buf.blit_from_bytes(0, row, 0, len)
    1 =>
      for i in 0..<len {
        let a = if i >= bpp { buf[i - bpp].to_int() } else { 0 }
        buf[i] = ((row[i].to_int() + a) % 256).to_byte()
      }
    2 =>
      for i in 0..<len {
        let b = prev[i].to_int()
        buf[i] = ((row[i].to_int() + b) % 256).to_byte()
      }
    3 =>
      for i in 0..<len {
        let a = if i >= bpp { buf[i - bpp].to_int() } else { 0 }
        let b = prev[i].to_int()
        buf[i] = ((row[i].to_int() + (a + b) / 2) % 256).to_byte()
      }
    4 =>
      for i in 0..<len {
        let a = if i >= bpp { buf[i - bpp].to_int() } else { 0 }
        let b = prev[i].to_int()
        let c = if i >= bpp { prev[i - bpp].to_int() } else { 0 }
        buf[i] = ((row[i].to_int() + paeth_predictor(a, b, c)) % 256).to_byte()
      }
    _ => raise CorruptData("unknown filter type: " + filter_type.to_string())
  }
  Bytes::from_array(buf)
}
