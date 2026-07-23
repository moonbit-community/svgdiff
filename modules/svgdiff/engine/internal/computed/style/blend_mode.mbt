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
pub fn blend_mode_from_keyword(value : String) -> @svg.BlendMode? {
  match value.trim().to_owned().to_lower() {
    "normal" => Some(Normal)
    "multiply" => Some(Multiply)
    "screen" => Some(Screen)
    "overlay" => Some(Overlay)
    "darken" => Some(Darken)
    "lighten" => Some(Lighten)
    "color-dodge" => Some(ColorDodge)
    "color-burn" => Some(ColorBurn)
    "hard-light" => Some(HardLight)
    "soft-light" => Some(SoftLight)
    "difference" => Some(Difference)
    "exclusion" => Some(Exclusion)
    "hue" => Some(Hue)
    "saturation" => Some(Saturation)
    "color" => Some(ColorMode)
    "luminosity" => Some(Luminosity)
    _ => None
  }
}
