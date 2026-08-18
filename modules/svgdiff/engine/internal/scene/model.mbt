// Copyright 2026 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
priv struct SceneObject {
  summary : @model.VisualObjectSummary
  identity : String?
  style_signatures : Array[String]
  primitive_signatures : Array[String]
  primitive_indices : Array[Int]
}

///|
priv struct VisualScene {
  objects : Array[SceneObject]
  relations : Array[@model.VisualRelationSummary]
  semantic_text : Array[String]
}

///|
/// Parsed object-level comparison state reused by subject alignment and final
/// report assembly. Its implementation stays private to the scene package.
pub struct VisualSceneContext {
  analysis : @model.VisualSceneAnalysis
  object_change_plans : Array[(String, String)]
  before_subject_owners : Array[String?]
  after_subject_owners : Array[String?]
  before_subject_owner_entries : Array[(String, String)]
  after_subject_owner_entries : Array[(String, String)]
}

///|
priv struct AlignmentCandidate {
  before_index : Int
  after_index : Int
  common_text : Int
  total_text : Int
}

///|
priv struct GeometricCandidate {
  before_index : Int
  after_index : Int
  score : Double
  basis : String
}
