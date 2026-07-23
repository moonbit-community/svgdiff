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
priv struct CliConfig {
  before_path : String
  after_path : String
  width : Int
  height : Int
  max_checkpoints : Int
  perceptual_background : @svgdiff.PerceptualBackground?
  flip_viewing_conditions : @svgdiff.FlipViewingConditions?
  flip_error_threshold : @svgdiff.FlipErrorThreshold?
}

///|
priv enum CliParseResult {
  Config(CliConfig)
  Invalid(String)
}

///|
fn usage() -> String {
  "Usage: svgdiff_miniio <before.svg> <after.svg> [--width N] [--height N] [--max-checkpoints N] [--perceptual-background COLOR] [--flip-pixels-per-degree PPD] [--flip-error-threshold VALUE]"
}

///|
fn help_text() -> String {
  usage() +
  "\n\nCompare two deterministic static SVG files and emit concise Structured Report JSON.\nUse - for exactly one input to read that SVG from stdin. Every file path is guest-visible and its directory must be preopened by the WASI host.\n\nOptions:\n  --width N          Comparison viewport width in CSS pixels (default: 16)\n  --height N         Comparison viewport height in CSS pixels (default: 16)\n  --max-checkpoints N\n                     Deterministic computation budget (default: 1000000)\n  --perceptual-background COLOR\n                     Record one explicit opaque deterministic sRGB background\n  --flip-pixels-per-degree PPD\n                     Request LDR-FLIP with supported PPD in [1, 4096]\n  --flip-error-threshold VALUE\n                     Report FLIP area strictly above an explicit value in [0, 1]\n  --help             Show this help and exit\n  --version          Show component versions and exit\n\nExit status:\n  0  Complete or partial report produced\n  1  Analysis failed or the deterministic checkpoint budget was exhausted\n  2  Invalid arguments or file I/O failure"
}

///|
fn version_text() -> String {
  "svgdiff_miniio 0.7.0\nschema: 2.0"
}

///|
fn parse_positive_int(value : String, option : String) -> Result[Int, String] {
  let parsed = @string.parse_int(value) catch {
    _ => return Err("\{option} requires a positive integer")
  }
  if parsed > 0 {
    Ok(parsed)
  } else {
    Err("\{option} requires a positive integer")
  }
}

///|
fn parse_flip_viewing_conditions(
  value : String,
) -> Result[@svgdiff.FlipViewingConditions, String] {
  let parsed = @string.parse_double(value) catch {
    _ =>
      return Err(
        "--flip-pixels-per-degree requires a finite number in [1, 4096]",
      )
  }
  match @svgdiff.FlipViewingConditions::from_pixels_per_degree(parsed) {
    Some(viewing) => Ok(viewing)
    None =>
      Err("--flip-pixels-per-degree requires a finite number in [1, 4096]")
  }
}

///|
fn parse_flip_error_threshold(
  value : String,
) -> Result[@svgdiff.FlipErrorThreshold, String] {
  let parsed = @string.parse_double(value) catch {
    _ => return Err("--flip-error-threshold requires a finite number in [0, 1]")
  }
  match @svgdiff.FlipErrorThreshold::from_value(parsed) {
    Some(threshold) => Ok(threshold)
    None => Err("--flip-error-threshold requires a finite number in [0, 1]")
  }
}

///|
fn parse_cli(args : Array[String]) -> CliParseResult {
  if args.length() < 3 {
    return Invalid(usage())
  }
  if args[1] == "-" && args[2] == "-" {
    return Invalid("Only one SVG input may use stdin (-)")
  }
  let mut width = 16
  let mut height = 16
  let mut max_checkpoints = 1000000
  let mut perceptual_background : @svgdiff.PerceptualBackground? = None
  let mut flip_viewing_conditions : @svgdiff.FlipViewingConditions? = None
  let mut flip_error_threshold : @svgdiff.FlipErrorThreshold? = None
  let mut index = 3
  while index < args.length() {
    if index + 1 >= args.length() {
      return Invalid("Missing value for \{args[index]}")
    }
    let value = args[index + 1]
    match args[index] {
      "--width" =>
        match parse_positive_int(value, "--width") {
          Ok(parsed) => width = parsed
          Err(message) => return Invalid(message)
        }
      "--height" =>
        match parse_positive_int(value, "--height") {
          Ok(parsed) => height = parsed
          Err(message) => return Invalid(message)
        }
      "--max-checkpoints" =>
        match parse_positive_int(value, "--max-checkpoints") {
          Ok(parsed) => max_checkpoints = parsed
          Err(message) => return Invalid(message)
        }
      "--perceptual-background" =>
        match @svgdiff.PerceptualBackground::parse_srgb(value) {
          Some(background) => perceptual_background = Some(background)
          None =>
            return Invalid(
              "--perceptual-background requires an opaque deterministic sRGB color",
            )
        }
      "--flip-pixels-per-degree" =>
        match parse_flip_viewing_conditions(value) {
          Ok(viewing) => flip_viewing_conditions = Some(viewing)
          Err(message) => return Invalid(message)
        }
      "--flip-error-threshold" =>
        match parse_flip_error_threshold(value) {
          Ok(threshold) => flip_error_threshold = Some(threshold)
          Err(message) => return Invalid(message)
        }
      option => return Invalid("Unknown option: \{option}")
    }
    index += 2
  }
  if flip_viewing_conditions is Some(_) && perceptual_background is None {
    return Invalid("--flip-pixels-per-degree requires --perceptual-background")
  }
  if flip_error_threshold is Some(_) && flip_viewing_conditions is None {
    return Invalid("--flip-error-threshold requires --flip-pixels-per-degree")
  }
  Config({
    before_path: args[1],
    after_path: args[2],
    width,
    height,
    max_checkpoints,
    perceptual_background,
    flip_viewing_conditions,
    flip_error_threshold,
  })
}

///|
fn read_svg(path : String) -> Result[String, String] {
  if path == "-" {
    try @miniio.stdin.read_all().text() catch {
      error => Err("Failed to read stdin: \{error}")
    } noraise {
      source => Ok(source)
    }
  } else {
    try @miniio.read_text_file(path) catch {
      error => Err("Failed to read \{path}: \{error}")
    } noraise {
      source => Ok(source)
    }
  }
}

///|
fn compare_sources(
  before_svg : String,
  after_svg : String,
  config : CliConfig,
) -> @svgdiff.StructuredReport raise @svgdiff.ComparisonInterrupted {
  @svgdiff.compare_with_control(
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
    {
      should_cancel: () => false,
      max_checkpoints: Some(config.max_checkpoints),
    },
  )
}

///|
fn write_error(message : String) -> Unit {
  @miniio.stderr.write_text(message + "\n") catch {
    _ => ()
  }
}

///|
fn main {
  let args = @miniio.args_get() catch {
    error => {
      write_error("Failed to read command arguments: \{error}")
      @miniio.exit(2)
      return
    }
  }
  if args.any(argument => argument == "--help") {
    @miniio.stdout.write_text(help_text() + "\n") catch {
      error => {
        write_error("Failed to write help: \{error}")
        @miniio.exit(2)
      }
    }
    return
  }
  if args.any(argument => argument == "--version") {
    @miniio.stdout.write_text(version_text() + "\n") catch {
      error => {
        write_error("Failed to write version: \{error}")
        @miniio.exit(2)
      }
    }
    return
  }
  let config = match parse_cli(args) {
    Config(config) => config
    Invalid(message) => {
      write_error(message)
      @miniio.exit(2)
      return
    }
  }
  let before_svg = match read_svg(config.before_path) {
    Ok(source) => source
    Err(message) => {
      write_error(message)
      @miniio.exit(2)
      return
    }
  }
  let after_svg = match read_svg(config.after_path) {
    Ok(source) => source
    Err(message) => {
      write_error(message)
      @miniio.exit(2)
      return
    }
  }
  let report = compare_sources(before_svg, after_svg, config) catch {
    CheckpointBudgetExceeded(max_checkpoints~) => {
      write_error(
        "Deterministic checkpoint budget \{max_checkpoints} exhausted",
      )
      @miniio.exit(1)
      return
    }
    Cancelled => {
      write_error("Comparison cancelled")
      @miniio.exit(1)
      return
    }
  }
  @miniio.stdout.write_text(report.to_compact_json_string() + "\n") catch {
    error => {
      write_error("Failed to write report: \{error}")
      @miniio.exit(2)
      return
    }
  }
  if report.analysis_status == "failed" {
    @miniio.exit(1)
  }
}
