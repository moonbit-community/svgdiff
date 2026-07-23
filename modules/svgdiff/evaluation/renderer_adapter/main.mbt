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
  "Usage: renderer_adapter SOURCE.svg WIDTH HEIGHT"
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
async fn main {
  let args = @sys.get_cli_args()
  if args.length() != 4 {
    fail(usage())
    return
  }
  let width = match parse_positive_int(args[2]) {
    Some(value) => value
    None => {
      fail("WIDTH must be a positive integer")
      return
    }
  }
  let height = match parse_positive_int(args[3]) {
    Some(value) => value
    None => {
      fail("HEIGHT must be a positive integer")
      return
    }
  }
  let source = @fs.read_file(args[1]).text() catch {
    error => {
      fail("Failed to read SVG: \{error}")
      return
    }
  }
  let document = match @svg.parse_svg_document(source) {
    Some(document) => document
    None => {
      fail("Pinned renderer rejected the SVG fixture")
      return
    }
  }
  let rendered = @svg.render_svg_document(
      document,
      width,
      height,
      @svg.RenderOptions::default(),
    ).image
  if rendered.width() != width || rendered.height() != height {
    fail("Renderer pixel buffer dimensions are invalid")
    return
  }
  let output = StringBuilder::new()
  output.write_string("{\"width\":\{width},\"height\":\{height},\"rgba\":[")
  let mut first = true
  for y in 0..<height {
    for x in 0..<width {
      let pixel = rendered.get_pixel(x, y)
      for channel in [pixel.r, pixel.g, pixel.b, pixel.a] {
        if first {
          first = false
        } else {
          output.write_char(',')
        }
        output.write_string(channel.to_string())
      }
    }
  }
  output.write_string("]}")
  println(output.to_string())
}
