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
pub struct Resource {
  locator : String
  media_type : String
  path : String
} derive(FromJson)

///|
pub struct Config {
  before_path : String
  after_path : String
  output_path : String?
  html_path : String?
  agent_json : Bool
  width : Int?
  height : Int?
  perceptual_background : @svgdiff.PerceptualBackground?
  flip_viewing_conditions : @svgdiff.FlipViewingConditions?
  flip_error_threshold : @svgdiff.FlipErrorThreshold?
  before_resources : Array[Resource]
  after_resources : Array[Resource]
  max_checkpoints : Int?
}

///|
pub suberror CliError {
  InvalidArguments(String)
}

///|
fn version_text(command_name : String) -> String {
  (
    $|\{command_name} 0.10.1
    $|schema: 5.0
  )
}

///|
fn program_name(args : ArrayView[String]) -> String {
  let name = (match args {
      [path, ..] => path
      [] => "svgdiff"
    })
    .replace_all(old="\\", new="/")
    .split("/")
    .last()
    .unwrap_or("svgdiff")
    .to_owned()
  match name.strip_suffix(".exe") {
    Some(name) => name.to_owned()
    None => name.strip_suffix(".wasm").unwrap_or(name[:]).to_owned()
  }
}

///|
fn command(name : String) -> @argparse.Command {
  Command(
    name,
    about=(
      #|Compare two deterministic static SVG files and emit Structured Report JSON.
      #|Use - for exactly one input to read that SVG from stdin. Resource files are read only when named by an explicit resource option.
      #|
      #|Each --before-resource or --after-resource accepts one JSON object with locator, media_type, and path string fields.
      #|
      #|Exit status:
      #|  0  Complete or partial report produced
      #|  1  Analysis failed or the deterministic checkpoint budget was exhausted
      #|  2  Invalid arguments or file I/O failure
    ),
    version=version_text(name),
    positionals=[
      PositionArg(
        "before",
        about="Before SVG file, or - for stdin",
        num_args=@argparse.ValueRange::single(),
        allow_hyphen_values=true,
      ),
      PositionArg(
        "after",
        about="After SVG file, or - for stdin",
        num_args=@argparse.ValueRange::single(),
        allow_hyphen_values=true,
      ),
    ],
    flags=[
      FlagArg(
        "agent-json",
        about="Remove JSON formatting whitespace without removing evidence",
      ),
    ],
    options=[
      OptionArg(
        "width",
        about="Comparison viewport width in CSS pixels; defaults to the before SVG intrinsic width",
        allow_hyphen_values=true,
      ),
      OptionArg(
        "height",
        about="Comparison viewport height in CSS pixels; defaults to the before SVG intrinsic height",
        allow_hyphen_values=true,
      ),
      OptionArg(
        "max-checkpoints",
        about="Optional deterministic computation budget",
        allow_hyphen_values=true,
      ),
      OptionArg(
        "perceptual-background",
        about="Record one explicit opaque deterministic sRGB background",
        allow_hyphen_values=true,
      ),
      OptionArg(
        "flip-pixels-per-degree",
        about="Request LDR-FLIP with supported PPD in [1, 4096]",
        allow_hyphen_values=true,
      ),
      OptionArg(
        "flip-error-threshold",
        about="Report FLIP area strictly above an explicit value in [0, 1]",
        allow_hyphen_values=true,
      ),
      OptionArg(
        "before-resource",
        about="Supply one before-side resource JSON object",
        action=Append,
      ),
      OptionArg(
        "after-resource",
        about="Supply one after-side resource JSON object",
        action=Append,
      ),
      OptionArg("output", about="Write JSON to FILE", allow_hyphen_values=true),
      OptionArg(
        "html",
        about="Also write the self-contained HTML presentation",
        allow_hyphen_values=true,
      ),
    ],
  )
}

///|
pub fn parse(args : ArrayView[String]) -> Config raise CliError {
  let name = program_name(args)
  let argv = if args.length() > 0 { args[1:] } else { args[:] }
  let matches = @argparse.parse(command(name), argv~, env=Map([])) catch {
    error => raise InvalidArguments(error.to_string())
  }
  guard matches.values is { "before": [before_path], "after": [after_path], .. } else {
    raise InvalidArguments("Invalid command arguments")
  }
  if before_path == "-" && after_path == "-" {
    raise InvalidArguments("Only one SVG input may use stdin (-)")
  }
  let (width, height) = match
    (matches.values.get("width"), matches.values.get("height")) {
    (None, None) => (None, None)
    (Some([width_text]), Some([height_text])) => {
      let width = @string.parse_int(width_text) catch {
        _ => raise InvalidArguments("--width requires a positive integer")
      }
      guard width > 0 else {
        raise InvalidArguments("--width requires a positive integer")
      }
      let height = @string.parse_int(height_text) catch {
        _ => raise InvalidArguments("--height requires a positive integer")
      }
      guard height > 0 else {
        raise InvalidArguments("--height requires a positive integer")
      }
      (Some(width), Some(height))
    }
    _ =>
      raise InvalidArguments("--width and --height must be provided together")
  }
  let perceptual_background = matches.values
    .get("perceptual-background")
    .map(args => {
      guard @svgdiff.PerceptualBackground::parse_srgb(args[0])
        is Some(background) else {
        raise InvalidArguments(
          "--perceptual-background requires an opaque deterministic sRGB color",
        )
      }
      background
    })
  let flip_viewing_conditions = matches.values
    .get("flip-pixels-per-degree")
    .map(args => {
      let value = @string.parse_double(args[0]) catch {
        _ =>
          raise InvalidArguments(
            "--flip-pixels-per-degree requires a finite number in [1, 4096]",
          )
      }
      guard @svgdiff.FlipViewingConditions::from_pixels_per_degree(value)
        is Some(viewing) else {
        raise InvalidArguments(
          "--flip-pixels-per-degree requires a finite number in [1, 4096]",
        )
      }
      viewing
    })
  let flip_error_threshold = matches.values
    .get("flip-error-threshold")
    .map(args => {
      let value = @string.parse_double(args[0]) catch {
        _ =>
          raise InvalidArguments(
            "--flip-error-threshold requires a finite number in [0, 1]",
          )
      }
      guard @svgdiff.FlipErrorThreshold::from_value(value) is Some(threshold) else {
        raise InvalidArguments(
          "--flip-error-threshold requires a finite number in [0, 1]",
        )
      }
      threshold
    })
  let max_checkpoints = matches.values
    .get("max-checkpoints")
    .map(args => {
      let value = @string.parse_int(args[0]) catch {
        _ =>
          raise InvalidArguments(
            "--max-checkpoints requires a positive integer",
          )
      }
      guard value > 0 else {
        raise InvalidArguments("--max-checkpoints requires a positive integer")
      }
      value
    })
  let before_resources = matches.values
    .get("before-resource")
    .unwrap_or([])
    .map(value => {
      let resource : Resource = @json.from_json(@json.parse(value)) catch {
        _ =>
          raise InvalidArguments(
            "--before-resource requires a JSON object with string locator, media_type, and path fields",
          )
      }
      if resource.path == "-" {
        raise InvalidArguments("Resource path may not use stdin (-)")
      }
      resource
    })
  let after_resources = matches.values
    .get("after-resource")
    .unwrap_or([])
    .map(value => {
      let resource : Resource = @json.from_json(@json.parse(value)) catch {
        _ =>
          raise InvalidArguments(
            "--after-resource requires a JSON object with string locator, media_type, and path fields",
          )
      }
      if resource.path == "-" {
        raise InvalidArguments("Resource path may not use stdin (-)")
      }
      resource
    })
  {
    before_path,
    after_path,
    output_path: matches.values.get("output").map(args => args[0]),
    html_path: matches.values.get("html").map(args => args[0]),
    agent_json: matches.flags.get("agent-json").unwrap_or(false),
    width,
    height,
    perceptual_background,
    flip_viewing_conditions,
    flip_error_threshold,
    before_resources,
    after_resources,
    max_checkpoints,
  }
}

///|
fn svg_intrinsic_length(source : String) -> Double? {
  let value = source.trim().to_owned()
  let number = match value.strip_suffix("px") {
    Some(value) => value.trim().to_owned()
    None => value
  }
  let parsed = @string.parse_double(number) catch { _ => return None }
  if parsed.is_nan() || parsed.is_inf() || parsed <= 0.0 {
    None
  } else {
    Some(parsed)
  }
}

///|
fn svg_view_box_size(source : String) -> (Double, Double)? {
  let values : Array[Double] = []
  for token in source.replace_all(old=",", new=" ").split(" ") {
    let token = token.trim()
    if token == "" {
      continue
    }
    let value = @string.parse_double(token) catch { _ => return None }
    if value.is_nan() || value.is_inf() {
      return None
    }
    values.push(value)
  }
  match values {
    [_, _, width, height] if width > 0.0 && height > 0.0 =>
      Some((width, height))
    _ => None
  }
}

///|
fn intrinsic_viewport(before_svg : String) -> (Int, Int)? {
  let events = @xml.NamespaceReader::from_string(before_svg).read_events_until_eof() catch {
    _ => return None
  }
  for event in events {
    let element = match event.kind {
      Start(element) | Empty(element) => element
      _ => continue
    }
    if element.name.local_name != "svg" {
      return None
    }
    let mut width : Double? = None
    let mut height : Double? = None
    let mut view_box : (Double, Double)? = None
    for attribute in element.attributes {
      match attribute.name.local_name {
        "width" => width = svg_intrinsic_length(attribute.value)
        "height" => height = svg_intrinsic_length(attribute.value)
        "viewBox" => view_box = svg_view_box_size(attribute.value)
        _ => ()
      }
    }
    let dimensions = match (width, height, view_box) {
      (Some(width), Some(height), _) => Some((width, height))
      (_, _, Some(size)) => Some(size)
      _ => None
    }
    return dimensions.map(dimensions => {
      (dimensions.0.ceil().to_int(), dimensions.1.ceil().to_int())
    })
  }
  None
}

///|
fn comparison_profile(
  before_svg : String,
  config : Config,
) -> @svgdiff.ComparisonProfile raise CliError {
  let (viewport_width, viewport_height) = match (config.width, config.height) {
    (Some(width), Some(height)) => (width, height)
    _ =>
      intrinsic_viewport(before_svg).unwrap_or_else(() => {
        raise InvalidArguments(
          "Before SVG does not declare a usable intrinsic viewport; specify --width and --height",
        )
      })
  }
  {
    viewport_width,
    viewport_height,
    perceptual_background: config.perceptual_background,
    flip_viewing_conditions: config.flip_viewing_conditions,
    flip_error_threshold: config.flip_error_threshold,
  }
}

///|
pub fn compare_sources(
  before_svg : String,
  after_svg : String,
  config : Config,
  before_resources : @svgdiff.ResourceBundle,
  after_resources : @svgdiff.ResourceBundle,
) -> @svgdiff.StructuredReport raise {
  @svgdiff.compare_with_control_and_resources(
    before_svg,
    after_svg,
    comparison_profile(before_svg, config),
    before_resources,
    after_resources,
    { should_cancel: () => false, max_checkpoints: config.max_checkpoints },
  )
}

///|
pub fn compare_sources_with_artifact(
  before_svg : String,
  after_svg : String,
  config : Config,
  before_resources : @svgdiff.ResourceBundle,
  after_resources : @svgdiff.ResourceBundle,
) -> @svgdiff.ComparisonArtifact raise {
  @svgdiff.compare_artifact_with_control_and_resources(
    before_svg,
    after_svg,
    comparison_profile(before_svg, config),
    before_resources,
    after_resources,
    { should_cancel: () => false, max_checkpoints: config.max_checkpoints },
  )
}

///|
pub fn serialize_report(
  report : @svgdiff.StructuredReport,
  config : Config,
) -> String {
  if config.agent_json {
    report.to_compact_json_string()
  } else {
    report.to_json_string()
  }
}

///|
pub extend Resource with @moonbitlang/core/json.FromJson::{from_json}
