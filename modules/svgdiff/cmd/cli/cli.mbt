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
  summary_path : String?
  agent_json : Bool
  agent_projection : Bool
  width : Int
  height : Int
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
  let profile = @svgdiff.ComparisonProfile::v1_default()
  (
    $|\{command_name} 0.8.0
    $|engine: 0.8.0
    $|schema: 3.0
    $|agent-projection: svgdiff-agent-projection/2
    $|renderer: \{profile.renderer_id}
    $|renderer-conformance-profile: \{profile.renderer_conformance_profile_id}
    $|ordering-policy: v2_domain_lexicographic
    $|impact-policy: event_rendered_pareto/v1
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
        conflicts_with=["agent-projection"],
      ),
      FlagArg(
        "agent-projection",
        about="Emit lossless line-addressable Agent projection JSONL",
        conflicts_with=["agent-json"],
      ),
    ],
    options=[
      OptionArg(
        "width",
        about="Comparison viewport width in CSS pixels",
        default_values=["16"],
        allow_hyphen_values=true,
      ),
      OptionArg(
        "height",
        about="Comparison viewport height in CSS pixels",
        default_values=["16"],
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
      OptionArg(
        "output",
        about="Write JSON or Agent projection JSONL to FILE",
        allow_hyphen_values=true,
      ),
      OptionArg(
        "html",
        about="Also write the self-contained HTML presentation",
        allow_hyphen_values=true,
      ),
      OptionArg(
        "summary",
        about="Also write a derived non-authoritative Markdown summary",
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
  guard matches.values
    is {
      "before": [before_path],
      "after": [after_path],
      "width": [width_text],
      "height": [height_text],
      ..
    } else {
    raise InvalidArguments("Invalid command arguments")
  }
  if before_path == "-" && after_path == "-" {
    raise InvalidArguments("Only one SVG input may use stdin (-)")
  }
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
    summary_path: matches.values.get("summary").map(args => args[0]),
    agent_json: matches.flags.get("agent-json").unwrap_or(false),
    agent_projection: matches.flags.get("agent-projection").unwrap_or(false),
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
pub fn compare_sources(
  before_svg : String,
  after_svg : String,
  config : Config,
  before_resources : @svgdiff.ResourceBundle,
  after_resources : @svgdiff.ResourceBundle,
) -> @svgdiff.StructuredReport raise @svgdiff.ComparisonInterrupted {
  @svgdiff.compare_with_control_and_resources(
    before_svg,
    after_svg,
    {
      ..@svgdiff.ComparisonProfile::v1_default(),
      viewport_width: config.width,
      viewport_height: config.height,
      perceptual_background: config.perceptual_background,
      flip_viewing_conditions: config.flip_viewing_conditions,
      flip_error_threshold: config.flip_error_threshold,
    },
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
  if config.agent_projection {
    report.to_agent_projection_json_lines()
  } else if config.agent_json {
    report.to_compact_json_string()
  } else {
    report.to_json_string()
  }
}
