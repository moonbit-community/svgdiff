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
test "spatially disconnected pixel changes produce separate regions" {
  let before = "<svg width='16' height='16'><rect x='1' y='1' width='3' height='3' fill='red'/><rect x='12' y='12' width='3' height='3' fill='red'/></svg>"
  let after = "<svg width='16' height='16'><rect x='1' y='1' width='3' height='3' fill='blue'/><rect x='12' y='12' width='3' height='3' fill='blue'/></svg>"
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.events.length(), 2)
  assert_true(
    report.events.all(event => event.difference_regions.length() == 1),
  )
  let all_regions : Array[@engine.DifferenceRegion] = []
  for event in report.events {
    all_regions.push_iter(event.difference_regions.iter())
  }
  assert_eq(all_regions.length(), 2)
  assert_true(all_regions.all(region => region.source == "isolated_pixel_mask"))
  assert_eq(
    all_regions.fold(init=0, fn(total, region) { total + region.changed_pixels }),
    18,
  )
}

///|
test "each event raster magnitude is local to its region union" {
  let before = "<svg width='16' height='16'><rect x='1' y='1' width='2' height='2' fill='red'/><rect x='8' y='8' width='6' height='6' fill='red'/></svg>"
  let after = "<svg width='16' height='16'><rect x='1' y='1' width='2' height='2' fill='blue'/><rect x='8' y='8' width='6' height='6' fill='blue'/></svg>"
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.events.length(), 2)
  let counts : Array[Int] = []
  for event in report.events {
    match event.rendered_outcome.magnitude {
      Some(magnitude) => {
        let region_pixels = event.difference_regions.fold(init=0, fn(
          total,
          region,
        ) {
          total + region.changed_pixels
        })
        assert_eq(magnitude.changed_pixels, region_pixels)
        counts.push(magnitude.changed_pixels)
      }
      None => fail("expected event-local rendered magnitude")
    }
  }
  counts.sort()
  assert_eq(counts, [4, 36])
}

///|
test "ordinary inheritance uses an isolated pixel candidate" {
  let before = "<svg width='16' height='16'><g fill='red'><rect id='box' x='2' y='3' width='5' height='4'/></g></svg>"
  let after = "<svg width='16' height='16'><g fill='blue'><rect id='box' x='4' y='3' width='5' height='4'/></g></svg>"
  let report = @engine.compare(
    before,
    after,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.events.length(), 2)
  let fill_events = [
    for event in report.events if event.atomic_difference_ids.any(id => {
      id.has_suffix(":fill")
    }) => event
  ]
  assert_eq(fill_events.length(), 1)
  assert_eq(fill_events[0].difference_regions.length(), 1)
  let region = fill_events[0].difference_regions[0]
  assert_eq(region.source, "isolated_pixel_mask")
  assert_eq(region.css_x, 2.0)
  assert_eq(region.css_y, 3.0)
  assert_eq(region.css_width, 7.0)
  assert_eq(region.css_height, 4.0)
}
