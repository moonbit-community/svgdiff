// Copyright 2026 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
pub(all) enum MarkerReferenceParse {
  NoMarker
  LocalMarker(String)
  InvalidMarkerReference
}

///|
pub fn marker_attachment_property(property : String) -> Bool {
  property == "marker" ||
  property == "marker-start" ||
  property == "marker-mid" ||
  property == "marker-end"
}

///|
pub fn parse_marker_reference(source : String) -> MarkerReferenceParse {
  let value = source.trim().to_owned()
  if value.to_lower() == "none" {
    return NoMarker
  }
  if !value.to_lower().has_prefix("url(") || !value.has_suffix(")") {
    return InvalidMarkerReference
  }
  let mut inner = value
    .view(start_offset=4, end_offset=value.length() - 1)
    .to_owned()
    .trim()
    .to_owned()
  if inner.length() >= 2 &&
    (
      (inner.has_prefix("'") && inner.has_suffix("'")) ||
      (inner.has_prefix("\"") && inner.has_suffix("\""))
    ) {
    inner = inner
      .view(start_offset=1, end_offset=inner.length() - 1)
      .to_owned()
      .trim()
      .to_owned()
  }
  if inner.length() <= 1 || !inner.has_prefix("#") {
    return InvalidMarkerReference
  }
  let id = inner.view(start_offset=1, end_offset=inner.length()).to_owned()
  if id.find("#") is Some(_) ||
    id.find(" ") is Some(_) ||
    id.find("\t") is Some(_) ||
    id.find("\n") is Some(_) ||
    id.find("\r") is Some(_) {
    return InvalidMarkerReference
  }
  LocalMarker(decode_local_fragment(id))
}

///|
pub fn canonical_marker_reference(source : String) -> String? {
  match parse_marker_reference(source) {
    NoMarker => Some("none")
    LocalMarker(id) => Some("url(#\{id})")
    InvalidMarkerReference => None
  }
}
