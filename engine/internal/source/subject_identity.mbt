///|
pub fn authored_subject_id(element : @xml.NamespaceElement) -> String? {
  for attribute in element.attributes {
    if attribute.name.local_name == "id" {
      let id = attribute.value.trim().to_owned()
      if id != "" {
        return Some(id)
      }
    }
  }
  None
}

///|
pub fn generated_subject_id(kind : String, index : Int) -> String {
  "\{kind}:\{index}"
}
