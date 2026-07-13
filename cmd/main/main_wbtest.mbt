///|
test "CLI parses paths viewport and output" {
  let config = parse_cli([
    "svgdiff", "before.svg", "after.svg", "--width", "32", "--height", "24", "--output",
    "report.json",
  ])
  match config {
    Some(config) => {
      assert_eq(config.before_path, "before.svg")
      assert_eq(config.after_path, "after.svg")
      assert_eq(config.width, 32)
      assert_eq(config.height, 24)
      assert_eq(config.output_path, Some("report.json"))
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
