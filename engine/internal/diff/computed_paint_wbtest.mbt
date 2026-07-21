///|
test "computed solid paint includes color paint and leaf alpha factors" {
  let source = "<svg><rect id='box' width='8' height='8' fill='rgba(255,0,0,0.5)' fill-opacity='25%' opacity='0.5'/></svg>"
  let subject = extract_source_subjects_or_raise(source)[0]
  assert_eq(
    generic_subject_computed_value(
      subject,
      "fill",
      source_subject_fact(subject, "fill"),
    ),
    Some("rgba(255,0,0,0.0625)"),
  )
}
