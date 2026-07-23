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
pub(all) struct Resource {
  locator : String
  media_type : String
  path : String
} derive(FromJson)

///|
pub(all) struct Config {
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
pub(all) suberror CliError {
  InvalidArguments(String)
}

///|
pub fn version_text(command_name : String) -> String {
  let profile = @svgdiff.ComparisonProfile::v1_default()
  (
    $|\{command_name} 0.7.0
    $|engine: 0.7.0
    $|schema: 2.0
    $|agent-projection: svgdiff-agent-projection/1
    $|renderer: \{profile.renderer_id}
    $|renderer-conformance-profile: \{profile.renderer_conformance_profile_id}
    $|ordering-policy: v2_domain_lexicographic
    $|impact-policy: event_rendered_pareto/v1
  )
}

///|
fn program_name(args : Array[String]) -> String {
  let name = args
    .get(0)
    .unwrap_or("svgdiff")
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
fn input_positionals() -> Array[@argparse.PositionArg] {
  [
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
  ]
}

///|
fn command_options() -> Array[@argparse.OptionArg] {
  [
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
  ]
}

///|
pub fn command(name : String) -> @argparse.Command {
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
    positionals=input_positionals(),
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
    options=command_options(),
  )
}

///|
fn parse_positive_int(value : String, option : String) -> Int raise CliError {
  let parsed = @string.parse_int(value) catch {
    _ => raise InvalidArguments("\{option} requires a positive integer")
  }
  guard parsed > 0 else {
    raise InvalidArguments("\{option} requires a positive integer")
  }
  parsed
}

///|
fn parse_flip_viewing_conditions(
  value : String,
) -> @svgdiff.FlipViewingConditions raise CliError {
  let parsed = @string.parse_double(value) catch {
    _ =>
      raise InvalidArguments(
        "--flip-pixels-per-degree requires a finite number in [1, 4096]",
      )
  }
  match @svgdiff.FlipViewingConditions::from_pixels_per_degree(parsed) {
    Some(viewing) => viewing
    None =>
      raise InvalidArguments(
        "--flip-pixels-per-degree requires a finite number in [1, 4096]",
      )
  }
}

///|
fn parse_flip_error_threshold(
  value : String,
) -> @svgdiff.FlipErrorThreshold raise CliError {
  let parsed = @string.parse_double(value) catch {
    _ =>
      raise InvalidArguments(
        "--flip-error-threshold requires a finite number in [0, 1]",
      )
  }
  match @svgdiff.FlipErrorThreshold::from_value(parsed) {
    Some(threshold) => threshold
    None =>
      raise InvalidArguments(
        "--flip-error-threshold requires a finite number in [0, 1]",
      )
  }
}

///|
fn optional_arg(values : Array[String]?) -> String? {
  match values {
    Some([value]) => Some(value)
    _ => None
  }
}

///|
fn parse_matches(matches : @argparse.Matches) -> Config raise CliError {
  guard matches.values
    is {
      "before": [before_path],
      "after": [after_path],
      "width": [width_text],
      "height": [height_text],
      "max-checkpoints"? : max_checkpoints_arg,
      "perceptual-background"? : perceptual_background_arg,
      "flip-pixels-per-degree"? : flip_viewing_conditions_arg,
      "flip-error-threshold"? : flip_error_threshold_arg,
      "before-resource"? : before_resource_args,
      "after-resource"? : after_resource_args,
      "output"? : output_arg,
      "html"? : html_arg,
      "summary"? : summary_arg,
      ..
    } else {
    raise InvalidArguments("Invalid command arguments")
  }
  let { "agent-json"? : agent_json, "agent-projection"? : agent_projection, .. } = matches.flags
  if before_path == "-" && after_path == "-" {
    raise InvalidArguments("Only one SVG input may use stdin (-)")
  }
  let width = parse_positive_int(width_text, "--width")
  let height = parse_positive_int(height_text, "--height")
  let perceptual_background = match optional_arg(perceptual_background_arg) {
    Some(value) =>
      match @svgdiff.PerceptualBackground::parse_srgb(value) {
        Some(background) => Some(background)
        None =>
          raise InvalidArguments(
            "--perceptual-background requires an opaque deterministic sRGB color",
          )
      }
    None => None
  }
  let flip_viewing_conditions = match
    optional_arg(flip_viewing_conditions_arg) {
    Some(value) => Some(parse_flip_viewing_conditions(value))
    None => None
  }
  let flip_error_threshold = match optional_arg(flip_error_threshold_arg) {
    Some(value) => Some(parse_flip_error_threshold(value))
    None => None
  }
  let max_checkpoints = match optional_arg(max_checkpoints_arg) {
    Some(value) => Some(parse_positive_int(value, "--max-checkpoints"))
    None => None
  }
  let before_resources = parse_resources(
    before_resource_args, "--before-resource",
  )
  let after_resources = parse_resources(after_resource_args, "--after-resource")
  {
    before_path,
    after_path,
    output_path: optional_arg(output_arg),
    html_path: optional_arg(html_arg),
    summary_path: optional_arg(summary_arg),
    agent_json: agent_json.unwrap_or(false),
    agent_projection: agent_projection.unwrap_or(false),
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
fn parse_resources(
  values : Array[String]?,
  option : String,
) -> Array[Resource] raise CliError {
  let resources : Array[Resource] = []
  match values {
    Some(values) =>
      for value in values {
        let resource : Resource = @json.from_json(@json.parse(value)) catch {
          _ =>
            raise InvalidArguments(
              "\{option} requires a JSON object with string locator, media_type, and path fields",
            )
        }
        if resource.path == "-" {
          raise InvalidArguments("Resource path may not use stdin (-)")
        }
        resources.push(resource)
      }
    None => ()
  }
  resources
}

///|
pub fn parse(args : Array[String]) -> Config raise CliError {
  let name = program_name(args)
  let argv = if args.length() > 0 { args[1:] } else { args[:] }
  let matches = command(name).parse(argv~) catch {
    error => raise InvalidArguments(error.to_string())
  }
  parse_matches(matches)
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
