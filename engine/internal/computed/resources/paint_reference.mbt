///|
pub fn authored_paint_server_reference(
  subject : SourceSubject,
  property : String,
) -> String? {
  match source_subject_fact(subject, property) {
    Some(fact) => paint_server_reference(fact.declared_value)
    None =>
      paint_server_reference(subject_value(subject, property).unwrap_or(""))
  }
}
