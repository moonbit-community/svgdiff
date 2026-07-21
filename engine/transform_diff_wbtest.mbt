///|
fn transform_differences(report : StructuredReport) -> Array[AtomicDifference] {
  [
    for difference in report.atomic_differences if difference.domain.find(
      "geometry.transform.",
    ) ==
    Some(0) => difference
  ]
}

///|
test "equivalent transform lists retain source semantics only" {
  let before = "<svg width='16' height='16'><rect id='box' x='1' y='1' width='4' height='4' transform='translate(1)'/></svg>"
  let after = "<svg width='16' height='16'><rect id='box' x='1' y='1' width='4' height='4' transform='matrix(1 0 0 1 1 0)'/></svg>"
  let report = compare(before, after, ComparisonProfile::v1_default())
  let differences = transform_differences(report)
  assert_eq(report.analysis_status, "complete")
  assert_eq(differences.length(), 1)
  assert_eq(differences[0].domain, "geometry.transform.list")
  assert_eq(differences[0].computed_relation.status, "equivalent")
  assert_eq(
    differences[0].computed_relation.reason_code,
    "same_local_transform_matrix",
  )
  assert_eq(differences[0].source_before, "translate(1)")
  assert_eq(differences[0].source_after, "matrix(1 0 0 1 1 0)")
  assert_eq(
    report.events.last().unwrap().rendered_outcome.magnitude.unwrap().changed_pixels,
    0,
  )
}

///|
test "local transform change reports its cumulative matrix" {
  let before = "<svg width='16' height='16'><rect id='box' x='1' y='1' width='4' height='4' transform='translate(1 0)'/></svg>"
  let after = "<svg width='16' height='16'><rect id='box' x='1' y='1' width='4' height='4' transform='translate(3 0)'/></svg>"
  let report = compare(before, after, ComparisonProfile::v1_default())
  let differences = transform_differences(report)
  assert_eq(differences.length(), 3)
  assert_eq(differences[0].domain, "geometry.transform.list")
  assert_eq(differences[0].computed_relation.status, "different")
  assert_eq(differences[1].domain, "geometry.transform.cumulative_matrix")
  assert_eq(differences[1].source_before, "matrix(1,0,0,1,1,0)")
  assert_eq(differences[1].source_after, "matrix(1,0,0,1,3,0)")
  assert_true(differences[1].parameter_delta_css_px is None)
  assert_true(differences[1].magnitude.parameter_abs_user_units is None)
  assert_eq(differences[2].domain, "geometry.transform.translation")
  assert_true(
    differences[2].magnitude.transform_effect is Some(TranslationEffect(_)),
  )
  assert_eq(differences[2].magnitude.parameter_abs_css_px, Some(2.0))
  assert_eq(
    differences[2].magnitude.parameter_viewport_fraction,
    Some(0.08838834764831843),
  )
  assert_true(
    (differences[2].magnitude.parameter_entity_fraction.unwrap() -
    0.35355339059327373).abs() <
    0.000000000000001,
  )
  assert_eq(report.changed_facts.length(), 1)
}

///|
test "typed transform JSON retains zero components" {
  let report = compare(
    "<svg width='16' height='16'><rect id='box' width='4' height='4' transform='translate(1 0)'/></svg>",
    "<svg width='16' height='16'><rect id='box' width='4' height='4' transform='translate(3 0)'/></svg>",
    ComparisonProfile::v1_default(),
  )
  match @json.parse(report.to_json_string()) {
    {
      "atomic_differences": [
        _,
        _,
        {
          "domain": "geometry.transform.translation",
          "magnitude": {
            "transform_effect": {
              "kind": "translation",
              "delta_x_css_px": 2,
              "delta_y_css_px": 0,
              "norm_css_px": 2,
              ..
            },
            ..
          },
          ..
        },
      ],
      ..
    } => ()
    _ => fail("typed translation JSON omitted a measured zero component")
  }
}

///|
test "integer axis transforms are complete while general affine raster stays guarded" {
  let supported = compare(
    "<svg width='16' height='16'><rect id='box' width='4' height='4' transform='translate(1)'/></svg>",
    "<svg width='16' height='16'><rect id='box' width='4' height='4' transform='translate(3)'/></svg>",
    ComparisonProfile::v1_default(),
  )
  assert_eq(supported.analysis_status, "complete")
  let guarded = compare(
    "<svg width='16' height='16'><rect id='box' width='4' height='4' transform='skewX(10)'/></svg>",
    "<svg width='16' height='16'><rect id='box' width='4' height='4' transform='skewX(20)'/></svg>",
    ComparisonProfile::v1_default(),
  )
  assert_eq(guarded.analysis_status, "partial")
  assert_true(
    guarded.diagnostics.any(diagnostic => {
      diagnostic.code == "renderer_transform_raster_unproven" &&
      diagnostic.subject_id == "box" &&
      diagnostic.affected_evidence_layers == ["rendered_evidence"]
    }),
  )
  assert_true(
    guarded.atomic_differences.any(difference => {
      difference.domain == "geometry.transform.cumulative_matrix" &&
      difference.computed_relation.status == "different" &&
      !difference.computed_relation.diagnostic_ids.is_empty()
    }),
  )
}

///|
test "skew functions render identically to their equivalent matrices" {
  let cases = [
    ("skewX(0)", "skewX(45)", "matrix(1 0 0 1 0 0)", "matrix(1 0 1 1 0 0)"),
    ("skewY(0)", "skewY(45)", "matrix(1 0 0 1 0 0)", "matrix(1 1 0 1 0 0)"),
  ]
  let profiles = [
    ComparisonProfile::v1_default(),
    {
      ..ComparisonProfile::v1_default(),
      viewport_width: 32,
      viewport_height: 24,
    },
  ]
  for profile in profiles {
    for case in cases {
      let (before_function, after_function, before_matrix, after_matrix) = case
      let function_report = compare(
        "<svg width='16' height='16'><rect id='box' x='2' y='2' width='4' height='6' fill='red' transform='\{before_function}'/></svg>",
        "<svg width='16' height='16'><rect id='box' x='2' y='2' width='4' height='6' fill='red' transform='\{after_function}'/></svg>",
        profile,
      )
      let matrix_report = compare(
        "<svg width='16' height='16'><rect id='box' x='2' y='2' width='4' height='6' fill='red' transform='\{before_matrix}'/></svg>",
        "<svg width='16' height='16'><rect id='box' x='2' y='2' width='4' height='6' fill='red' transform='\{after_matrix}'/></svg>",
        profile,
      )
      let function_pixels = function_report.events.last().unwrap().rendered_outcome.magnitude.unwrap().changed_pixels
      let matrix_pixels = matrix_report.events.last().unwrap().rendered_outcome.magnitude.unwrap().changed_pixels
      assert_true(matrix_pixels > 0)
      assert_eq(function_pixels, matrix_pixels)
    }
  }
}

///|
test "ancestor affine guard constrains each affected transform domain row" {
  let before = "<svg><g id='layer' transform='skewX(10)'><rect id='box' width='4' height='4'/></g></svg>"
  let after = "<svg><g id='layer' transform='skewX(20)'><rect id='box' width='4' height='4'/></g></svg>"
  let report = compare(before, after, ComparisonProfile::v1_default())
  assert_true(
    report.coverage_matrix.any(row => {
      row.feature_id == "domain.geometry.transform.cumulative_matrix" &&
      row.subject_id == "alignment:0" &&
      row.rendered_evidence == "limited" &&
      !row.diagnostic_ids.is_empty()
    }),
  )
}

///|
test "compact signed transform numbers reach the renderer without partial parsing" {
  let source = "<svg width='16' height='16'><rect id='box' width='4' height='4' transform='translate(+.5-2E-1)'/></svg>"
  let report = compare(source, source, ComparisonProfile::v1_default())
  assert_eq(report.analysis_status, "partial")
  assert_true(
    report.diagnostics.any(diagnostic => {
      diagnostic.code == "renderer_transform_raster_unproven"
    }),
  )
  assert_true(
    report.diagnostics.all(diagnostic => {
      diagnostic.code != "transform_syntax_unsupported"
    }),
  )
}

///|
test "group transform fact fans out to every affected subject" {
  let before = "<svg width='16' height='16'><g id='layer' transform='translate(1 0)'><rect id='a' width='2' height='2'/><rect id='b' x='4' width='2' height='2'/></g></svg>"
  let after = "<svg width='16' height='16'><g id='layer' transform='translate(2 0)'><rect id='a' width='2' height='2'/><rect id='b' x='4' width='2' height='2'/></g></svg>"
  let report = compare(before, after, ComparisonProfile::v1_default())
  let differences = transform_differences(report)
  assert_eq(differences.length(), 6)
  let transform_facts = [
    for fact in report.changed_facts if fact.property == "transform" => fact
  ]
  assert_eq(transform_facts.length(), 1)
  assert_eq(transform_facts[0].subject_id, "layer")
  assert_eq(transform_facts[0].affected_subject_ids, ["a", "b"])
  assert_true(
    differences.all(difference => {
      difference.changed_fact_ids == [transform_facts[0].id]
    }),
  )
}

///|
fn transform_effect_difference(
  report : StructuredReport,
  domain : String,
) -> AtomicDifference {
  for difference in report.atomic_differences {
    if difference.domain == domain {
      return difference
    }
  }
  abort("expected transform effect difference")
}

///|
test "combined affine change emits typed translation rotation scale and skew" {
  let before = "<svg><rect id='box' width='4' height='4' transform='matrix(1 0 0 1 0 0)'/></svg>"
  let after = "<svg><rect id='box' width='4' height='4' transform='translate(3 4) rotate(30) skewX(20) scale(2 3)'/></svg>"
  let report = compare(before, after, ComparisonProfile::v1_default())
  let translation = transform_effect_difference(
    report, "geometry.transform.translation",
  )
  match translation.magnitude.transform_effect {
    Some(TranslationEffect(value)) => {
      assert_eq(value.delta_x_css_px, 3.0)
      assert_eq(value.delta_y_css_px, 4.0)
      assert_eq(value.norm_css_px, 5.0)
      assert_eq(translation.magnitude.geometry_displacement_css_px, Some(5.0))
    }
    _ => fail("translation magnitude kind changed")
  }
  match
    transform_effect_difference(report, "geometry.transform.rotation").magnitude.transform_effect {
    Some(RotationEffect(value)) => {
      assert_transform_close(value.signed_delta_degrees, 30.0)
      assert_transform_close(value.abs_delta_degrees, 30.0)
    }
    _ => fail("rotation magnitude kind changed")
  }
  let rotation = transform_effect_difference(
    report, "geometry.transform.rotation",
  )
  assert_true(rotation.magnitude.parameter_abs_css_px is None)
  assert_true(rotation.magnitude.parameter_entity_fraction is None)
  match
    transform_effect_difference(report, "geometry.transform.scale").magnitude.transform_effect {
    Some(ScaleEffect(value)) => {
      assert_transform_close(value.after_x, 2.0)
      assert_transform_close(value.after_y, 3.0)
      assert_transform_close(value.max_abs_delta, 2.0)
    }
    _ => fail("scale magnitude kind changed")
  }
  let scale = transform_effect_difference(report, "geometry.transform.scale")
  assert_true(scale.magnitude.parameter_abs_css_px is None)
  assert_true(scale.magnitude.parameter_entity_fraction is None)
  match
    transform_effect_difference(report, "geometry.transform.skew").magnitude.transform_effect {
    Some(SkewEffect(value)) => {
      assert_transform_close(value.signed_delta_degrees, 20.0)
      assert_transform_close(value.abs_delta_degrees, 20.0)
    }
    _ => fail("skew magnitude kind changed")
  }
}

///|
test "rotation effect crosses the angle boundary by the short direction" {
  let before = "<svg><rect id='box' width='4' height='4' transform='rotate(179)'/></svg>"
  let after = "<svg><rect id='box' width='4' height='4' transform='rotate(-179)'/></svg>"
  let effect = transform_effect_difference(
    compare(before, after, ComparisonProfile::v1_default()),
    "geometry.transform.rotation",
  )
  match effect.magnitude.transform_effect {
    Some(RotationEffect(value)) => {
      assert_transform_close(value.signed_delta_degrees, 2.0)
      assert_transform_close(value.abs_delta_degrees, 2.0)
      assert_eq(effect.domain_ordering.components[0], value.abs_delta_degrees)
    }
    _ => fail("rotation magnitude kind changed")
  }
}

///|
test "reflection is retained in the canonical signed Y scale" {
  let before = "<svg><rect id='box' width='4' height='4' transform='scale(1 1)'/></svg>"
  let after = "<svg><rect id='box' width='4' height='4' transform='scale(1 -1)'/></svg>"
  let report = compare(before, after, ComparisonProfile::v1_default())
  match
    transform_effect_difference(report, "geometry.transform.scale").magnitude.transform_effect {
    Some(ScaleEffect(value)) => {
      assert_eq(value.before_y, 1.0)
      assert_eq(value.after_y, -1.0)
      assert_eq(value.max_abs_delta, 2.0)
    }
    _ => fail("scale magnitude kind changed")
  }
  assert_true(
    report.atomic_differences.all(difference => {
      difference.domain != "geometry.transform.residual_matrix"
    }),
  )
}

///|
test "singular linear change emits exact residual coefficients without a score" {
  let before = "<svg><rect id='box' width='4' height='4' transform='scale(1)'/></svg>"
  let after = "<svg><rect id='box' width='4' height='4' transform='scale(0 2)'/></svg>"
  let report = compare(before, after, ComparisonProfile::v1_default())
  let residual = transform_effect_difference(
    report, "geometry.transform.residual_matrix",
  )
  match residual.magnitude.transform_effect {
    Some(ResidualMatrixEffect(value)) => {
      assert_eq(value.before_matrix, [1.0, 0.0, 0.0, 1.0, 0.0, 0.0])
      assert_eq(value.after_matrix, [0.0, 0.0, 0.0, 2.0, 0.0, 0.0])
      assert_eq(value.before_determinant, 1.0)
      assert_eq(value.after_determinant, 0.0)
    }
    _ => fail("residual magnitude kind changed")
  }
  assert_true(residual.magnitude.parameter_abs_user_units is None)
  assert_true(residual.magnitude.geometry_displacement_css_px is None)
  assert_true(
    report.atomic_differences.all(difference => {
      difference.domain != "geometry.transform.rotation" &&
      difference.domain != "geometry.transform.scale" &&
      difference.domain != "geometry.transform.skew"
    }),
  )
}

///|
test "transform event keeps occupied and vacated pixel components" {
  let before = "<svg width='16' height='16'><g transform='translate(1 0)'><rect id='box' x='2' y='4' width='5' height='5' fill='red'/></g></svg>"
  let after = "<svg width='16' height='16'><g transform='translate(5 0)'><rect id='box' x='2' y='4' width='5' height='5' fill='red'/></g></svg>"
  let report = compare(before, after, ComparisonProfile::v1_default())
  let event = report.events.last().unwrap()
  assert_eq(event.rendered_outcome.magnitude.unwrap().changed_pixels, 40)
  assert_eq(event.difference_regions.length(), 2)
  assert_eq(event.difference_regions.map(region => region.changed_pixels), [
    20, 20,
  ])
}

///|
test "transform event excludes disjoint changes outside cumulative painted bounds" {
  let before = "<svg width='16' height='16'><rect id='moved' x='1' y='1' width='3' height='3' fill='red' transform='translate(0 0)'/><rect id='other' x='12' y='12' width='3' height='3' fill='red'/></svg>"
  let after = "<svg width='16' height='16'><rect id='moved' x='1' y='1' width='3' height='3' fill='red' transform='translate(4 0)'/><rect id='other' x='12' y='12' width='3' height='3' fill='blue'/></svg>"
  let report = compare(before, after, ComparisonProfile::v1_default())
  guard report.events.filter(event => event.id.find(":transform") is Some(_))
    is [event] else {
    fail("expected one transform event")
  }
  assert_eq(event.difference_regions.length(), 2)
  assert_true(
    event.difference_regions.all(region => {
      region.css_x >= 1.0 && region.css_x + region.css_width <= 8.0
    }),
  )
  assert_eq(event.rendered_outcome.magnitude.unwrap().changed_pixels, 18)
}

///|
test "nested groups and viewports accumulate root to element" {
  let source = "<svg transform='translate(1 0)'><g transform='scale(2)'><svg transform='translate(3 4)'><rect width='1' height='1'/></svg></g></svg>"
  let subject = extract_source_subjects_or_raise(source)[0]
  assert_eq(subject.cumulative_transform.signature(), "matrix(2,0,0,2,7,8)")
  assert_true(subject.transform_complete)
  assert_eq(subject.transform_chain.length(), 4)
}

///|
test "uninstantiated definition ancestry produces no rendered subject" {
  let source = "<svg><defs transform='translate(2 3)'><g transform='scale(2)'><rect id='resource-shape' width='1' height='1'/></g></defs></svg>"
  assert_true(extract_source_subjects_or_raise(source).is_empty())
}

///|
test "malformed transform syntax remains partial and source located" {
  let source = "<svg><rect id='box' width='4' height='4' transform='translate(1,) '/></svg>"
  let report = compare(source, source, ComparisonProfile::v1_default())
  assert_eq(report.analysis_status, "partial")
  assert_true(transform_differences(report).is_empty())
  assert_true(
    report.diagnostics.any(diagnostic => {
      diagnostic.code == "transform_syntax_unsupported" &&
      diagnostic.subject_id == "box" &&
      diagnostic.source_locations.length() == 2
    }),
  )
}

///|
test "identical malformed transform declarations do not create a false diff" {
  let source = "<svg><rect id='box' width='4' height='4' transform='translate(1,)'/></svg>"
  let report = compare(source, source, ComparisonProfile::v1_default())
  assert_eq(report.analysis_status, "partial")
  assert_true(transform_differences(report).is_empty())
}

///|
test "different malformed transform declarations remain source reportable" {
  let before = "<svg><rect id='box' width='4' height='4' transform='translate(1,)'/></svg>"
  let after = "<svg><rect id='box' width='4' height='4' transform='translate(2,)'/></svg>"
  let report = compare(before, after, ComparisonProfile::v1_default())
  let differences = transform_differences(report)
  assert_eq(report.analysis_status, "partial")
  assert_eq(differences.length(), 1)
  assert_eq(differences[0].domain, "geometry.transform.list")
  assert_eq(differences[0].computed_relation.status, "indeterminate")
  assert_true(differences[0].computed_relation.diagnostic_ids.length() > 0)
  assert_true(
    differences[0].computed_relation.diagnostic_ids.all(id => {
      report.diagnostics.any(diagnostic => {
        diagnostic.id == id && diagnostic.subject_id == "box"
      })
    }),
  )
}

///|
test "gradient transform syntax remains source-visible and computed-equivalent" {
  let before = "<svg><defs><linearGradient id='paint' gradientTransform='translate(1)'><stop offset='0' stop-color='red'/></linearGradient></defs></svg>"
  let after = "<svg><defs><linearGradient id='paint' gradientTransform='matrix(1 0 0 1 1 0)'><stop offset='0' stop-color='red'/></linearGradient></defs></svg>"
  let report = compare(before, after, ComparisonProfile::v1_default())
  let differences = [
    for difference in report.atomic_differences if difference.domain ==
    "resource.gradient.transform.list" => difference
  ]
  assert_eq(report.analysis_status, "complete")
  assert_eq(differences.length(), 1)
  assert_eq(differences[0].subject_role, "resource")
  assert_eq(differences[0].computed_relation.status, "equivalent")
  assert_eq(differences[0].changed_fact_ids.length(), 1)
  assert_true(
    report.diagnostics.all(diagnostic => {
      diagnostic.code != "resource_transform_semantics_unsupported"
    }),
  )
}

///|
test "gradient transform matrix changes retain authored and effective forms" {
  let before = "<svg><defs><linearGradient id='paint' gradientTransform='translate(1)'/></defs></svg>"
  let after = "<svg><defs><linearGradient id='paint' gradientTransform='translate(3)'/></defs></svg>"
  let differences = [
    for
      difference in compare(before, after, ComparisonProfile::v1_default()).atomic_differences if difference.domain.has_prefix(
      "resource.gradient.transform.",
    ) => difference
  ]
  assert_eq(differences.length(), 2)
  assert_eq(
    differences[1].domain,
    "resource.gradient.transform.effective_matrix",
  )
  assert_eq(differences[1].source_before, "matrix(1,0,0,1,1,0)")
  assert_eq(differences[1].source_after, "matrix(1,0,0,1,3,0)")
  assert_true(differences[1].parameter_delta_css_px is None)
  assert_true(differences[1].magnitude.parameter_abs_user_units is None)
}

///|
test "anonymous gradient transform differences pair by resource ordinal" {
  let before = "<svg><defs><linearGradient gradientTransform='translate(1)'/></defs></svg>"
  let after = "<svg><defs><linearGradient gradientTransform='translate(2)'/></defs></svg>"
  let report = compare(before, after, ComparisonProfile::v1_default())
  assert_eq(report.analysis_status, "complete")
  assert_true(
    report.diagnostics.all(diagnostic => {
      diagnostic.code != "coverage_proof_incomplete"
    }),
  )
  assert_true(
    report.atomic_differences.any(difference => {
      difference.domain == "resource.gradient.transform.effective_matrix" &&
      difference.computed_relation.status == "different" &&
      difference.computed_relation.diagnostic_ids.is_empty()
    }),
  )
}

///|
test "pattern transform has complete resource-local semantics" {
  let before = "<svg><defs><pattern id='tile' patternTransform='scale(1)'/></defs></svg>"
  let after = "<svg><defs><pattern id='tile' patternTransform='scale(2)'/></defs></svg>"
  let report = compare(before, after, ComparisonProfile::v1_default())
  assert_true(
    report.atomic_differences.any(difference => {
      difference.domain == "resource.pattern.transform.list" &&
      difference.source_before == "scale(1)" &&
      difference.source_after == "scale(2)"
    }),
  )
  assert_true(
    report.diagnostics.all(diagnostic => {
      diagnostic.code != "unsupported_visual_subject"
    }),
  )
  assert_true(
    report.diagnostics.all(diagnostic => {
      diagnostic.code != "coverage_proof_incomplete"
    }),
  )
}

///|
test "radial gradient transform has complete effective matrix semantics" {
  let before = "<svg><defs><radialGradient id='paint' gradientTransform='translate(1)'/></defs></svg>"
  let after = "<svg><defs><radialGradient id='paint' gradientTransform='translate(2)'/></defs></svg>"
  let report = compare(before, after, ComparisonProfile::v1_default())
  assert_true(
    report.atomic_differences.any(difference => {
      difference.domain == "resource.gradient.transform.effective_matrix" &&
      difference.source_before == "matrix(1,0,0,1,1,0)" &&
      difference.source_after == "matrix(1,0,0,1,2,0)"
    }),
  )
  assert_true(
    report.diagnostics.all(diagnostic => {
      diagnostic.code != "resource_transform_semantics_unsupported"
    }),
  )
}
