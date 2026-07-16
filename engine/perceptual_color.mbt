///|
priv struct OklabColor {
  lightness : Double
  green_red : Double
  blue_yellow : Double
}

///|
fn composite_linear_srgb_channel(
  foreground : Int,
  alpha : Double,
  background : Int,
) -> Double {
  srgb8_to_linear(foreground) * alpha +
  srgb8_to_linear(background) * (1.0 - alpha)
}

///|
fn linear_srgb_to_oklab(
  red : Double,
  green : Double,
  blue : Double,
) -> OklabColor {
  let l = 0.4122214708 * red + 0.5363325363 * green + 0.0514459929 * blue
  let m = 0.2119034982 * red + 0.6806995451 * green + 0.1073969566 * blue
  let s = 0.0883024619 * red + 0.2817188376 * green + 0.6299787005 * blue
  let l_root = @math.pow(l, 1.0 / 3.0)
  let m_root = @math.pow(m, 1.0 / 3.0)
  let s_root = @math.pow(s, 1.0 / 3.0)
  {
    lightness: 0.2104542553 * l_root +
    0.7936177850 * m_root -
    0.0040720468 * s_root,
    green_red: 1.9779984951 * l_root -
    2.4285922050 * m_root +
    0.4505937099 * s_root,
    blue_yellow: 0.0259040371 * l_root +
    0.7827717662 * m_root -
    0.8086757660 * s_root,
  }
}

///|
fn displayed_oklab(
  foreground : @svg.Color,
  background : PerceptualBackground,
) -> OklabColor {
  let alpha = foreground.a.to_double() / 255.0
  linear_srgb_to_oklab(
    composite_linear_srgb_channel(foreground.r, alpha, background.red),
    composite_linear_srgb_channel(foreground.g, alpha, background.green),
    composite_linear_srgb_channel(foreground.b, alpha, background.blue),
  )
}

///|
fn delta_e_ok_after_background(
  before : @svg.Color,
  after : @svg.Color,
  background : PerceptualBackground,
) -> Double {
  let left = displayed_oklab(before, background)
  let right = displayed_oklab(after, background)
  let lightness = left.lightness - right.lightness
  let green_red = left.green_red - right.green_red
  let blue_yellow = left.blue_yellow - right.blue_yellow
  (lightness * lightness + green_red * green_red + blue_yellow * blue_yellow).sqrt()
}

///|
fn event_local_perceptual_color_evidence(
  before : @svg.Image,
  after : @svg.Image,
  regions : Array[DifferenceRegion],
  background : PerceptualBackground,
) -> PerceptualColorEvidence {
  if before.width != after.width || before.height != after.height {
    return not_computed_perceptual_color_evidence(
      "rendered_evidence_unavailable",
    )
  }
  let single_region = match regions {
    [region] => Some(region)
    _ => None
  }
  let start_x = match single_region {
    Some(region) => region.pixel_x.max(0)
    None => 0
  }
  let start_y = match single_region {
    Some(region) => region.pixel_y.max(0)
    None => 0
  }
  let end_x = match single_region {
    Some(region) => (region.pixel_x + region.pixel_width).min(before.width)
    None => before.width
  }
  let end_y = match single_region {
    Some(region) => (region.pixel_y + region.pixel_height).min(before.height)
    None => before.height
  }
  let mut sample_count = 0
  let mut sum = 0.0
  for y in start_y..<end_y {
    for x in start_x..<end_x {
      let index = y * before.width + x
      if (single_region is None && !pixel_in_regions(x, y, regions)) ||
        !pixels_differ(before, after, index) {
        continue
      }
      sample_count += 1
      sum += delta_e_ok_after_background(
        before.pixels[index],
        after.pixels[index],
        background,
      )
    }
  }
  computed_perceptual_color_evidence({
    method_id: "delta_e_ok_changed_pixels_after_linear_srgb_background/v1",
    sample_count,
    mean_delta_e_ok: if sample_count == 0 {
      0.0
    } else {
      sum / sample_count.to_double()
    },
  })
}
