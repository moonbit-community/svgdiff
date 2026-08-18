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
fn assert_parse_error(args : Array[String], expected? : String) -> Unit raise {
  try @cli.parse(args) catch {
    InvalidArguments(message) =>
      match expected {
        Some(expected) => assert_eq(message, expected)
        None => ()
      }
  } noraise {
    _ => fail("expected CLI parsing to raise InvalidArguments")
  }
}

///|
test "CLI parses paths viewport and output" {
  let config = @cli.parse([
    "svgdiff", "before.svg", "after.svg", "--width", "32", "--height", "24", "--output",
    "report.json", "--html", "report.html", "--summary", "summary.md", "--agent-json",
    "--before-resource", "{\"locator\":\"asset.png\",\"media_type\":\"image/png\",\"path\":\"before.png\"}",
    "--before-resource", "{\"locator\":\"mask.png\",\"media_type\":\"image/png\",\"path\":\"before-mask.png\"}",
    "--after-resource", "{\"locator\":\"asset.png\",\"media_type\":\"image/png\",\"path\":\"after.png\"}",
    "--perceptual-background", "#336699", "--flip-pixels-per-degree", "67", "--flip-error-threshold",
    "0.05", "--max-checkpoints", "8192",
  ])
  assert_eq(config.before_path, "before.svg")
  assert_eq(config.after_path, "after.svg")
  assert_eq(config.width, 32)
  assert_eq(config.height, 24)
  assert_eq(config.output_path, Some("report.json"))
  assert_eq(config.html_path, Some("report.html"))
  assert_eq(config.summary_path, Some("summary.md"))
  assert_true(config.agent_json)
  assert_false(config.agent_projection)
  assert_eq(config.max_checkpoints, Some(8192))
  assert_eq(config.before_resources.length(), 2)
  assert_eq(config.before_resources[0].locator, "asset.png")
  assert_eq(config.before_resources[0].media_type, "image/png")
  assert_eq(config.before_resources[0].path, "before.png")
  assert_eq(config.before_resources[1].locator, "mask.png")
  assert_eq(config.before_resources[1].path, "before-mask.png")
  assert_eq(config.after_resources.length(), 1)
  assert_eq(config.after_resources[0].path, "after.png")
  guard config.perceptual_background is Some(background) else {
    fail("expected parsed Perceptual Background")
  }
  assert_eq(background.red(), 51)
  assert_eq(background.green(), 102)
  assert_eq(background.blue(), 153)
  guard config.flip_viewing_conditions is Some(viewing) else {
    fail("expected parsed FLIP Viewing Conditions")
  }
  assert_eq(viewing.pixels_per_degree(), 67.0)
  guard config.flip_error_threshold is Some(threshold) else {
    fail("expected parsed FLIP error threshold")
  }
  assert_eq(threshold.value(), 0.05)
}

///|
test "CLI keeps canonical JSON as the default" {
  let config = @cli.parse(["svgdiff", "before.svg", "after.svg"])
  assert_false(config.agent_json)
  assert_false(config.agent_projection)
  assert_true(config.summary_path is None)
  assert_true(config.max_checkpoints is None)
}

///|
test "CLI selects one lossless Agent projection mode" {
  let config = @cli.parse([
    "svgdiff", "before.svg", "after.svg", "--agent-projection",
  ])
  assert_false(config.agent_json)
  assert_true(config.agent_projection)
  assert_parse_error([
    "svgdiff", "before.svg", "after.svg", "--agent-json", "--agent-projection",
  ])
}

///|
test "CLI records a FLIP error threshold without inventing Viewing Conditions" {
  let config = @cli.parse([
    "svgdiff", "before.svg", "after.svg", "--flip-error-threshold", "0.25",
  ])
  assert_true(config.flip_viewing_conditions is None)
  guard config.flip_error_threshold is Some(threshold) else {
    fail("expected parsed FLIP error threshold")
  }
  assert_eq(threshold.value(), 0.25)
}

///|
test "CLI rejects missing and invalid arguments" {
  assert_parse_error([])
  assert_parse_error(["svgdiff"])
  assert_parse_error(
    ["svgdiff", "a.svg", "b.svg", "--width", "0"],
    expected="--width requires a positive integer",
  )
  assert_parse_error(["svgdiff", "a.svg", "b.svg", "--unknown", "x"])
  assert_parse_error(
    ["svgdiff", "a.svg", "b.svg", "--perceptual-background", "transparent"],
    expected="--perceptual-background requires an opaque deterministic sRGB color",
  )
  for value in ["0", "4097", "nan", "inf", "invalid"] {
    assert_parse_error(
      ["svgdiff", "a.svg", "b.svg", "--flip-pixels-per-degree", value],
      expected="--flip-pixels-per-degree requires a finite number in [1, 4096]",
    )
  }
  for value in ["-0.001", "1.001", "nan", "inf", "invalid"] {
    assert_parse_error(
      ["svgdiff", "a.svg", "b.svg", "--flip-error-threshold", value],
      expected="--flip-error-threshold requires a finite number in [0, 1]",
    )
  }
  assert_parse_error(
    ["svgdiff", "-", "-"],
    expected="Only one SVG input may use stdin (-)",
  )
  assert_parse_error(
    [
      "svgdiff", "a.svg", "b.svg", "--before-resource", "{\"locator\":\"asset\"}",
    ],
    expected="--before-resource requires a JSON object with string locator, media_type, and path fields",
  )
  assert_parse_error(
    [
      "svgdiff", "a.svg", "b.svg", "--before-resource", "{\"locator\":\"asset\",\"media_type\":\"image/png\",\"path\":\"-\"}",
    ],
    expected="Resource path may not use stdin (-)",
  )
}

///|
test "CLI accepts one explicit stdin operand" {
  let before_stdin = @cli.parse(["svgdiff", "-", "after.svg"])
  assert_eq(before_stdin.before_path, "-")
  assert_eq(before_stdin.after_path, "after.svg")
  let after_stdin = @cli.parse(["svgdiff", "before.svg", "-"])
  assert_eq(after_stdin.before_path, "before.svg")
  assert_eq(after_stdin.after_path, "-")
}

///|
test "program name does not change the CLI contract" {
  let native = @cli.parse(["svgdiff", "before.svg", "after.svg"])
  let wasm = @cli.parse(["svgdiff.wasm", "before.svg", "after.svg"])
  assert_eq(native.before_path, wasm.before_path)
  assert_eq(native.after_path, wasm.after_path)
  assert_eq(native.width, wasm.width)
  assert_eq(native.height, wasm.height)
  assert_eq(native.max_checkpoints, wasm.max_checkpoints)
}

///|
test "shared CLI comparison emits selected Agent JSON" {
  let config = @cli.parse(["svgdiff", "before.svg", "after.svg", "--agent-json"])
  let report = @cli.compare_sources(
    "<svg width='16' height='16'><rect x='1' y='1' width='8' height='8' fill='red'/></svg>",
    "<svg width='16' height='16'><rect x='1' y='1' width='8' height='8' fill='blue'/></svg>",
    config,
    @svgdiff.ResourceBundle::empty(),
    @svgdiff.ResourceBundle::empty(),
  )
  let json = @cli.serialize_report(report, config)
  assert_true(json.contains("\"schema_version\":\"5.0\""))
  assert_true(json.contains("\"difference_groups\""))
  assert_true(json.contains("\"events\""))
  assert_true(json.contains("\"limitations\""))
  assert_false(json.contains("\n"))
}
