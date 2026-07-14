///|
fn affine_transform_values(transform : AffineTransform) -> Array[Double] {
  [transform.a, transform.b, transform.c, transform.d, transform.e, transform.f]
}

///|
fn affine_linear_determinant(transform : AffineTransform) -> Double {
  normalized_transform_component(
    transform.a * transform.d - transform.b * transform.c,
  )
}

///|
fn transform_component_relation(
  reason_code : String,
  diagnostic_ids : Array[String],
) -> ComputedRelation {
  { status: "different", reason_code, missing_side: None, diagnostic_ids }
}

///|
fn append_transform_effect_difference(
  alignment : SubjectAlignment,
  suffix : String,
  domain : String,
  reason_code : String,
  source_before : String,
  source_after : String,
  changed_fact_ids : Array[String],
  diagnostic_ids : Array[String],
  effect : TransformEffectMagnitude,
  differences : Array[AtomicDifference],
  difference_ids : Array[String],
) -> Unit {
  let id = "diff:\{alignment.id}:transform:effect:\{suffix}"
  differences.push({
    id,
    subject_role: "entity",
    subject_alignment_id: Some(alignment.id),
    domain,
    source_before,
    source_after,
    source_fact_before: None,
    source_fact_after: None,
    changed_fact_ids,
    evidence_layers: ["computed_appearance", "rendered_evidence"],
    computed_relation: transform_component_relation(reason_code, diagnostic_ids),
    parameter_delta_css_px: None,
    presence_magnitude: None,
    magnitude: {
      ..empty_difference_magnitude(),
      transform_effect: Some(effect),
    },
    domain_ordering: empty_domain_ordering(),
  })
  difference_ids.push(id)
}

///|
fn transform_translation_signature(x : Double, y : Double) -> String {
  "translate(\{x},\{y})"
}

///|
fn transform_rotation_signature(degrees : Double) -> String {
  "rotate(\{degrees})"
}

///|
fn transform_scale_signature(x : Double, y : Double) -> String {
  "scale(\{x},\{y})"
}

///|
fn transform_skew_signature(degrees : Double) -> String {
  "skewX(\{degrees})"
}

///|
fn different_linear_transform(
  before : AffineTransform,
  after : AffineTransform,
) -> Bool {
  before.a != after.a ||
  before.b != after.b ||
  before.c != after.c ||
  before.d != after.d
}

///|
fn append_transform_effect_differences(
  report : StructuredReport,
  alignment : SubjectAlignment,
  before : SourceSubject,
  after : SourceSubject,
  changed_fact_ids : Array[String],
  differences : Array[AtomicDifference],
  difference_ids : Array[String],
) -> Unit {
  let before_matrix = before.cumulative_transform
  let after_matrix = after.cumulative_transform
  let before_decomposition = decompose_affine_transform(before_matrix)
  let after_decomposition = decompose_affine_transform(after_matrix)
  let diagnostic_ids = transform_chain_renderer_diagnostic_ids(
    report, before, after,
  )
  if before_decomposition.translation_x_css_px !=
    after_decomposition.translation_x_css_px ||
    before_decomposition.translation_y_css_px !=
    after_decomposition.translation_y_css_px {
    let delta_x = normalized_transform_component(
      after_decomposition.translation_x_css_px -
      before_decomposition.translation_x_css_px,
    )
    let delta_y = normalized_transform_component(
      after_decomposition.translation_y_css_px -
      before_decomposition.translation_y_css_px,
    )
    append_transform_effect_difference(
      alignment,
      "translation",
      "geometry.transform.translation",
      "cumulative_transform_translation_differs",
      transform_translation_signature(
        before_decomposition.translation_x_css_px,
        before_decomposition.translation_y_css_px,
      ),
      transform_translation_signature(
        after_decomposition.translation_x_css_px,
        after_decomposition.translation_y_css_px,
      ),
      changed_fact_ids,
      diagnostic_ids,
      TranslationEffect({
        before_x_css_px: before_decomposition.translation_x_css_px,
        before_y_css_px: before_decomposition.translation_y_css_px,
        after_x_css_px: after_decomposition.translation_x_css_px,
        after_y_css_px: after_decomposition.translation_y_css_px,
        delta_x_css_px: delta_x,
        delta_y_css_px: delta_y,
        norm_css_px: @math.hypot(delta_x, delta_y),
      }),
      differences,
      difference_ids,
    )
  }
  match (before_decomposition.linear, after_decomposition.linear) {
    (Some(before_linear), Some(after_linear)) => {
      let rotation_delta = shortest_transform_angle_delta(
        before_linear.rotation_degrees,
        after_linear.rotation_degrees,
      )
      if rotation_delta != 0.0 {
        append_transform_effect_difference(
          alignment,
          "rotation",
          "geometry.transform.rotation",
          "cumulative_transform_rotation_differs",
          transform_rotation_signature(before_linear.rotation_degrees),
          transform_rotation_signature(after_linear.rotation_degrees),
          changed_fact_ids,
          diagnostic_ids,
          RotationEffect({
            before_degrees: before_linear.rotation_degrees,
            after_degrees: after_linear.rotation_degrees,
            signed_delta_degrees: rotation_delta,
            abs_delta_degrees: rotation_delta.abs(),
          }),
          differences,
          difference_ids,
        )
      }
      if before_linear.scale_x != after_linear.scale_x ||
        before_linear.scale_y != after_linear.scale_y {
        let x_delta = (after_linear.scale_x - before_linear.scale_x).abs()
        let y_delta = (after_linear.scale_y - before_linear.scale_y).abs()
        append_transform_effect_difference(
          alignment,
          "scale",
          "geometry.transform.scale",
          "cumulative_transform_scale_differs",
          transform_scale_signature(
            before_linear.scale_x,
            before_linear.scale_y,
          ),
          transform_scale_signature(after_linear.scale_x, after_linear.scale_y),
          changed_fact_ids,
          diagnostic_ids,
          ScaleEffect({
            before_x: before_linear.scale_x,
            before_y: before_linear.scale_y,
            after_x: after_linear.scale_x,
            after_y: after_linear.scale_y,
            max_abs_delta: x_delta.max(y_delta),
          }),
          differences,
          difference_ids,
        )
      }
      let skew_delta = shortest_transform_angle_delta(
        before_linear.skew_x_degrees,
        after_linear.skew_x_degrees,
      )
      if skew_delta != 0.0 {
        append_transform_effect_difference(
          alignment,
          "skew",
          "geometry.transform.skew",
          "cumulative_transform_skew_differs",
          transform_skew_signature(before_linear.skew_x_degrees),
          transform_skew_signature(after_linear.skew_x_degrees),
          changed_fact_ids,
          diagnostic_ids,
          SkewEffect({
            before_degrees: before_linear.skew_x_degrees,
            after_degrees: after_linear.skew_x_degrees,
            signed_delta_degrees: skew_delta,
            abs_delta_degrees: skew_delta.abs(),
          }),
          differences,
          difference_ids,
        )
      }
    }
    _ =>
      if different_linear_transform(before_matrix, after_matrix) {
        append_transform_effect_difference(
          alignment,
          "residual-matrix",
          "geometry.transform.residual_matrix",
          "singular_transform_linear_parts_differ",
          before_matrix.signature(),
          after_matrix.signature(),
          changed_fact_ids,
          diagnostic_ids,
          ResidualMatrixEffect({
            before_matrix: affine_transform_values(before_matrix),
            after_matrix: affine_transform_values(after_matrix),
            before_determinant: affine_linear_determinant(before_matrix),
            after_determinant: affine_linear_determinant(after_matrix),
          }),
          differences,
          difference_ids,
        )
      }
  }
}
