// Whitebox tests run within the package scope.
// Use them to validate internal helpers or invariants.
// Keep them focused; public behavior belongs in `_test.mbt`.

///|
test "HTML preview injects the Comparison Viewport as a missing root viewBox" {
  assert_eq(
    preview_source(
      "<?xml version='1.0'?><!-- source --><svg width='16' height='16'><rect/></svg>",
      16, 16,
    ),
    "<?xml version='1.0'?><!-- source --><svg width='16' height='16' viewBox=\"0 0 16 16\"><rect/></svg>",
  )
  assert_eq(
    preview_source("<svg width='16' height='16'/>", 16, 16),
    "<svg width='16' height='16' viewBox=\"0 0 16 16\"/>",
  )
}

///|
test "HTML preview preserves an authored root viewBox and malformed source" {
  let with_view_box = "<svg width='16' height='16' viewBox='0 0 8 8'><rect/></svg>"
  assert_eq(preview_source(with_view_box, 16, 16), with_view_box)
  let malformed = "<svg width='16'><rect></svg>"
  assert_eq(preview_source(malformed, 16, 16), malformed)
}
