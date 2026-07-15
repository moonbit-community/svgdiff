///|
/// One caller-supplied resource identified by an opaque SVG locator.
///
/// The comparison engine never interprets `locator` as a path or URL and never
/// performs I/O. Callers own acquisition and supply the bytes explicitly.
pub(all) struct ResourceBundleEntry {
  locator : String
  media_type : String
  bytes : Bytes
}

///|
/// An ordered, caller-supplied set of resources for one SVG source.
pub(all) struct ResourceBundle {
  entries : Array[ResourceBundleEntry]
}

///|
/// Construct a bundle that supplies no external resources.
pub fn ResourceBundle::empty() -> ResourceBundle {
  { entries: [] }
}

///|
priv struct ComparisonResourceBundles {
  before : ResourceBundle
  after : ResourceBundle
}

///|
fn ComparisonResourceBundles::empty() -> ComparisonResourceBundles {
  { before: ResourceBundle::empty(), after: ResourceBundle::empty() }
}

///|
fn normalized_bundle_media_type(media_type : String) -> String {
  media_type.trim().to_owned().to_lower()
}

///|
fn resource_bundle_entry(
  bundle : ResourceBundle,
  authored_locator : String,
) -> ResourceBundleEntry? {
  let locator = authored_locator.trim().to_owned()
  for entry in bundle.entries {
    if entry.locator.trim().to_owned() == locator {
      return Some(entry)
    }
  }
  None
}

///|
fn invalid_resource_bundle_diagnostic(
  source_role : String,
  subject : String,
) -> Diagnostic {
  let subject_id = "bundle.\{source_role}.\{subject}"
  {
    id: "diagnostic:resource-bundle-invalid:\{subject_id}",
    code: "resource_bundle_invalid",
    subject_id,
    affected_evidence_layers: [
      "source_semantics", "computed_appearance", "rendered_evidence",
    ],
    source_locations: [],
  }
}

///|
fn validate_resource_bundle(
  bundle : ResourceBundle,
  source_role : String,
  limits : ResourceLimits,
) -> Diagnostic? {
  if bundle.entries.length() > limits.max_resource_bundle_entries {
    return Some(
      resource_limit_diagnostic(
        "resource_bundle_entries",
        Some(source_role),
        None,
      ),
    )
  }
  let seen : Array[String] = []
  let mut total_bytes = 0
  for index, entry in bundle.entries {
    let locator = entry.locator.trim().to_owned()
    if locator.is_empty() ||
      locator.has_prefix("#") ||
      locator.to_lower().has_prefix("data:") {
      return Some(
        invalid_resource_bundle_diagnostic(
          source_role,
          "entry.\{index}.locator",
        ),
      )
    }
    if seen.contains(locator) {
      return Some(
        invalid_resource_bundle_diagnostic(
          source_role,
          "entry.\{index}.duplicate_locator",
        ),
      )
    }
    seen.push(locator)
    let media_type = normalized_bundle_media_type(entry.media_type)
    if media_type != "image/png" && media_type != "image/jpeg" {
      return Some(
        invalid_resource_bundle_diagnostic(
          source_role,
          "entry.\{index}.media_type",
        ),
      )
    }
    if entry.bytes.length() > limits.max_resource_bundle_entry_bytes {
      return Some(
        resource_limit_diagnostic(
          "resource_bundle_entry_bytes",
          Some(source_role),
          None,
        ),
      )
    }
    total_bytes += entry.bytes.length()
    if total_bytes > limits.max_resource_bundle_bytes {
      return Some(
        resource_limit_diagnostic(
          "resource_bundle_bytes",
          Some(source_role),
          None,
        ),
      )
    }
  }
  None
}
