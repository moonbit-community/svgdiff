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
pub(all) struct CanonicalRasterPair {
  before : @svg.Image
  after : @svg.Image
}

///|
pub struct CanonicalRasterCapture {
  mut pair : CanonicalRasterPair?
}

///|
pub fn CanonicalRasterCapture::new() -> CanonicalRasterCapture {
  { pair: None }
}

///|
pub fn CanonicalRasterCapture::store(
  self : CanonicalRasterCapture,
  before : @svg.Image,
  after : @svg.Image,
) -> Unit {
  self.pair = Some({ before, after })
}

///|
fn displayed_channel(color : @svg.Color, channel : Int) -> Int {
  let value = match channel {
    0 => color.r
    1 => color.g
    _ => color.b
  }
  (value * color.a + 255 * (255 - color.a) + 127) / 255
}

///|
pub fn canonical_difference_rgba(
  before : @svg.Image,
  after : @svg.Image,
) -> Bytes? {
  if before.width() != after.width() || before.height() != after.height() {
    return None
  }
  Some(
    Bytes::makei(before.width() * before.height() * 4, index => {
      let channel = index % 4
      if channel == 3 {
        return 255
      }
      let pixel = index / 4
      let left = displayed_channel(image_pixel_at(before, pixel), channel)
      let right = displayed_channel(image_pixel_at(after, pixel), channel)
      (if left == right { 0 } else { 255 }).to_byte()
    }),
  )
}

///|
pub fn CanonicalRasterCapture::difference_rgba(
  self : CanonicalRasterCapture,
) -> Bytes? {
  self.pair.bind(pair => canonical_difference_rgba(pair.before, pair.after))
}
