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
pub fn image_pixel_count(image : @svg.Image) -> Int {
  image.width() * image.height()
}

///|
pub fn image_pixel_at(image : @svg.Image, index : Int) -> @svg.Color {
  let width = image.width()
  image.get_pixel(index % width, index / width)
}

///|
pub fn pixels_differ(
  before : @svg.Image,
  after : @svg.Image,
  index : Int,
) -> Bool {
  let left = image_pixel_at(before, index)
  let right = image_pixel_at(after, index)
  left.r != right.r ||
  left.g != right.g ||
  left.b != right.b ||
  left.a != right.a
}

///|
pub fn pixel_in_regions(
  x : Int,
  y : Int,
  regions : Array[DifferenceRegion],
) -> Bool {
  regions.any(region => {
    x >= region.pixel_x &&
    x < region.pixel_x + region.pixel_width &&
    y >= region.pixel_y &&
    y < region.pixel_y + region.pixel_height
  })
}
