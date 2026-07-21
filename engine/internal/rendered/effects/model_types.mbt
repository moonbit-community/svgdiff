///|
using @model {type ComparisonProfile}

///|
using @computed {type CssBounds}

///|
using @computed_effects {
  type BlendSemanticDocument,
  type BlendSite,
  type ResolvedFilterHost,
  resolve_blend_semantic_document_or_raise,
  resolve_filter_hosts_or_raise,
}

///|
using @style {blend_mode_from_keyword}

///|
using @rendered {
  group_compositor_apply_opacity,
  group_compositor_atomic_container,
  group_compositor_children,
  group_compositor_clear_outside_bounds,
  group_compositor_container,
  group_compositor_over_image,
  group_compositor_render_container,
  group_compositor_render_leaf,
  group_compositor_render_masked_container,
  render_product_document_to_image,
}

///|
using @normalization {normalize_renderer_input_with_profile}
