///|
priv struct EmbeddedRasterDataUrl {
  media_type : String
  encoding : String
  bytes : Bytes
}

///|
priv enum EmbeddedRasterDataUrlResult {
  EmbeddedRasterDataUrlAccepted(EmbeddedRasterDataUrl)
  EmbeddedRasterDataUrlUnsupported(String)
  EmbeddedRasterDataUrlInvalid(String)
  NotEmbeddedRasterDataUrl
}

///|
fn data_url_hex_value(character : Char) -> Int? {
  match character {
    '0'..='9' => Some(character.to_int() - '0'.to_int())
    'a'..='f' => Some(character.to_int() - 'a'.to_int() + 10)
    'A'..='F' => Some(character.to_int() - 'A'.to_int() + 10)
    _ => None
  }
}

///|
fn decode_percent_encoded_bytes(source : String) -> Bytes? {
  let output = FixedArray::make(source.length(), b'\x00')
  let mut input_index = 0
  let mut output_index = 0
  while input_index < source.length() {
    let character = source[input_index].to_int().unsafe_to_char()
    if character == '%' {
      if input_index + 2 >= source.length() {
        return None
      }
      guard data_url_hex_value(
          source[input_index + 1].to_int().unsafe_to_char(),
        )
        is Some(high) else {
        return None
      }
      guard data_url_hex_value(
          source[input_index + 2].to_int().unsafe_to_char(),
        )
        is Some(low) else {
        return None
      }
      output[output_index] = ((high << 4) | low).to_byte()
      input_index += 3
    } else {
      let codepoint = character.to_int()
      if codepoint > 0x7f {
        return None
      }
      output[output_index] = codepoint.to_byte()
      input_index += 1
    }
    output_index += 1
  }
  Some(Bytes::makei(output_index, fn(index) { output[index] }))
}

///|
fn valid_base64_payload(source : String) -> Bool {
  if source.length() == 0 || source.length() % 4 != 0 {
    return false
  }
  let mut padding = 0
  for index in 0..<source.length() {
    let character = source[index].to_int().unsafe_to_char()
    let ordinary = match character {
      'A'..='Z' | 'a'..='z' | '0'..='9' | '+' | '/' => true
      _ => false
    }
    if character == '=' {
      padding += 1
      if index < source.length() - 2 || padding > 2 {
        return false
      }
    } else if !ordinary || padding > 0 {
      return false
    }
  }
  true
}

///|
fn decode_base64_data_url_payload(source : String) -> Bytes? {
  if !valid_base64_payload(source) {
    return None
  }
  try @base64.decode(source[:]) catch {
    _ => None
  } noraise {
    bytes => Some(bytes)
  }
}

///|
fn parse_embedded_raster_data_url(
  authored : String,
) -> EmbeddedRasterDataUrlResult {
  let source = authored.trim().to_owned()
  if source.length() < 5 || source[:5].to_owned().to_lower() != "data:" {
    return NotEmbeddedRasterDataUrl
  }
  guard source.find(",") is Some(comma) else {
    return EmbeddedRasterDataUrlInvalid("data_url_missing_comma")
  }
  let metadata = source[5:comma].to_owned()
  let payload = source[comma + 1:].to_owned()
  let tokens = metadata.split(";").collect()
  if tokens.is_empty() || tokens[0].trim() == "" {
    return EmbeddedRasterDataUrlUnsupported("data_url_media_type_required")
  }
  let media_type = tokens[0].trim().to_owned().to_lower()
  if media_type != "image/png" && media_type != "image/jpeg" {
    return EmbeddedRasterDataUrlUnsupported("data_url_media_type_unsupported")
  }
  let mut base64 = false
  for index in 1..<tokens.length() {
    let token = tokens[index].trim().to_owned()
    if token.to_lower() == "base64" {
      if base64 || index != tokens.length() - 1 {
        return EmbeddedRasterDataUrlInvalid("data_url_base64_marker_invalid")
      }
      base64 = true
    } else if token == "" || token.find("=") is None {
      return EmbeddedRasterDataUrlInvalid("data_url_parameter_invalid")
    }
  }
  let bytes = if base64 {
    decode_base64_data_url_payload(payload)
  } else {
    decode_percent_encoded_bytes(payload)
  }
  match bytes {
    Some(bytes) =>
      EmbeddedRasterDataUrlAccepted({
        media_type,
        encoding: if base64 {
          "base64"
        } else {
          "percent_encoded"
        },
        bytes,
      })
    None =>
      EmbeddedRasterDataUrlInvalid(
        if base64 {
          "data_url_base64_invalid"
        } else {
          "data_url_percent_encoding_invalid"
        },
      )
  }
}
