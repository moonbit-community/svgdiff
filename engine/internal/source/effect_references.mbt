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
pub(all) enum ClipPathReference {
  ClipNone
  ClipLocal(String)
  ClipExternal
  ClipInvalid
}

///|
pub(all) enum FilterReference {
  FilterNone
  FilterLocal(String)
  FilterExternal
  FilterInvalid
}

///|
pub(all) enum MaskReference {
  MaskNone
  MaskLocal(String)
  MaskExternal
  MaskInvalid
}

///|
fn parsed_effect_reference(source : String) -> (String, String?) {
  let value = source.trim().to_owned()
  if value.to_lower() == "none" {
    return ("none", None)
  }
  if value.length() < 6 ||
    !value.to_lower().has_prefix("url(") ||
    !value.has_suffix(")") {
    return ("invalid", None)
  }
  let mut locator = value
    .view(start_offset=4, end_offset=value.length() - 1)
    .to_owned()
    .trim()
    .to_owned()
  if locator.length() >= 2 &&
    (
      (locator.has_prefix("'") && locator.has_suffix("'")) ||
      (locator.has_prefix("\"") && locator.has_suffix("\""))
    ) {
    locator = locator
      .view(start_offset=1, end_offset=locator.length() - 1)
      .to_owned()
      .trim()
      .to_owned()
  }
  if locator.length() > 1 && locator.has_prefix("#") {
    let id = decode_local_fragment(locator.view(start_offset=1).to_owned())
    if id != "" &&
      id.find("#") is None &&
      id.find(" ") is None &&
      id.find("\t") is None &&
      id.find("\n") is None &&
      id.find("\r") is None {
      return ("local", Some(id))
    }
    return ("invalid", None)
  }
  if locator == "" {
    ("invalid", None)
  } else {
    ("external", None)
  }
}

///|
pub fn parse_clip_path_reference(source : String) -> ClipPathReference {
  match parsed_effect_reference(source) {
    ("none", _) => ClipNone
    ("local", Some(id)) => ClipLocal(id)
    ("external", _) => ClipExternal
    _ => ClipInvalid
  }
}

///|
pub fn canonical_clip_path_reference(source : String) -> String? {
  match parse_clip_path_reference(source) {
    ClipNone => Some("none")
    ClipLocal(id) => Some("url(#\{id})")
    _ => None
  }
}

///|
pub fn parse_filter_reference(source : String) -> FilterReference {
  match parsed_effect_reference(source) {
    ("none", _) => FilterNone
    ("local", Some(id)) => FilterLocal(id)
    ("external", _) => FilterExternal
    _ => FilterInvalid
  }
}

///|
pub fn parse_mask_reference(source : String) -> MaskReference {
  match parsed_effect_reference(source) {
    ("none", _) => MaskNone
    ("local", Some(id)) => MaskLocal(id)
    ("external", _) => MaskExternal
    _ => MaskInvalid
  }
}

///|
pub fn canonical_mask_reference(source : String) -> String? {
  match parse_mask_reference(source) {
    MaskNone => Some("none")
    MaskLocal(id) => Some("url(#\{id})")
    _ => None
  }
}
