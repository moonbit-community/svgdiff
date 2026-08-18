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
test "scene comparison preserves semantic objects across representation changes" {
  let before =
    #|<svg width="100" height="60">
    #|  <g class="entity" transform="translate(2 2)">
    #|    <rect width="40" height="20" fill="white" stroke="black"/>
    #|    <text x="4" y="12">Account</text>
    #|  </g>
    #|  <g class="entity" transform="translate(55 30)">
    #|    <rect width="40" height="20" fill="white" stroke="black"/>
    #|    <text x="4" y="12">Customer</text>
    #|  </g>
    #|  <g class="link"><path d="M42 12L55 40" stroke="black"/></g>
    #|</svg>
  let after =
    #|<svg width="120" height="80">
    #|  <g class="entity" transform="translate(5 5)">
    #|    <rect width="44" height="24" fill="#f8f8f8" stroke="black"/>
    #|    <circle cx="6" cy="8" r="4" fill="white"/>
    #|    <text x="4" y="12">A</text>
    #|    <text x="12" y="12">Account</text>
    #|  </g>
    #|  <g class="entity" transform="translate(65 42)">
    #|    <rect width="44" height="24" fill="#f8f8f8" stroke="black"/>
    #|    <circle cx="6" cy="8" r="4" fill="white"/>
    #|    <text x="4" y="12">C</text>
    #|    <text x="12" y="12">Customer</text>
    #|  </g>
    #|  <path class="relation" d="M49 17L65 54" stroke="black"/>
    #|</svg>
  let analysis = compare_visual_scenes(
    before,
    after,
    @model.ComparisonProfile::v1_default(),
  )
  assert_eq(analysis.summary.before_object_count, 2)
  assert_eq(analysis.summary.after_object_count, 2)
  assert_eq(analysis.summary.before_relation_count, 1)
  assert_eq(analysis.summary.after_relation_count, 1)
  assert_eq(analysis.summary.content, "preserved")
  assert_eq(analysis.summary.object_set, "preserved")
  assert_eq(analysis.summary.relation_graph, "preserved")
  assert_eq(analysis.summary.layout, "changed")
  assert_eq(analysis.summary.style, "changed")
  assert_eq(analysis.summary.representation, "changed")
  assert_true(
    analysis.alignments.all(alignment => {
      alignment.relation == "correspondence" &&
      alignment.before_object_ids.length() == 1 &&
      alignment.after_object_ids.length() == 1
    }),
  )
}

///|
test "scene alignment keeps an object identity when its label changes" {
  let before =
    #|<svg><g><rect width="10" height="10"/><text>Account</text></g></svg>
  let after =
    #|<svg><g><rect width="10" height="10"/><text>Invoice</text></g></svg>
  let analysis = compare_visual_scenes(
    before,
    after,
    @model.ComparisonProfile::v1_default(),
  )
  assert_eq(analysis.summary.content, "changed")
  assert_eq(analysis.summary.object_set, "preserved")
  assert_true(
    analysis.alignments.all(alignment => alignment.relation == "correspondence"),
  )
}

///|
test "scene alignment abstains from unsupported geometric guesses" {
  let before =
    #|<svg width="200" height="200"><rect width="10" height="10"/></svg>
  let after =
    #|<svg width="200" height="200"><circle cx="180" cy="180" r="10"/></svg>
  let analysis = compare_visual_scenes(
    before,
    after,
    @model.ComparisonProfile::v1_default(),
  )
  assert_eq(analysis.summary.object_set, "indeterminate")
  assert_true(
    analysis.alignments.all(alignment => alignment.ambiguity == "abstained"),
  )
}

///|
test "scene style compares effective colors instead of source spelling" {
  let before =
    #|<svg><rect id="box" width="10" height="10" fill="red"/></svg>
  let after =
    #|<svg><rect id="box" width="10" height="10" fill="#ff0000"/></svg>
  let analysis = compare_visual_scenes(
    before,
    after,
    @model.ComparisonProfile::v1_default(),
  )
  assert_eq(analysis.summary.content, "preserved")
  assert_eq(analysis.summary.object_set, "preserved")
  assert_eq(analysis.summary.layout, "preserved")
  assert_eq(analysis.summary.style, "preserved")
  assert_eq(analysis.summary.representation, "preserved")
}

///|
test "scene comparison recognizes one shared axis-aligned affine layout change" {
  let before =
    #|<svg width="100" height="100"><rect id="a" x="10" y="10" width="10" height="10"/><rect id="b" x="40" y="30" width="20" height="10"/></svg>
  let after =
    #|<svg width="100" height="100"><g transform="translate(5 7) scale(2 3)"><rect id="a" x="10" y="10" width="10" height="10"/><rect id="b" x="40" y="30" width="20" height="10"/></g></svg>
  let analysis = compare_visual_scenes(
    before,
    after,
    @model.ComparisonProfile::v1_default(),
  )
  assert_eq(analysis.summary.layout, "changed")
  assert_true(
    analysis.events.any(event => event.kind == "layout.global_affine"),
  )
  assert_false(analysis.events.any(event => event.kind == "layout.reflow"))
}

///|
test "scene content follows aligned objects instead of only the global text set" {
  let before =
    #|<svg width="100" height="40">
    #|  <g id="left"><rect width="40" height="20"/><text>Account</text></g>
    #|  <g id="right" transform="translate(50 0)"><rect width="40" height="20"/><text>Invoice</text></g>
    #|</svg>
  let after =
    #|<svg width="100" height="40">
    #|  <g id="left"><rect width="40" height="20"/><text>Invoice</text></g>
    #|  <g id="right" transform="translate(50 0)"><rect width="40" height="20"/><text>Account</text></g>
    #|</svg>
  let analysis = compare_visual_scenes(
    before,
    after,
    @model.ComparisonProfile::v1_default(),
  )
  assert_eq(analysis.summary.content, "changed")
  assert_eq(analysis.summary.object_set, "preserved")
  let content_changes = analysis.events.filter(event => {
    event.kind == "content.change"
  })
  assert_eq(content_changes.length(), 2)
  assert_true(
    content_changes.all(event => event.object_change_ids.length() == 1),
  )
}

///|
test "scene alignment abstains when several before objects tie for one target" {
  let before =
    #|<svg width="80" height="20"><rect x="0" width="10" height="10"/><rect x="20" width="10" height="10"/></svg>
  let after =
    #|<svg width="80" height="20"><rect x="10" width="10" height="10"/></svg>
  let analysis = compare_visual_scenes(
    before,
    after,
    @model.ComparisonProfile::v1_default(),
  )
  assert_eq(analysis.summary.object_set, "indeterminate")
  assert_true(
    analysis.alignments.all(alignment => alignment.ambiguity == "abstained"),
  )
}

///|
test "scene alignment abstains from tied semantic overlap" {
  let before =
    #|<svg width="400" height="40"><g><rect width="30" height="20"/><text>Account</text><text>Primary</text></g></svg>
  let after =
    #|<svg width="400" height="40"><g transform="translate(150 0)"><rect width="30" height="20"/><text>Account</text><text>Foo</text></g><g transform="translate(300 0)"><rect width="30" height="20"/><text>Account</text><text>Bar</text></g></svg>
  let analysis = compare_visual_scenes(
    before,
    after,
    @model.ComparisonProfile::v1_default(),
  )
  assert_eq(analysis.summary.object_set, "indeterminate")
  assert_true(
    analysis.alignments.all(alignment => alignment.ambiguity == "abstained"),
  )
}

///|
test "relation decorations are excluded without becoming graph edges" {
  let source =
    #|<svg width="100" height="40">
    #|  <g id="a"><rect width="30" height="20"/><text>Alice</text></g>
    #|  <g id="b" transform="translate(60 0)"><rect width="30" height="20"/><text>Bob</text></g>
    #|  <path class="relation-decoration" d="M30 10L60 10"/>
    #|  <g class="relation-decoration"><path d="M30 12L60 12"/></g>
    #|</svg>
  let analysis = compare_visual_scenes(
    source,
    source,
    @model.ComparisonProfile::v1_default(),
  )
  assert_eq(analysis.summary.before_object_count, 2)
  assert_eq(analysis.summary.before_relation_count, 0)
  assert_eq(analysis.summary.relation_graph, "preserved")
}

///|
test "ordinary grouped paths remain visual objects instead of relations" {
  let source =
    #|<svg width="100" height="40">
    #|  <g class="icon"><path d="M0 0L10 10"/><path d="M10 0L0 10"/></g>
    #|</svg>
  let analysis = compare_visual_scenes(
    source,
    source,
    @model.ComparisonProfile::v1_default(),
  )
  assert_eq(analysis.summary.before_object_count, 2)
  assert_eq(analysis.summary.before_relation_count, 0)
  assert_eq(analysis.summary.relation_graph, "preserved")
}

///|
test "scene events localize only their affected object alignments" {
  let before =
    #|<svg width="100" height="40"><rect id="size" width="10" height="10" fill="red"/><rect id="color" x="60" width="10" height="10" fill="red"/></svg>
  let after =
    #|<svg width="100" height="40"><rect id="size" width="20" height="10" fill="red"/><rect id="color" x="60" width="10" height="10" fill="blue"/></svg>
  let analysis = compare_visual_scenes(
    before,
    after,
    @model.ComparisonProfile::v1_default(),
  )
  let layout = analysis.object_changes.filter(change => {
      change.kind == "layout.reflow"
    })[0]
  let style = analysis.object_changes.filter(change => {
      change.kind == "style.change"
    })[0]
  assert_true(layout.object_alignment_id != style.object_alignment_id)
}
