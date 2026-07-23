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
  match config {
    Ok(config) => {
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
    Err(message) => fail("expected valid CLI configuration: \{message}")
  }
}

///|
test "CLI keeps canonical JSON as the default" {
  match @cli.parse(["svgdiff", "before.svg", "after.svg"]) {
    Ok(config) => {
      assert_false(config.agent_json)
      assert_false(config.agent_projection)
      assert_true(config.summary_path is None)
      assert_true(config.max_checkpoints is None)
    }
    Err(message) => fail("expected default configuration: \{message}")
  }
}

///|
test "CLI selects one lossless Agent projection mode" {
  match
    @cli.parse(["svgdiff", "before.svg", "after.svg", "--agent-projection"]) {
    Ok(config) => {
      assert_false(config.agent_json)
      assert_true(config.agent_projection)
    }
    Err(message) => fail("expected Agent projection configuration: \{message}")
  }
  assert_true(
    @cli.parse([
      "svgdiff", "before.svg", "after.svg", "--agent-json", "--agent-projection",
    ])
    is Err(_),
  )
}

///|
test "CLI records a FLIP error threshold without inventing Viewing Conditions" {
  match
    @cli.parse([
      "svgdiff", "before.svg", "after.svg", "--flip-error-threshold", "0.25",
    ]) {
    Ok(config) => {
      assert_true(config.flip_viewing_conditions is None)
      guard config.flip_error_threshold is Some(threshold) else {
        fail("expected parsed FLIP error threshold")
      }
      assert_eq(threshold.value(), 0.25)
    }
    Err(message) => fail("expected threshold-only configuration: \{message}")
  }
}

///|
test "CLI rejects missing and invalid arguments" {
  assert_true(@cli.parse([]) is Err(_))
  assert_true(@cli.parse(["svgdiff"]) is Err(_))
  assert_true(
    @cli.parse(["svgdiff", "a.svg", "b.svg", "--width", "0"]) is Err(_),
  )
  assert_true(
    @cli.parse(["svgdiff", "a.svg", "b.svg", "--unknown", "x"]) is Err(_),
  )
  assert_true(
    @cli.parse([
      "svgdiff", "a.svg", "b.svg", "--perceptual-background", "transparent",
    ])
    is Err(_),
  )
  for value in ["0", "4097", "nan", "inf", "invalid"] {
    assert_true(
      @cli.parse([
        "svgdiff", "a.svg", "b.svg", "--flip-pixels-per-degree", value,
      ])
      is Err(_),
    )
  }
  for value in ["-0.001", "1.001", "nan", "inf", "invalid"] {
    assert_true(
      @cli.parse(["svgdiff", "a.svg", "b.svg", "--flip-error-threshold", value])
      is Err(_),
    )
  }
  assert_true(@cli.parse(["svgdiff", "-", "-"]) is Err(_))
  assert_true(
    @cli.parse([
      "svgdiff", "a.svg", "b.svg", "--before-resource", "{\"locator\":\"asset\"}",
    ])
    is Err(_),
  )
  assert_true(
    @cli.parse([
      "svgdiff", "a.svg", "b.svg", "--before-resource", "{\"locator\":\"asset\",\"media_type\":\"image/png\",\"path\":\"-\"}",
    ])
    is Err(_),
  )
}

///|
test "CLI accepts one explicit stdin operand" {
  match @cli.parse(["svgdiff", "-", "after.svg"]) {
    Ok(config) => {
      assert_eq(config.before_path, "-")
      assert_eq(config.after_path, "after.svg")
    }
    Err(message) => fail("expected before stdin: \{message}")
  }
  match @cli.parse(["svgdiff", "before.svg", "-"]) {
    Ok(config) => {
      assert_eq(config.before_path, "before.svg")
      assert_eq(config.after_path, "-")
    }
    Err(message) => fail("expected after stdin: \{message}")
  }
}

///|
test "CLI help documents options and exit statuses" {
  let help = @cli.command("svgdiff").render_help()
  assert_true(help.has_prefix("Usage: svgdiff"))
  assert_true(help.contains("--width <width>"))
  assert_true(help.contains("--height <height>"))
  assert_true(help.contains("--max-checkpoints <max-checkpoints>"))
  assert_true(help.contains("--perceptual-background <perceptual-background>"))
  assert_true(
    help.contains("--flip-pixels-per-degree <flip-pixels-per-degree>"),
  )
  assert_true(help.contains("--flip-error-threshold <flip-error-threshold>"))
  assert_true(help.contains("--output <output>"))
  assert_true(help.contains("--before-resource <before-resource>"))
  assert_true(help.contains("--after-resource <after-resource>"))
  assert_true(help.contains("locator, media_type, and path"))
  assert_true(help.contains("read only when named"))
  assert_true(help.contains("--html <html>"))
  assert_true(help.contains("--summary <summary>"))
  assert_true(help.contains("--agent-json"))
  assert_true(help.contains("--agent-projection"))
  assert_true(help.contains("--help"))
  assert_true(help.contains("--version"))
  assert_true(help.contains("Use - for exactly one input"))
  assert_true(help.contains("2  Invalid arguments or file I/O failure"))
}

///|
test "CLI version exposes every contract identity" {
  assert_eq(
    @cli.version_text("svgdiff"),
    "svgdiff 0.7.0\nengine: 0.7.0\nschema: 2.0\nagent-projection: svgdiff-agent-projection/1\nrenderer: svgdiff/residual-paint-normalizer@1+opacity-used-value-normalizer@1+length-unit-normalizer@1+shape-css-points-normalizer@1+stroke-length-normalizer@1+mask-edge-semantics-normalizer@1+isolated-group-compositor@1+static-mask-compositor@1+empty-filter-outcome-adapter@1+static-blend-compositor@1+Milky2018/svg@0.3.1\nrenderer-conformance-profile: svgdiff-renderer-conformance-profile/27\nordering-policy: v2_domain_lexicographic\nimpact-policy: event_rendered_pareto/v1",
  )
}

///|
test "program name does not change the CLI contract" {
  let native = @cli.parse(["svgdiff", "before.svg", "after.svg"])
  let miniio = @cli.parse(["svgdiff_miniio", "before.svg", "after.svg"])
  guard (native, miniio) is (Ok(native), Ok(miniio)) else {
    fail("expected both executable names to use the shared CLI contract")
  }
  assert_eq(native.before_path, miniio.before_path)
  assert_eq(native.after_path, miniio.after_path)
  assert_eq(native.width, miniio.width)
  assert_eq(native.height, miniio.height)
  assert_eq(native.max_checkpoints, miniio.max_checkpoints)
}

///|
test "shared CLI comparison emits selected Agent JSON" {
  let config = match
    @cli.parse(["svgdiff_miniio", "before.svg", "after.svg", "--agent-json"]) {
    Ok(config) => config
    Err(message) => fail("expected valid config: \{message}")
  }
  let report = @cli.compare_sources(
    "<svg width='16' height='16'><rect x='1' y='1' width='8' height='8' fill='red'/></svg>",
    "<svg width='16' height='16'><rect x='1' y='1' width='8' height='8' fill='blue'/></svg>",
    config,
    @svgdiff.ResourceBundle::empty(),
    @svgdiff.ResourceBundle::empty(),
  )
  let json = @cli.serialize_report(report, config)
  assert_true(json.contains("\"schema_version\":\"2.0\""))
  assert_true(json.contains("\"difference_groups\""))
  assert_true(json.contains("\"events\""))
  assert_true(json.contains("\"limitations\""))
  assert_false(json.contains("\n"))
}
