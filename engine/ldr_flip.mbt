///|
/// Private implementation of the NVIDIA LDR-FLIP v1.7 equations and constants.
///
/// Reference: NVlabs/flip commit b475eb4bf394ab877c42166c9eb0a84a02cc5b14
/// (BSD-3-Clause). This module is a MoonBit implementation and does not link or
/// ship the reference implementation.
///
/// Linear-light RGB sample used by the private LDR-FLIP implementation.
priv struct FlipLinearRgb {
  red : Double
  green : Double
  blue : Double
}

///|
priv struct FlipYCxCz {
  luminance : Double
  red_green : Double
  blue_yellow : Double
}

///|
priv struct FlipLab {
  lightness : Double
  green_red : Double
  blue_yellow : Double
}

///|
priv struct FlipSpatialWeight {
  first : Double
  second : Double
}

///|
priv struct FlipSpatialIntermediate {
  luminance : Double
  red_green : Double
  blue_yellow_first : Double
  blue_yellow_second : Double
}

///|
priv struct FlipFeatureWeight {
  gaussian : Double
  first_derivative : Double
  second_derivative : Double
}

///|
priv struct FlipFeatureIntermediate {
  first_derivative : Double
  second_derivative : Double
  gaussian : Double
}

///|
priv struct FlipErrorMap {
  values : Array[Double]
}

///|
fn flip_clamp_unit(value : Double) -> Double {
  value.max(0.0).min(1.0)
}

///|
fn flip_linear_rgb_to_xyz(color : FlipLinearRgb) -> FlipLinearRgb {
  {
    red: 10135552.0 / 24577794.0 * color.red +
    8788810.0 / 24577794.0 * color.green +
    4435075.0 / 24577794.0 * color.blue,
    green: 2613072.0 / 12288897.0 * color.red +
    8788810.0 / 12288897.0 * color.green +
    887015.0 / 12288897.0 * color.blue,
    blue: 1425312.0 / 73733382.0 * color.red +
    8788810.0 / 73733382.0 * color.green +
    70074185.0 / 73733382.0 * color.blue,
  }
}

///|
fn flip_xyz_to_linear_rgb(xyz : FlipLinearRgb) -> FlipLinearRgb {
  {
    red: 3.241003275 * xyz.red -
    1.537398934 * xyz.green -
    0.498615861 * xyz.blue,
    green: -0.969224334 * xyz.red +
    1.875930071 * xyz.green +
    0.041554224 * xyz.blue,
    blue: 0.055639423 * xyz.red -
    0.204011202 * xyz.green +
    1.057148933 * xyz.blue,
  }
}

///|
fn flip_xyz_to_ycxcz(xyz : FlipLinearRgb) -> FlipYCxCz {
  let x = xyz.red * 1.052156925
  let y = xyz.green
  let z = xyz.blue * 0.918357670
  {
    luminance: 116.0 * y - 16.0,
    red_green: 500.0 * (x - y),
    blue_yellow: 200.0 * (y - z),
  }
}

///|
fn flip_ycxcz_to_xyz(color : FlipYCxCz) -> FlipLinearRgb {
  let y = (color.luminance + 16.0) / 116.0
  let x = y + color.red_green / 500.0
  let z = y - color.blue_yellow / 200.0
  { red: x * 0.950428545, green: y, blue: z * 1.088900371 }
}

///|
fn flip_xyz_lab_component(value : Double) -> Double {
  let delta = 6.0 / 29.0
  let delta_square = delta * delta
  let delta_cube = delta * delta_square
  if value > delta_cube {
    @math.pow(value, 1.0 / 3.0)
  } else {
    value / (3.0 * delta_square) + 4.0 / 29.0
  }
}

///|
fn flip_xyz_to_lab(xyz : FlipLinearRgb) -> FlipLab {
  let x = flip_xyz_lab_component(xyz.red * 1.052156925)
  let y = flip_xyz_lab_component(xyz.green)
  let z = flip_xyz_lab_component(xyz.blue * 0.918357670)
  let lightness = 116.0 * y - 16.0
  {
    lightness,
    green_red: 0.01 * lightness * 500.0 * (x - y),
    blue_yellow: 0.01 * lightness * 200.0 * (y - z),
  }
}

///|
fn flip_hyab(left : FlipLab, right : FlipLab) -> Double {
  (left.lightness - right.lightness).abs() +
  ((left.green_red - right.green_red) * (left.green_red - right.green_red) +
  (left.blue_yellow - right.blue_yellow) *
  (left.blue_yellow - right.blue_yellow)).sqrt()
}

///|
fn flip_color_max_distance() -> Double {
  let green = flip_xyz_to_lab(
    flip_linear_rgb_to_xyz({ red: 0.0, green: 1.0, blue: 0.0 }),
  )
  let blue = flip_xyz_to_lab(
    flip_linear_rgb_to_xyz({ red: 0.0, green: 0.0, blue: 1.0 }),
  )
  @math.pow(flip_hyab(green, blue), 0.7)
}

///|
fn flip_gaussian_alternative(
  x_squared : Double,
  a : Double,
  b : Double,
) -> Double {
  a * (@math.PI / b).sqrt() * @math.exp(-@math.PI * @math.PI * x_squared / b)
}

///|
fn flip_gaussian_sqrt(x_squared : Double, a : Double, b : Double) -> Double {
  (a * (@math.PI / b).sqrt()).sqrt() *
  @math.exp(-@math.PI * @math.PI * x_squared / b)
}

///|
fn flip_spatial_filter_radius(pixels_per_degree : Double) -> Int {
  (3.0 * (0.04 / (2.0 * @math.PI * @math.PI)).sqrt() * pixels_per_degree)
  .ceil()
  .to_int()
}

///|
fn flip_feature_filter_radius(pixels_per_degree : Double) -> Int {
  (3.0 * 0.5 * 0.082 * pixels_per_degree).ceil().to_int()
}

///|
fn flip_response_radius(pixels_per_degree : Double) -> Int {
  flip_spatial_filter_radius(pixels_per_degree) +
  flip_feature_filter_radius(pixels_per_degree)
}

///|
fn flip_spatial_filters(
  pixels_per_degree : Double,
) -> (Array[FlipSpatialWeight], Array[FlipSpatialWeight]) {
  let radius = flip_spatial_filter_radius(pixels_per_degree)
  let width = 2 * radius + 1
  let luminance_red_green : Array[FlipSpatialWeight] = []
  let blue_yellow : Array[FlipSpatialWeight] = []
  let mut luminance_sum = 0.0
  let mut red_green_sum = 0.0
  let mut blue_yellow_first_sum = 0.0
  let mut blue_yellow_second_sum = 0.0
  for index in 0..<width {
    let offset = (index - radius).to_double() / pixels_per_degree
    let squared = offset * offset
    let luminance = flip_gaussian_alternative(squared, 1.0, 0.0047)
    let red_green = flip_gaussian_alternative(squared, 1.0, 0.0053)
    let blue_yellow_first = flip_gaussian_sqrt(squared, 34.1, 0.04)
    let blue_yellow_second = flip_gaussian_sqrt(squared, 13.5, 0.025)
    luminance_red_green.push({ first: luminance, second: red_green })
    blue_yellow.push({ first: blue_yellow_first, second: blue_yellow_second })
    luminance_sum += luminance
    red_green_sum += red_green
    blue_yellow_first_sum += blue_yellow_first
    blue_yellow_second_sum += blue_yellow_second
  }
  let blue_yellow_norm = 1.0 /
    (blue_yellow_first_sum * blue_yellow_first_sum +
    blue_yellow_second_sum * blue_yellow_second_sum).sqrt()
  for index in 0..<width {
    let ycx = luminance_red_green[index]
    let cz = blue_yellow[index]
    luminance_red_green[index] = {
      first: ycx.first / luminance_sum,
      second: ycx.second / red_green_sum,
    }
    blue_yellow[index] = {
      first: cz.first * blue_yellow_norm,
      second: cz.second * blue_yellow_norm,
    }
  }
  (luminance_red_green, blue_yellow)
}

///|
fn flip_feature_filter(pixels_per_degree : Double) -> Array[FlipFeatureWeight] {
  let standard_deviation = 0.5 * 0.082 * pixels_per_degree
  let radius = flip_feature_filter_radius(pixels_per_degree)
  let width = 2 * radius + 1
  let filter : Array[FlipFeatureWeight] = []
  let mut gaussian_sum = 0.0
  let mut first_positive = 0.0
  let mut first_negative = 0.0
  let mut second_positive = 0.0
  let mut second_negative = 0.0
  for index in 0..<width {
    let offset = (index - radius).to_double()
    let gaussian = @math.exp(
      -(offset * offset) / (2.0 * standard_deviation * standard_deviation),
    )
    let first = -offset * gaussian
    let second = (
        offset * offset / (standard_deviation * standard_deviation) - 1.0
      ) *
      gaussian
    gaussian_sum += gaussian
    if first > 0.0 {
      first_positive += first
    } else {
      first_negative -= first
    }
    if second > 0.0 {
      second_positive += second
    } else {
      second_negative -= second
    }
    filter.push({ gaussian, first_derivative: first, second_derivative: second })
  }
  for index in 0..<width {
    let weight = filter[index]
    filter[index] = {
      gaussian: weight.gaussian / gaussian_sum,
      first_derivative: weight.first_derivative /
      (if weight.first_derivative > 0.0 {
        first_positive
      } else {
        first_negative
      }),
      second_derivative: weight.second_derivative /
      (if weight.second_derivative > 0.0 {
        second_positive
      } else {
        second_negative
      }),
    }
  }
  filter
}

///|
fn flip_pixel_index(x : Int, y : Int, width : Int, height : Int) -> Int {
  y.clamp(min=0, max=height - 1) * width + x.clamp(min=0, max=width - 1)
}

///|
fn flip_to_ycxcz(values : Array[FlipLinearRgb]) -> Array[FlipYCxCz] {
  values.map(color => flip_xyz_to_ycxcz(flip_linear_rgb_to_xyz(color)))
}

///|
fn flip_spatial_first_pass(
  image : Array[FlipYCxCz],
  width : Int,
  height : Int,
  ycx_filter : Array[FlipSpatialWeight],
  cz_filter : Array[FlipSpatialWeight],
) -> Array[FlipSpatialIntermediate] {
  let result : Array[FlipSpatialIntermediate] = Array::make(width * height, {
    luminance: 0.0,
    red_green: 0.0,
    blue_yellow_first: 0.0,
    blue_yellow_second: 0.0,
  })
  let radius = ycx_filter.length() / 2
  for y in 0..<height {
    for x in 0..<width {
      let mut luminance = 0.0
      let mut red_green = 0.0
      let mut blue_yellow_first = 0.0
      let mut blue_yellow_second = 0.0
      for offset in -radius..<=radius {
        let source = image[flip_pixel_index(x + offset, y, width, height)]
        let ycx_weight = ycx_filter[offset + radius]
        let cz_weight = cz_filter[offset + radius]
        luminance += ycx_weight.first * source.luminance
        red_green += ycx_weight.second * source.red_green
        blue_yellow_first += cz_weight.first * source.blue_yellow
        blue_yellow_second += cz_weight.second * source.blue_yellow
      }
      result[y * width + x] = {
        luminance,
        red_green,
        blue_yellow_first,
        blue_yellow_second,
      }
    }
  }
  result
}

///|
fn flip_filtered_lab(
  intermediate : Array[FlipSpatialIntermediate],
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  ycx_filter : Array[FlipSpatialWeight],
  cz_filter : Array[FlipSpatialWeight],
) -> FlipLab {
  let radius = ycx_filter.length() / 2
  let mut luminance = 0.0
  let mut red_green = 0.0
  let mut blue_yellow = 0.0
  for offset in -radius..<=radius {
    let source = intermediate[flip_pixel_index(x, y + offset, width, height)]
    let ycx_weight = ycx_filter[offset + radius]
    let cz_weight = cz_filter[offset + radius]
    luminance += ycx_weight.first * source.luminance
    red_green += ycx_weight.second * source.red_green
    blue_yellow += cz_weight.first * source.blue_yellow_first +
      cz_weight.second * source.blue_yellow_second
  }
  let linear = flip_xyz_to_linear_rgb(
    flip_ycxcz_to_xyz({ luminance, red_green, blue_yellow }),
  )
  flip_xyz_to_lab(
    flip_linear_rgb_to_xyz({
      red: flip_clamp_unit(linear.red),
      green: flip_clamp_unit(linear.green),
      blue: flip_clamp_unit(linear.blue),
    }),
  )
}

///|
fn flip_color_difference(
  reference : Array[FlipYCxCz],
  candidate : Array[FlipYCxCz],
  width : Int,
  height : Int,
  pixels_per_degree : Double,
) -> Array[Double] {
  let (ycx_filter, cz_filter) = flip_spatial_filters(pixels_per_degree)
  let reference_intermediate = flip_spatial_first_pass(
    reference, width, height, ycx_filter, cz_filter,
  )
  let candidate_intermediate = flip_spatial_first_pass(
    candidate, width, height, ycx_filter, cz_filter,
  )
  let cmax = flip_color_max_distance()
  let pccmax = 0.4 * cmax
  let result = Array::make(width * height, 0.0)
  for y in 0..<height {
    for x in 0..<width {
      let reference_lab = flip_filtered_lab(
        reference_intermediate, x, y, width, height, ycx_filter, cz_filter,
      )
      let candidate_lab = flip_filtered_lab(
        candidate_intermediate, x, y, width, height, ycx_filter, cz_filter,
      )
      let powered = @math.pow(flip_hyab(reference_lab, candidate_lab), 0.7)
      result[y * width + x] = if powered < pccmax {
        0.95 / pccmax * powered
      } else {
        0.95 + (powered - pccmax) / (cmax - pccmax) * 0.05
      }
    }
  }
  result
}

///|
fn flip_feature_first_pass(
  image : Array[FlipYCxCz],
  width : Int,
  height : Int,
  filter : Array[FlipFeatureWeight],
) -> Array[FlipFeatureIntermediate] {
  let result : Array[FlipFeatureIntermediate] = Array::make(width * height, {
    first_derivative: 0.0,
    second_derivative: 0.0,
    gaussian: 0.0,
  })
  let radius = filter.length() / 2
  for y in 0..<height {
    for x in 0..<width {
      let mut first = 0.0
      let mut second = 0.0
      let mut gaussian = 0.0
      for offset in -radius..<=radius {
        let source = image[flip_pixel_index(x + offset, y, width, height)]
        let normalized = (source.luminance + 16.0) / 116.0
        let weight = filter[offset + radius]
        first += weight.first_derivative * normalized
        second += weight.second_derivative * normalized
        gaussian += weight.gaussian * normalized
      }
      let value : FlipFeatureIntermediate = {
        first_derivative: first,
        second_derivative: second,
        gaussian,
      }
      result[y * width + x] = value
    }
  }
  result
}

///|
fn flip_feature_magnitude(
  intermediate : Array[FlipFeatureIntermediate],
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  filter : Array[FlipFeatureWeight],
) -> (Double, Double) {
  let radius = filter.length() / 2
  let mut first_x = 0.0
  let mut second_x = 0.0
  let mut first_y = 0.0
  let mut second_y = 0.0
  for offset in -radius..<=radius {
    let source = intermediate[flip_pixel_index(x, y + offset, width, height)]
    let weight = filter[offset + radius]
    first_x += weight.gaussian * source.first_derivative
    second_x += weight.gaussian * source.second_derivative
    first_y += weight.first_derivative * source.gaussian
    second_y += weight.second_derivative * source.gaussian
  }
  (
    (first_x * first_x + first_y * first_y).sqrt(),
    (second_x * second_x + second_y * second_y).sqrt(),
  )
}

///|
fn ldr_flip_error_map(
  reference : Array[FlipLinearRgb],
  candidate : Array[FlipLinearRgb],
  width : Int,
  height : Int,
  pixels_per_degree : Double,
) -> FlipErrorMap {
  let reference_ycxcz = flip_to_ycxcz(reference)
  let candidate_ycxcz = flip_to_ycxcz(candidate)
  let color_difference = flip_color_difference(
    reference_ycxcz, candidate_ycxcz, width, height, pixels_per_degree,
  )
  let feature_filter = flip_feature_filter(pixels_per_degree)
  let reference_features = flip_feature_first_pass(
    reference_ycxcz, width, height, feature_filter,
  )
  let candidate_features = flip_feature_first_pass(
    candidate_ycxcz, width, height, feature_filter,
  )
  let values = Array::make(width * height, 0.0)
  for y in 0..<height {
    for x in 0..<width {
      let (reference_edge, reference_point) = flip_feature_magnitude(
        reference_features, x, y, width, height, feature_filter,
      )
      let (candidate_edge, candidate_point) = flip_feature_magnitude(
        candidate_features, x, y, width, height, feature_filter,
      )
      let feature_difference = @math.pow(
        1.0 /
        2.0.sqrt() *
        (reference_edge - candidate_edge)
        .abs()
        .max((reference_point - candidate_point).abs()),
        0.5,
      )
      values[y * width + x] = @math.pow(
        color_difference[y * width + x],
        1.0 - feature_difference,
      )
    }
  }
  { values, }
}

///|
fn quantize_flip_u16(value : Double) -> Int {
  (flip_clamp_unit(value) * 65535.0).round().to_int()
}
