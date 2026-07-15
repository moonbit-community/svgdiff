///|
priv struct DecodedEmbeddedRaster {
  source_kind : String
  media_type : String
  encoding : String
  encoded_bytes : Int
  encoded_sha256 : String
  width : Int
  height : Int
  rgba8 : Bytes
  rgba8_sha256 : String
}

///|
priv enum EmbeddedRasterDecodeResult {
  EmbeddedRasterDecoded(DecodedEmbeddedRaster)
  EmbeddedRasterUnsupported(String)
  EmbeddedRasterInvalid(String)
  EmbeddedRasterLimitExceeded(String)
  EmbeddedRasterBundleMissing
}

///|
fn raster_sha256(bytes : Bytes) -> String {
  @crypto.bytes_to_hex_string(@crypto.sha256(bytes))
}

///|
fn decode_raster_bytes(
  bytes : Bytes,
  media_type : String,
  source_kind : String,
  encoding : String,
  max_bytes : Int,
  max_dimension : Int,
  max_pixels : Int,
) -> EmbeddedRasterDecodeResult {
  if bytes.length() > max_bytes {
    return EmbeddedRasterLimitExceeded(
      if source_kind == "data" {
        "embedded_raster_data_bytes"
      } else {
        "resource_bundle_entry_bytes"
      },
    )
  }
  let image = try {
    if media_type == "image/png" {
      @raster_codec.decode_png_bounded(bytes, max_dimension~, max_pixels~)
    } else {
      @raster_codec.decode_jpeg_bounded(bytes, max_dimension~, max_pixels~)
    }
  } catch {
    DecodeLimitExceeded(dimension) =>
      return EmbeddedRasterLimitExceeded(dimension)
    InvalidSignature(_) =>
      return EmbeddedRasterInvalid("embedded_raster_signature_mismatch")
    UnsupportedFeature(_) =>
      return EmbeddedRasterUnsupported("embedded_raster_variant_unsupported")
    _ => return EmbeddedRasterInvalid("embedded_raster_decode_failed")
  }
  if image.data.length() != image.width * image.height * 4 {
    return EmbeddedRasterInvalid("embedded_raster_rgba8_length_invalid")
  }
  EmbeddedRasterDecoded({
    source_kind,
    media_type,
    encoding,
    encoded_bytes: bytes.length(),
    encoded_sha256: raster_sha256(bytes),
    width: image.width,
    height: image.height,
    rgba8: image.data,
    rgba8_sha256: raster_sha256(image.data),
  })
}

///|
fn decode_embedded_raster(
  authored : String,
  bundle : ResourceBundle,
  max_data_uri_bytes : Int,
  max_data_bytes : Int,
  max_bundle_entry_bytes : Int,
  max_dimension : Int,
  max_pixels : Int,
) -> EmbeddedRasterDecodeResult {
  let source = authored.trim().to_owned()
  if source.length() > max_data_uri_bytes &&
    source.length() >= 5 &&
    source[:5].to_lower() == "data:" {
    return EmbeddedRasterLimitExceeded("embedded_raster_data_uri_bytes")
  }
  match parse_embedded_raster_data_url(source) {
    NotEmbeddedRasterDataUrl =>
      match resource_bundle_entry(bundle, source) {
        None => EmbeddedRasterBundleMissing
        Some(entry) =>
          decode_raster_bytes(
            entry.bytes,
            normalized_bundle_media_type(entry.media_type),
            "bundle",
            "caller_supplied",
            max_bundle_entry_bytes,
            max_dimension,
            max_pixels,
          )
      }
    EmbeddedRasterDataUrlUnsupported(reason) =>
      EmbeddedRasterUnsupported(reason)
    EmbeddedRasterDataUrlInvalid(reason) => EmbeddedRasterInvalid(reason)
    EmbeddedRasterDataUrlAccepted(data_url) =>
      decode_raster_bytes(
        data_url.bytes,
        data_url.media_type,
        "data",
        data_url.encoding,
        max_data_bytes,
        max_dimension,
        max_pixels,
      )
  }
}

///|
fn preferred_image_href_attribute(
  element : @xml.NamespaceElement,
) -> @xml.NamespaceAttribute? {
  let mut legacy : @xml.NamespaceAttribute? = None
  for attribute in element.attributes {
    if attribute.name.local_name != "href" {
      continue
    }
    if attribute.name.prefix is None {
      return Some(attribute)
    }
    if attribute.name.namespace_uri == Some("http://www.w3.org/1999/xlink") {
      legacy = Some(attribute)
    }
  }
  legacy
}

///|
fn embedded_raster_source_limit(
  input : String,
  source_role : String,
  bundle : ResourceBundle,
  limits : ResourceLimits,
) -> Diagnostic? raise {
  let reader = @xml.NamespaceReader::from_string(input)
  let mut cumulative_pixels = 0
  for event in reader.read_events_until_eof() {
    match event.kind {
      Start(element) | Empty(element) if element.name.local_name == "image" => {
        guard preferred_image_href_attribute(element) is Some(attribute) else {
          continue
        }
        match
          decode_embedded_raster(
            attribute.value,
            bundle,
            limits.max_embedded_data_uri_bytes,
            limits.max_embedded_data_bytes,
            limits.max_resource_bundle_entry_bytes,
            limits.max_embedded_raster_dimension,
            limits.max_embedded_raster_pixels,
          ) {
          EmbeddedRasterDecoded(image) => {
            cumulative_pixels += image.width * image.height
            if cumulative_pixels > limits.max_embedded_raster_pixels {
              return Some(
                resource_limit_diagnostic(
                  "embedded_raster_pixels",
                  Some(source_role),
                  Some(attribute.span),
                ),
              )
            }
          }
          EmbeddedRasterLimitExceeded(dimension) =>
            return Some(
              resource_limit_diagnostic(
                dimension,
                Some(source_role),
                Some(attribute.span),
              ),
            )
          _ => ()
        }
      }
      _ => ()
    }
  }
  None
}
