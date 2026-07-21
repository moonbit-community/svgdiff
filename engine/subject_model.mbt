///|
priv struct SourceSubject {
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
priv struct StructuralAlignmentSubject {
  reference : SubjectReference
  path_signature : String
  semantic_signature : String
}
