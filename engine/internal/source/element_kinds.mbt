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
pub fn visual_subject_kind(kind : String) -> Bool {
  match kind {
    "rect" | "circle" | "ellipse" | "line" | "polyline" | "polygon" | "path" =>
      true
    _ => false
  }
}

///|
pub fn fill_hierarchy_kind(kind : String) -> Bool {
  match kind {
    "svg"
    | "g"
    | "defs"
    | "symbol"
    | "use"
    | "pattern"
    | "clipPath"
    | "mask"
    | "filter"
    | "linearGradient"
    | "radialGradient"
    | "stop"
    | "rect"
    | "circle"
    | "ellipse"
    | "line"
    | "polyline"
    | "polygon"
    | "path" => true
    _ => false
  }
}

///|
pub fn known_source_element(kind : String) -> Bool {
  match kind {
    "svg"
    | "g"
    | "rect"
    | "circle"
    | "ellipse"
    | "line"
    | "polyline"
    | "polygon"
    | "defs"
    | "symbol"
    | "use"
    | "linearGradient"
    | "radialGradient"
    | "pattern"
    | "clipPath"
    | "mask"
    | "filter"
    | "feOffset"
    | "marker"
    | "image"
    | "stop"
    | "text"
    | "title"
    | "desc"
    | "metadata"
    | "style" => true
    _ => false
  }
}

///|
pub fn group_opacity_container(kind : String) -> Bool {
  kind == "svg" || kind == "g" || kind == "symbol" || kind == "use"
}
