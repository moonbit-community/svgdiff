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
  let viewport_width = match
    positive_int_or_default(fields, "viewport_width", 16) {
    Ok(value) => value
    Err(message) => return invalid_request(message)
  }
  let viewport_height = match
    positive_int_or_default(fields, "viewport_height", 16) {
    Ok(value) => value
    Err(message) => return invalid_request(message)
  }
  Ok({ before_svg, after_svg, viewport_width, viewport_height })
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
    | "viewport_height" => true
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
fn positive_int_or_default(
  fields : Map[String, Json],
  key : String,
  default : Int,
) -> Result[Int, String] {
  match fields.get(key) {
    None => Ok(default)
    Some(_) =>
      match required_int(fields, key) {
        Ok(value) if value > 0 => Ok(value)
        Ok(_) => Err("field `\{key}` must be positive")
        Err(message) => Err(message)
      }
  }
}
