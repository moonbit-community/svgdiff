///|
pub(all) struct SourceTransformSite {
  node_index : Int
  subject_id : String
  authored_id : String?
  kind : String
  fact : DeclaredVisualFact?
  normalized_signature : String
  matrix : AffineTransform
  complete : Bool
  viewport_facts : Array[DeclaredVisualFact]
  viewport_matrix : AffineTransform
  viewport_complete : Bool
}

///|
pub fn source_transform_site(
  input : String,
  element : @xml.NamespaceElement,
  node_index : Int,
) -> SourceTransformSite {
  let subject_id = authored_subject_id(element).unwrap_or(
    generated_subject_id(element.name.local_name, node_index),
  )
  for attribute in element.attributes {
    if attribute.name.local_name == "transform" {
      let fact = presentation_fact(input, "transform", attribute)
      return match parse_transform_list(attribute.value) {
        ValidTransformList(normalized) =>
          {
            node_index,
            subject_id,
            authored_id: authored_subject_id(element),
            kind: element.name.local_name,
            fact: Some(fact),
            normalized_signature: normalized.signature,
            matrix: normalized.matrix,
            complete: true,
            viewport_facts: [],
            viewport_matrix: AffineTransform::identity(),
            viewport_complete: true,
          }
        InvalidTransformList =>
          {
            node_index,
            subject_id,
            authored_id: authored_subject_id(element),
            kind: element.name.local_name,
            fact: Some(fact),
            normalized_signature: "",
            matrix: AffineTransform::identity(),
            complete: false,
            viewport_facts: [],
            viewport_matrix: AffineTransform::identity(),
            viewport_complete: true,
          }
      }
    }
  }
  {
    node_index,
    subject_id,
    authored_id: authored_subject_id(element),
    kind: element.name.local_name,
    fact: None,
    normalized_signature: "",
    matrix: AffineTransform::identity(),
    complete: true,
    viewport_facts: [],
    viewport_matrix: AffineTransform::identity(),
    viewport_complete: true,
  }
}

///|
pub fn cumulative_transform(
  chain : Array[SourceTransformSite],
) -> (AffineTransform, Bool, Bool) {
  let mut matrix = AffineTransform::identity()
  let mut complete = true
  let mut has_transform = false
  for site in chain {
    if site.fact is Some(_) {
      has_transform = true
    }
    if !site.complete || !site.viewport_complete {
      complete = false
    }
    matrix = matrix.multiply(site.matrix).multiply(site.viewport_matrix)
    if !site.viewport_matrix.is_identity() || !site.viewport_facts.is_empty() {
      has_transform = true
    }
  }
  (matrix, complete, has_transform)
}
