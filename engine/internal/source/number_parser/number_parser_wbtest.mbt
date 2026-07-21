///|
test "number parser accepts compact, fractional, and exponent forms" {
  let parser : NumberParser = { data: "-1.25e+2.5", position: 0 }
  assert_eq(parser.parse_number(), Some(-125.0))
  assert_eq(parser.parse_number(), Some(0.5))
  assert_eq(parser.position, 10)
}

///|
test "number parser restores its cursor after an invalid exponent" {
  let parser : NumberParser = { data: "1e+", position: 0 }
  assert_eq(parser.parse_number(), None)
  assert_eq(parser.position, 0)
}
