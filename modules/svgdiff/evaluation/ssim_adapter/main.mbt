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
fn usage() -> String {
  "Usage: ssim_adapter BEFORE.svg AFTER.svg WIDTH HEIGHT"
}

///|
fn parse_positive_int(value : String) -> Int? {
  let parsed = @string.parse_int(value) catch { _ => return None }
  if parsed > 0 {
    Some(parsed)
  } else {
    None
  }
}

///|
async fn fail(message : String) -> Unit {
  @stdio.stderr.write(message + "\n")
  @sys.exit(2)
}

///|
fn bool_json(value : Bool) -> String {
  if value {
    "true"
  } else {
    "false"
  }
}

///|
fn optional_double_json(value : Double?) -> String {
  match value {
    Some(value) => value.to_string()
    None => "null"
  }
}

///|
fn optional_string_json(value : String?) -> String {
  match value {
    Some(value) => "\"" + value + "\""
    None => "null"
  }
}

///|
fn render_document(source : String, width : Int, height : Int) -> @svg.Image? {
  guard @svg.parse_svg_document(source) is Some(document) else { return None }
  let image = @svg.render_svg_document(
      document,
      width,
      height,
      @svg.RenderOptions::default(),
    ).image
  if image.width() != width || image.height() != height {
    None
  } else {
    Some(image)
  }
}

///|
async fn main {
  let args = @env.args()
  if args.length() != 5 {
    fail(usage())
    return
  }
  let width = match parse_positive_int(args[3]) {
    Some(value) => value
    None => {
      fail("WIDTH must be a positive integer")
      return
    }
  }
  let height = match parse_positive_int(args[4]) {
    Some(value) => value
    None => {
      fail("HEIGHT must be a positive integer")
      return
    }
  }
  let before_source = @fs.read_file(args[1]).text() catch {
    error => {
      fail("Failed to read before SVG: \{error}")
      return
    }
  }
  let after_source = @fs.read_file(args[2]).text() catch {
    error => {
      fail("Failed to read after SVG: \{error}")
      return
    }
  }
  guard render_document(before_source, width, height) is Some(before) &&
    render_document(after_source, width, height) is Some(after) else {
    fail("Pinned renderer rejected a source or emitted invalid dimensions")
    return
  }
  let enlarged_width = width * 16
  let enlarged_height = height * 16
  guard render_document(before_source, enlarged_width, enlarged_height)
    is Some(enlarged_before) &&
    render_document(after_source, enlarged_width, enlarged_height)
    is Some(enlarged_after) else {
    fail(
      "Pinned renderer rejected an enlarged source or emitted invalid dimensions",
    )
    return
  }
  guard ssim_components(
      displayed_grayscale_over_white(before),
      displayed_grayscale_over_white(after),
      width,
      height,
    )
    is Some(canonical) &&
    ssim_components(
      displayed_grayscale_over_white(enlarged_before),
      displayed_grayscale_over_white(enlarged_after),
      enlarged_width,
      enlarged_height,
    )
    is Some(enlarged) else {
    fail("Raster dimensions are too small for the 11x11 SSIM window")
    return
  }
  let multi_scale = five_level_ms_ssim(
    displayed_grayscale_over_white(enlarged_before),
    displayed_grayscale_over_white(enlarged_after),
    enlarged_width,
    enlarged_height,
  )
  println(
    "{" +
    "\"canonical_exact_rgba8\":" +
    bool_json(exact_pixels(before, after)) +
    ",\"canonical_ssim\":" +
    canonical.mean_ssim.to_string() +
    ",\"enlarged_exact_rgba8\":" +
    bool_json(exact_pixels(enlarged_before, enlarged_after)) +
    ",\"enlarged_ssim\":" +
    enlarged.mean_ssim.to_string() +
    ",\"ms_ssim\":" +
    optional_double_json(multi_scale.value) +
    ",\"ms_ssim_reason_code\":" +
    optional_string_json(multi_scale.reason_code) +
    "}",
  )
}
