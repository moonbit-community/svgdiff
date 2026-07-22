///|
using @model {type ComparisonProfile}

///|
using @computed_effects {
  type BlendSemanticDocument,
  type BlendSite,
  resolve_blend_semantic_document_or_raise,
  resolve_filter_hosts_or_raise,
}

///|
using @style {blend_mode_from_keyword}

///|
using @rendered {
  group_compositor_atomic_container,
  group_compositor_children,
  group_compositor_container,
  group_compositor_over_image,
  group_compositor_render_container,
  group_compositor_render_leaf,
  group_compositor_render_masked_container,
}

///|
using @normalization {normalize_renderer_input_with_profile}
