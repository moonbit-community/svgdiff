///|
/// One explicit opaque sRGB8 background for future perceptual compositing.
pub struct PerceptualBackground {
  red : Int
  green : Int
  blue : Int
} derive(ToJson, Eq)

///|
/// Parse one deterministic opaque sRGB color for perceptual compositing.
pub fn PerceptualBackground::parse_srgb(
  source : String,
) -> PerceptualBackground? {
  match @css_color.parse_solid_color(source) {
    Resolved(color) if color.alpha == 1.0 =>
      Some({ red: color.red, green: color.green, blue: color.blue })
    _ => None
  }
}

///|
pub fn PerceptualBackground::red(self : PerceptualBackground) -> Int {
  self.red
}

///|
pub fn PerceptualBackground::green(self : PerceptualBackground) -> Int {
  self.green
}

///|
pub fn PerceptualBackground::blue(self : PerceptualBackground) -> Int {
  self.blue
}

///|
/// Explicit LDR-FLIP viewing conditions with a bounded filter domain.
pub struct FlipViewingConditions {
  pixels_per_degree : Double
} derive(ToJson, Eq)

///|
/// Construct supported LDR-FLIP viewing conditions.
pub fn FlipViewingConditions::from_pixels_per_degree(
  pixels_per_degree : Double,
) -> FlipViewingConditions? {
  if pixels_per_degree.is_nan() ||
    pixels_per_degree.is_inf() ||
    pixels_per_degree < 1.0 ||
    pixels_per_degree > 4096.0 {
    None
  } else {
    Some({ pixels_per_degree, })
  }
}

///|
pub fn FlipViewingConditions::pixels_per_degree(
  self : FlipViewingConditions,
) -> Double {
  self.pixels_per_degree
}

///|
/// Explicit optional reporting threshold for LDR-FLIP error values.
pub struct FlipErrorThreshold {
  value : Double
} derive(ToJson, Eq)

///|
/// Construct one finite FLIP reporting threshold in the metric's `[0, 1]` range.
pub fn FlipErrorThreshold::from_value(value : Double) -> FlipErrorThreshold? {
  if value.is_nan() || value.is_inf() || value < 0.0 || value > 1.0 {
    None
  } else {
    Some({ value, })
  }
}

///|
pub fn FlipErrorThreshold::value(self : FlipErrorThreshold) -> Double {
  self.value
}

///|
/// Rendering and normalization conditions recorded for one comparison.
///
/// The root schema `1.45` API accepts caller-provided viewport dimensions,
/// Perceptual Background, FLIP Viewing Conditions, and FLIP error threshold,
/// and canonicalizes the
/// remaining fields to `v1_default`.
pub(all) struct ComparisonProfile {
  viewport_width : Int
  viewport_height : Int
  comparison_dpr : Double
  color_interpretation : String
  raster_representation : String
  renderer_id : String
  renderer_conformance_profile_id : String
  perceptual_background : PerceptualBackground?
  flip_viewing_conditions : FlipViewingConditions?
  flip_error_threshold : FlipErrorThreshold?
}

///|
pub impl ToJson for ComparisonProfile with fn to_json(self) {
  let fields : Map[String, Json] = Map([])
  fields["viewport_width"] = self.viewport_width.to_json()
  fields["viewport_height"] = self.viewport_height.to_json()
  fields["comparison_dpr"] = self.comparison_dpr.to_json()
  fields["color_interpretation"] = self.color_interpretation.to_json()
  fields["raster_representation"] = self.raster_representation.to_json()
  fields["renderer_id"] = self.renderer_id.to_json()
  fields["renderer_conformance_profile_id"] = self.renderer_conformance_profile_id.to_json()
  fields["perceptual_background"] = nullable_report_value(
    self.perceptual_background,
  )
  fields["flip_viewing_conditions"] = nullable_report_value(
    self.flip_viewing_conditions,
  )
  fields["flip_error_threshold"] = nullable_report_value(
    self.flip_error_threshold,
  )
  Json::object(fields)
}

///|
/// Return the fixed schema `1.45` profile with a `16 x 16` viewport.
///
/// Callers may copy the record with different positive viewport dimensions,
/// an explicitly parsed Perceptual Background, invariant-checked FLIP Viewing
/// Conditions, or an invariant-checked FLIP error threshold.
pub fn ComparisonProfile::v1_default() -> ComparisonProfile {
  {
    viewport_width: 16,
    viewport_height: 16,
    comparison_dpr: 1.0,
    color_interpretation: "srgb",
    raster_representation: "linear_srgb_premultiplied_rgba_f64",
    renderer_id: "svgdiff/style-precedence-normalizer@3+ordinary-inheritance-normalizer@1+css-computed-value-normalizer@3+css-color3-opacity-normalizer@1+length-used-value-normalizer@1+stroke-used-geometry-normalizer@1+basic-shape-used-geometry-normalizer@1+isolated-group-compositor@1+static-mask-normalizer@1+static-mask-compositor@1+static-filter-graph-compositor@1+static-blend-compositor@1+Milky2018/svg@0.3.0",
    renderer_conformance_profile_id: "svgdiff-renderer-conformance-profile/26",
    perceptual_background: None,
    flip_viewing_conditions: None,
    flip_error_threshold: None,
  }
}
