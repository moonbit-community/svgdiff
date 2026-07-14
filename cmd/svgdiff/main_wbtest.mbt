///|
test "CLI parses paths viewport and output" {
  let config = parse_cli([
    "svgdiff", "before.svg", "after.svg", "--width", "32", "--height", "24", "--output",
    "report.json", "--html", "report.html",
  ])
  match config {
    Some(config) => {
      assert_eq(config.before_path, "before.svg")
      assert_eq(config.after_path, "after.svg")
      assert_eq(config.width, 32)
      assert_eq(config.height, 24)
      assert_eq(config.output_path, Some("report.json"))
      assert_eq(config.html_path, Some("report.html"))
    }
    None => fail("expected valid CLI configuration")
  }
}

///|
test "CLI rejects missing and invalid arguments" {
  assert_true(parse_cli(["svgdiff"]) is None)
  assert_true(parse_cli(["svgdiff", "a.svg", "b.svg", "--width", "0"]) is None)
  assert_true(
    parse_cli(["svgdiff", "a.svg", "b.svg", "--unknown", "x"]) is None,
  )
}

///|
test "CLI help documents options and exit statuses" {
  let help = help_text()
  assert_true(help.has_prefix("Usage: svgdiff"))
  assert_true(help.contains("--width N"))
  assert_true(help.contains("--height N"))
  assert_true(help.contains("--output FILE"))
  assert_true(help.contains("--html FILE"))
  assert_true(help.contains("--help"))
  assert_true(help.contains("--version"))
  assert_true(help.contains("2  Invalid arguments or file I/O failure"))
}

///|
test "CLI version exposes every contract identity" {
  assert_eq(
    version_text(),
    "svgdiff 0.1.0\nengine: 0.1.0\nschema: 1.0\nrenderer: mizchi/svg@0.2.1\nordering-policy: v1_domain_lexicographic",
  )
}
