///|
fn flip_rgb(red : Double, green : Double, blue : Double) -> FlipLinearRgb {
  { red, green, blue }
}

///|
fn assert_flip_quantized(
  actual : FlipErrorMap,
  expected : Array[Int],
) -> Unit raise {
  assert_eq(actual.values.length(), expected.length())
  for index, value in actual.values {
    assert_true((quantize_flip_u16(value) - expected[index]).abs() <= 2)
  }
}

///|
test "LDR-FLIP matches NVIDIA v1.7 focused reference maps" {
  let white = flip_rgb(1.0, 1.0, 1.0)
  let black = flip_rgb(0.0, 0.0, 0.0)
  let reference = Array::make(25, white)
  let candidate = Array::make(25, white)
  candidate[12] = black
  let center_black = ldr_flip_error_map(reference, candidate, 5, 5, 20.0)
  assert_eq(flip_response_radius(20.0), 6)
  assert_flip_quantized(center_black, [
    0, 0, 0, 0, 0, 0, 866, 10088, 866, 0, 0, 10088, 64764, 10088, 0, 0, 866, 10088,
    866, 0, 0, 0, 0, 0, 0,
  ])

  let red = Array::make(12, flip_rgb(1.0, 0.0, 0.0))
  let blue = Array::make(12, flip_rgb(0.0, 0.0, 1.0))
  let red_blue = ldr_flip_error_map(red, blue, 4, 3, 67.0)
  assert_eq(flip_response_radius(67.0), 19)
  assert_flip_quantized(red_blue, Array::make(12, 63247))

  let gradient : Array[FlipLinearRgb] = []
  for index in 0..<9 {
    let value = index.to_double() / 8.0
    gradient.push(flip_rgb(value, value * 0.5, 1.0 - value))
  }
  let changed = gradient.copy()
  changed[4] = flip_rgb(0.25, 0.75, 0.5)
  let gradient_center = ldr_flip_error_map(gradient, changed, 3, 3, 35.0)
  assert_eq(flip_response_radius(35.0), 10)
  assert_flip_quantized(gradient_center, [
    8488, 20854, 7561, 17789, 48598, 18303, 7238, 17669, 8237,
  ])
}

///|
test "LDR-FLIP is symmetric and preserves exact zero" {
  let left = [
    flip_rgb(0.0, 0.0, 0.0),
    flip_rgb(1.0, 1.0, 1.0),
    flip_rgb(1.0, 0.0, 0.0),
    flip_rgb(0.0, 0.0, 1.0),
  ]
  let right = [
    flip_rgb(0.0, 0.0, 0.0),
    flip_rgb(0.5, 0.5, 0.5),
    flip_rgb(0.0, 1.0, 0.0),
    flip_rgb(0.0, 0.0, 1.0),
  ]
  let forward = ldr_flip_error_map(left, right, 2, 2, 20.0)
  let reverse = ldr_flip_error_map(right, left, 2, 2, 20.0)
  assert_eq(forward.values.length(), reverse.values.length())
  for index, value in forward.values {
    assert_eq(
      quantize_flip_u16(value),
      quantize_flip_u16(reverse.values[index]),
    )
  }
  let zero = ldr_flip_error_map(left, left, 2, 2, 20.0)
  assert_true(zero.values.all(value => value == 0.0))
}

///|
test "LDR-FLIP supported viewing-condition boundaries remain finite" {
  for pixels_per_degree in [1.0, 4096.0] {
    let result = ldr_flip_error_map(
      [flip_rgb(1.0, 0.0, 0.0)],
      [flip_rgb(0.0, 0.0, 1.0)],
      1,
      1,
      pixels_per_degree,
    )
    assert_eq(result.values.length(), 1)
    assert_true(!result.values[0].is_nan())
    assert_true(!result.values[0].is_inf())
    assert_true(result.values[0] >= 0.0 && result.values[0] <= 1.0)
  }
}
