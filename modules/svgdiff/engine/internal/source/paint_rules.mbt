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
pub(all) enum ParsedPaintOrder {
  ValidPaintOrder(Array[String])
  InvalidPaintOrder
}

///|
pub fn paint_rule_tokens(source : String) -> Array[String] {
  let normalized = source
    .trim()
    .to_owned()
    .to_lower()
    .replace_all(old="\t", new=" ")
    .replace_all(old="\n", new=" ")
    .replace_all(old="\r", new=" ")
  [
    for token in normalized.split(" ") if token.trim() != "" => {
      token.trim().to_owned()
    }
  ]
}

///|
pub fn parse_paint_order_value(source : String) -> ParsedPaintOrder {
  let tokens = paint_rule_tokens(source)
  if tokens == ["normal"] {
    return ValidPaintOrder(["fill", "stroke", "markers"])
  }
  if tokens.is_empty() || tokens.length() > 3 {
    return InvalidPaintOrder
  }
  let order : Array[String] = []
  for token in tokens {
    if !["fill", "stroke", "markers"].contains(token) || order.contains(token) {
      return InvalidPaintOrder
    }
    order.push(token)
  }
  for token in ["fill", "stroke", "markers"] {
    if !order.contains(token) {
      order.push(token)
    }
  }
  ValidPaintOrder(order)
}

///|
pub fn paint_order_signature(order : Array[String]) -> String {
  let mut signature = ""
  for item in order {
    if signature == "" {
      signature = item
    } else {
      signature = "\{signature} \{item}"
    }
  }
  signature
}

///|
pub fn canonical_paint_order(source : String) -> String? {
  match parse_paint_order_value(source) {
    ValidPaintOrder(order) => Some(paint_order_signature(order))
    InvalidPaintOrder => None
  }
}

///|
pub fn canonical_winding_rule(source : String) -> String? {
  match source.trim().to_owned().to_lower() {
    "nonzero" => Some("nonzero")
    "evenodd" => Some("evenodd")
    _ => None
  }
}

///|
pub fn paint_rule_value_valid(property : String, source : String) -> Bool {
  match property {
    "paint-order" => canonical_paint_order(source) is Some(_)
    "fill-rule" | "clip-rule" => canonical_winding_rule(source) is Some(_)
    _ => false
  }
}

///|
pub fn paint_rule_issue_code(property : String) -> String {
  if property == "paint-order" {
    "paint_order_syntax_unsupported"
  } else {
    "winding_rule_syntax_unsupported"
  }
}
