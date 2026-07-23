///|
test "CLI parses explicit deterministic comparison inputs" {
  match
    parse_cli([
      "svgdiff_miniio", "before.svg", "after.svg", "--width", "32", "--height", "24",
      "--max-checkpoints", "4096", "--perceptual-background", "#ffffff", "--flip-pixels-per-degree",
      "67", "--flip-error-threshold", "0.25",
    ]) {
    Config(config) => {
      assert_eq(config.before_path, "before.svg")
      assert_eq(config.after_path, "after.svg")
      assert_eq(config.width, 32)
      assert_eq(config.height, 24)
      assert_eq(config.max_checkpoints, 4096)
      assert_true(config.perceptual_background is Some(_))
      assert_true(config.flip_viewing_conditions is Some(_))
      assert_true(config.flip_error_threshold is Some(_))
    }
    Invalid(message) => fail("expected valid config: \{message}")
  }
}

///|
test "CLI rejects unsafe or incomplete profile inputs" {
  assert_true(
    parse_cli(["svgdiff_miniio", "-", "-"])
    is Invalid("Only one SVG input may use stdin (-)"),
  )
  assert_true(
    parse_cli([
      "svgdiff_miniio", "before.svg", "after.svg", "--max-checkpoints", "0",
    ])
    is Invalid("--max-checkpoints requires a positive integer"),
  )
  assert_true(
    parse_cli([
      "svgdiff_miniio", "before.svg", "after.svg", "--flip-pixels-per-degree", "67",
    ])
    is Invalid("--flip-pixels-per-degree requires --perceptual-background"),
  )
}

///|
test "skill comparison emits concise agent JSON" {
  let config = match
    parse_cli([
      "svgdiff_miniio", "before.svg", "after.svg", "--width", "16", "--height", "16",
    ]) {
    Config(config) => config
    Invalid(message) => fail("expected valid config: \{message}")
  }
  let report = compare_sources(
    "<svg width='16' height='16'><rect x='1' y='1' width='8' height='8' fill='red'/></svg>",
    "<svg width='16' height='16'><rect x='1' y='1' width='8' height='8' fill='blue'/></svg>",
    config,
  )
  let json = report.to_compact_json_string()
  assert_true(json.contains("\"schema_version\":\"2.0\""))
  assert_true(json.contains("\"difference_groups\""))
  assert_true(json.contains("\"events\""))
  assert_true(json.contains("\"limitations\""))
}
