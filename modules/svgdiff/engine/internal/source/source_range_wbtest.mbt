///|
test "source ranges preserve UTF-16 offsets" {
  let input = "A😀B"
  assert_eq(source_range_slice(input, 1, 3), "😀")
  let high = source_range_slice(input, 1, 2)
  let low = source_range_slice(input, 2, 3)
  assert_eq(high.length(), 1)
  assert_eq(low.length(), 1)
  assert_eq(high[0], input[1])
  assert_eq(low[0], input[2])
  assert_eq(source_range_slice(input, 4, 4), "")
}
