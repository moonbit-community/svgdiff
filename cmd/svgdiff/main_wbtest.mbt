///|
test "CLI parses paths viewport and output" {
  let config = parse_cli([
    "svgdiff", "before.svg", "after.svg", "--width", "32", "--height", "24", "--output",
    "report.json", "--html", "report.html", "--agent-json", "--before-resource",
    "asset.png", "image/png", "before.png", "--after-resource", "asset.png", "image/png",
    "after.png", "--perceptual-background", "#336699", "--flip-pixels-per-degree",
    "67",
  ])
  match config {
    Config(config) => {
      assert_eq(config.before_path, "before.svg")
      assert_eq(config.after_path, "after.svg")
      assert_eq(config.width, 32)
      assert_eq(config.height, 24)
      assert_eq(config.output_path, Some("report.json"))
      assert_eq(config.html_path, Some("report.html"))
      assert_true(config.agent_json)
      assert_eq(config.before_resources.length(), 1)
      assert_eq(config.before_resources[0].locator, "asset.png")
      assert_eq(config.before_resources[0].media_type, "image/png")
      assert_eq(config.before_resources[0].path, "before.png")
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
    }
    Invalid(message) => fail("expected valid CLI configuration: \{message}")
  }
}

///|
test "CLI keeps canonical JSON as the default" {
  match parse_cli(["svgdiff", "before.svg", "after.svg"]) {
    Config(config) => assert_false(config.agent_json)
    Invalid(message) => fail("expected default configuration: \{message}")
  }
}

///|
test "CLI rejects missing and invalid arguments" {
  assert_true(parse_cli(["svgdiff"]) is Invalid(_))
  assert_true(
    parse_cli(["svgdiff", "a.svg", "b.svg", "--width", "0"]) is Invalid(_),
  )
  assert_true(
    parse_cli(["svgdiff", "a.svg", "b.svg", "--unknown", "x"]) is Invalid(_),
  )
  assert_true(
    parse_cli([
      "svgdiff", "a.svg", "b.svg", "--perceptual-background", "transparent",
    ])
    is Invalid(_),
  )
  for value in ["0", "4097", "nan", "inf", "invalid"] {
    assert_true(
      parse_cli(["svgdiff", "a.svg", "b.svg", "--flip-pixels-per-degree", value])
      is Invalid(_),
    )
  }
  assert_true(parse_cli(["svgdiff", "-", "-"]) is Invalid(_))
  assert_true(
    parse_cli([
      "svgdiff", "a.svg", "b.svg", "--before-resource", "asset", "image/png",
    ])
    is Invalid(_),
  )
  assert_true(
    parse_cli([
      "svgdiff", "a.svg", "b.svg", "--before-resource", "asset", "image/png", "-",
    ])
    is Invalid(_),
  )
}

///|
test "CLI accepts one explicit stdin operand" {
  match parse_cli(["svgdiff", "-", "after.svg"]) {
    Config(config) => {
      assert_eq(config.before_path, "-")
      assert_eq(config.after_path, "after.svg")
    }
    Invalid(message) => fail("expected before stdin: \{message}")
  }
  match parse_cli(["svgdiff", "before.svg", "-"]) {
    Config(config) => {
      assert_eq(config.before_path, "before.svg")
      assert_eq(config.after_path, "-")
    }
    Invalid(message) => fail("expected after stdin: \{message}")
  }
}

///|
test "CLI help documents options and exit statuses" {
  let help = help_text()
  assert_true(help.has_prefix("Usage: svgdiff"))
  assert_true(help.contains("--width N"))
  assert_true(help.contains("--height N"))
  assert_true(help.contains("--perceptual-background COLOR"))
  assert_true(help.contains("--flip-pixels-per-degree PPD"))
  assert_true(help.contains("--output FILE"))
  assert_true(help.contains("--before-resource LOCATOR MEDIA_TYPE FILE"))
  assert_true(help.contains("--after-resource LOCATOR MEDIA_TYPE FILE"))
  assert_true(help.contains("read only when named"))
  assert_true(help.contains("--html FILE"))
  assert_true(help.contains("--agent-json"))
  assert_true(help.contains("--help"))
  assert_true(help.contains("--version"))
  assert_true(help.contains("Use - for exactly one input"))
  assert_true(help.contains("2  Invalid arguments or file I/O failure"))
}

///|
test "CLI version exposes every contract identity" {
  assert_eq(
    version_text(),
    "svgdiff 0.5.21\nengine: 0.5.21\nschema: 1.41\nrenderer: svgdiff/style-precedence-normalizer@3+ordinary-inheritance-normalizer@1+css-computed-value-normalizer@3+css-color3-opacity-normalizer@1+length-used-value-normalizer@1+stroke-used-geometry-normalizer@1+basic-shape-used-geometry-normalizer@1+isolated-group-compositor@1+static-mask-normalizer@1+static-mask-compositor@1+static-filter-graph-compositor@1+static-blend-compositor@1+mizchi/svg@0.2.1\nrenderer-conformance-profile: svgdiff-renderer-conformance-profile/25\nordering-policy: v2_domain_lexicographic",
  )
}
