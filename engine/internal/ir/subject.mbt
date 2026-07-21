///|
pub(all) struct MarkerPlacement {
  resource_id : String
  bounds : CssBounds
}

///|
pub(all) struct SourceSubject {
  reference : SubjectReference
  signature : String
  hierarchy_signature : String
  structural_parent_path_signature : String
  instance_resolution_signature : String
  kind : String
  values : Array[(String, String)]
  facts : Array[DeclaredVisualFact]
  resolved_visual_facts : Array[ResolvedVisualFact]
  geometry_invalid_facts : Array[DeclaredVisualFact]
  geometry_complete : Bool
  fillable_interior : Bool
  renders_geometry : Bool
  stroke_invalid_facts : Array[DeclaredVisualFact]
  stroke_complete : Bool
  stroke_paint_present : Bool
  stroke_path_present : Bool
  stroke_active : Bool
  stroke_conservative_expansion : Double
  stroke_non_scaling : Bool
  marker_invalid_facts : Array[DeclaredVisualFact]
  marker_effective_facts : Array[DeclaredVisualFact]
  marker_complete : Bool
  marker_active : Bool
  marker_placements : Array[MarkerPlacement]
  path_segments : Array[PathSegmentEvidence]
  path_data_complete : Bool
  transform_chain : Array[SourceTransformSite]
  cumulative_transform : AffineTransform
  transform_complete : Bool
  viewport : ViewportContext
  resource_owner_id : String?
  clip_path_owner_id : String?
  clip_resource_id : String?
  clip_complete : Bool
  clip_effect_bounds : CssBounds?
  clip_issue_codes : Array[String]
  mask_owner_id : String?
  mask_resource_id : String?
  mask_mode : String?
  mask_outcome : String?
  mask_complete : Bool
  mask_effect_bounds : CssBounds?
  mask_issue_codes : Array[String]
  source_offset : Int
}

///|
pub(all) struct StructuralAlignmentSubject {
  reference : SubjectReference
  path_signature : String
  semantic_signature : String
}

///|
pub fn source_subject_id(subject : SourceSubject) -> String {
  match subject.reference.instance_context {
    Some(context) => context.instance_id
    None =>
      subject.reference.authored_id.unwrap_or(
        "\{subject.kind}:\{subject.reference.source_index}",
      )
  }
}

///|
pub fn subject_value(subject : SourceSubject, property : String) -> String? {
  for item in subject.values {
    let (name, value) = item
    if name == property {
      return Some(value)
    }
  }
  None
}

///|
pub fn source_subject_resolution(
  subject : SourceSubject,
  property : String,
) -> ResolvedVisualFact? {
  for fact in subject.resolved_visual_facts {
    if fact.property == property {
      return Some({ ..fact, subject_id: source_subject_id(subject) })
    }
  }
  None
}

///|
pub fn source_subject_fact(
  subject : SourceSubject,
  property : String,
) -> DeclaredVisualFact? {
  for fact in subject.facts {
    if fact.property == property {
      return Some(fact)
    }
  }
  if subject.reference.instance_context is Some(_) {
    source_subject_resolution(subject, property).bind(resolution => {
      resolution.declaration
    })
  } else {
    None
  }
}

///|
pub fn source_subject_ids(
  before : Array[SourceSubject],
  after : Array[SourceSubject],
) -> Array[String] {
  let ids : Array[String] = []
  for subject in before {
    let id = source_subject_id(subject)
    if !ids.contains(id) {
      ids.push(id)
    }
  }
  for subject in after {
    let id = source_subject_id(subject)
    if !ids.contains(id) {
      ids.push(id)
    }
  }
  ids
}

///|
pub fn subjects_for_references(
  subjects : Array[SourceSubject],
  references : Array[SubjectReference],
) -> Array[SourceSubject] {
  let selected : Array[SourceSubject] = []
  for reference in references {
    for subject in subjects {
      if subject.reference.source_index == reference.source_index &&
        subject.reference.kind == reference.kind {
        selected.push(subject)
        break
      }
    }
  }
  selected
}
