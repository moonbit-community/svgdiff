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
pub fn render_product_source_to_image(
  source : String,
  profile : ComparisonProfile,
) -> @svg.Image? {
  guard @svg.parse_svg_document(
      normalize_renderer_input_with_profile(source, profile),
    )
    is Some(document) else {
    return None
  }
  Some(
    @svg.render_svg_document(
      document,
      profile.viewport_width,
      profile.viewport_height,
      @svg.RenderOptions::default(),
    ).image,
  )
}
