///|
priv struct WasmFailure {
  error_kind : Int
  message : String
}

///|
priv struct WasmCompareRequest {
  before_svg : String
  after_svg : String
  viewport_width : Int
  viewport_height : Int
  perceptual_background : @svgdiff.PerceptualBackground?
  flip_viewing_conditions : @svgdiff.FlipViewingConditions?
  flip_error_threshold : @svgdiff.FlipErrorThreshold?
  max_checkpoints : Int
}

///|
fn decode_compare_request(
  json : Json,
) -> Result[WasmCompareRequest, WasmFailure] {
  guard json is Object(fields) else {
    return invalid_request("request body must be a JSON object")
  }
  for key, _ in fields {
    if !is_request_field(key) {
      return invalid_request("unknown request field `\{key}`")
    }
  }
  let version = match required_int(fields, "version") {
    Ok(value) => value
    Err(message) => return invalid_request(message)
  }
  if version != abi_version_number {
    return Err({
      error_kind: error_unsupported_version,
      message: "unsupported request version \{version}; expected \{abi_version_number}",
    })
  }
  let before_svg = match required_string(fields, "before_svg") {
    Ok(value) => value
    Err(message) => return invalid_request(message)
  }
  let after_svg = match required_string(fields, "after_svg") {
    Ok(value) => value
    Err(message) => return invalid_request(message)
  }
  let viewport_width = match required_positive_int(fields, "viewport_width") {
    Ok(value) => value
    Err(message) => return invalid_request(message)
  }
  let viewport_height = match required_positive_int(fields, "viewport_height") {
    Ok(value) => value
    Err(message) => return invalid_request(message)
  }
  let perceptual_background = match
    required_nullable_string(fields, "perceptual_background") {
    Ok(Some(source)) =>
      match @svgdiff.PerceptualBackground::parse_srgb(source) {
        Some(background) => Some(background)
        None =>
          return invalid_request(
            "field `perceptual_background` must be null or an opaque deterministic sRGB color",
          )
      }
    Ok(None) => None
    Err(message) => return invalid_request(message)
  }
  let flip_viewing_conditions = match
    required_nullable_number(fields, "flip_pixels_per_degree") {
    Ok(Some(value)) =>
      match @svgdiff.FlipViewingConditions::from_pixels_per_degree(value) {
        Some(viewing) => Some(viewing)
        None =>
          return invalid_request(
            "field `flip_pixels_per_degree` must be null or a finite number in [1, 4096]",
          )
      }
    Ok(None) => None
    Err(message) => return invalid_request(message)
  }
  let flip_error_threshold = match
    required_nullable_number(fields, "flip_error_threshold") {
    Ok(Some(value)) =>
      match @svgdiff.FlipErrorThreshold::from_value(value) {
        Some(threshold) => Some(threshold)
        None =>
          return invalid_request(
            "field `flip_error_threshold` must be null or a finite number in [0, 1]",
          )
      }
    Ok(None) => None
    Err(message) => return invalid_request(message)
  }
  if flip_viewing_conditions is Some(_) && perceptual_background is None {
    return invalid_request(
      "field `flip_pixels_per_degree` requires `perceptual_background`",
    )
  }
  if flip_error_threshold is Some(_) && flip_viewing_conditions is None {
    return invalid_request(
      "field `flip_error_threshold` requires `flip_pixels_per_degree`",
    )
  }
  let max_checkpoints = match required_positive_int(fields, "max_checkpoints") {
    Ok(value) => value
    Err(message) => return invalid_request(message)
  }
  Ok({
    before_svg,
    after_svg,
    viewport_width,
    viewport_height,
    perceptual_background,
    flip_viewing_conditions,
    flip_error_threshold,
    max_checkpoints,
  })
}

///|
fn[T] invalid_request(message : String) -> Result[T, WasmFailure] {
  Err({ error_kind: error_invalid_request, message })
}

///|
fn is_request_field(key : String) -> Bool {
  match key {
    "version"
    | "before_svg"
    | "after_svg"
    | "viewport_width"
    | "viewport_height"
    | "perceptual_background"
    | "flip_pixels_per_degree"
    | "flip_error_threshold"
    | "max_checkpoints" => true
    _ => false
  }
}

///|
fn required_string(
  fields : Map[String, Json],
  key : String,
) -> Result[String, String] {
  match fields.get(key) {
    Some(String(value)) => Ok(value)
    Some(_) => Err("field `\{key}` must be a string")
    None => Err("missing required field `\{key}`")
  }
}

///|
fn required_int(
  fields : Map[String, Json],
  key : String,
) -> Result[Int, String] {
  match fields.get(key) {
    Some(Number(value, ..)) => {
      let integer = value.to_int()
      if integer.to_double() == value {
        Ok(integer)
      } else {
        Err("field `\{key}` must be an integer")
      }
    }
    Some(_) => Err("field `\{key}` must be an integer")
    None => Err("missing required field `\{key}`")
  }
}

///|
fn required_positive_int(
  fields : Map[String, Json],
  key : String,
) -> Result[Int, String] {
  match required_int(fields, key) {
    Ok(value) if value > 0 => Ok(value)
    Ok(_) => Err("field `\{key}` must be positive")
    Err(message) => Err(message)
  }
}

///|
fn required_nullable_string(
  fields : Map[String, Json],
  key : String,
) -> Result[String?, String] {
  match fields.get(key) {
    Some(String(value)) => Ok(Some(value))
    Some(Null) => Ok(None)
    Some(_) => Err("field `\{key}` must be a string or null")
    None => Err("missing required field `\{key}`")
  }
}

///|
fn required_nullable_number(
  fields : Map[String, Json],
  key : String,
) -> Result[Double?, String] {
  match fields.get(key) {
    Some(Number(value, ..)) => Ok(Some(value))
    Some(Null) => Ok(None)
    Some(_) => Err("field `\{key}` must be a number or null")
    None => Err("missing required field `\{key}`")
  }
}
