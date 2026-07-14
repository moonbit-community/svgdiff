///|
fn unsupported_document(content : String) -> String {
  "<svg width='16' height='16' xmlns='http://www.w3.org/2000/svg'>\{content}</svg>"
}

///|
fn assert_unsupported_never_proves_equality(source : String) -> Unit raise {
  let report = @engine.compare(
    source,
    source,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_false(
    report.analysis_status == "complete" && report.atomic_differences.is_empty(),
  )
  assert_true(
    report.analysis_status == "partial" || report.analysis_status == "failed",
  )
  assert_false(report.diagnostics.is_empty())
  assert_true(
    report.coverage_matrix.any(row => {
      row.source_semantics == "limited" ||
      row.computed_appearance == "limited" ||
      row.rendered_evidence == "limited" ||
      row.source_semantics == "failed" ||
      row.computed_appearance == "failed" ||
      row.rendered_evidence == "failed"
    }),
  )
}

///|
test "unsupported element families never produce complete equality" {
  let elements = [
    "<path d='M0 0 L8 8'/>", "<image href='data:image/png;base64,'/>", "<use href='#shape'/>",
    "<symbol id='shape'><rect width='4' height='4'/></symbol>", "<radialGradient id='paint'/>",
    "<pattern id='paint'/>", "<marker id='mark'/>", "<clipPath id='clip'><rect width='4' height='4'/></clipPath>",
    "<mask id='mask'><rect width='4' height='4'/></mask>", "<filter id='filter'/>",
    "<foreignObject width='4' height='4'/>", "<animate attributeName='x' values='0;1'/>",
    "<set attributeName='fill' to='red'/>", "<animateTransform attributeName='transform'/>",
    "<script>void 0</script>",
  ]
  for element in elements {
    assert_unsupported_never_proves_equality(unsupported_document(element))
    assert_unsupported_never_proves_equality(
      unsupported_document("<g>\{element}</g>"),
    )
  }
}

///|
test "unsupported attribute families never produce complete equality" {
  let attributes = [
    "clip-path='url(#clip)'", "mask='url(#mask)'", "filter='url(#filter)'", "mix-blend-mode='multiply'",
    "paint-order='stroke fill'",
  ]
  let shape_starts = [
    "<rect width='8' height='8'", "<circle cx='4' cy='4' r='3'", "<ellipse cx='4' cy='4' rx='3' ry='2'",
    "<line x1='0' y1='0' x2='8' y2='8'", "<polyline points='0,0 4,4 8,0'", "<polygon points='0,0 4,4 8,0'",
  ]
  for attribute in attributes {
    for shape in shape_starts {
      assert_unsupported_never_proves_equality(
        unsupported_document("\{shape} \{attribute}/>"),
      )
    }
  }
  for
    viewport_attribute in [
      "viewBox='0 0 0 8'", "viewBox='0 0 8 8' preserveAspectRatio='invalid'", "viewBox='0 0 8 8' x='12em'",
    ] {
    assert_unsupported_never_proves_equality(
      "<svg width='16' height='16' \{viewport_attribute}><rect width='8' height='8'/></svg>",
    )
  }
}

///|
test "supported integer viewport mappings remain complete" {
  for
    viewport_attribute in [
      "viewBox='0 0 16 16'", "viewBox='0,0,16,16'", "viewBox=' 0  0  16  16 '", "viewBox='0 0 8 8' preserveAspectRatio='none'",
      "viewBox='0 0 8 4' preserveAspectRatio='xMinYMin meet'", "viewBox='0 0 8 32' preserveAspectRatio='xMaxYMax slice'",
    ] {
    let source = "<svg width='16' height='16' \{viewport_attribute}><rect width='8' height='8'/></svg>"
    let report = @engine.compare(
      source,
      source,
      @engine.ComparisonProfile::v1_default(),
    )
    assert_eq(report.analysis_status, "complete")
  }
}

///|
test "unsupported basic shape geometry never proves equality" {
  for
    content in [
      "<rect id='box' width='-1' height='8'/>", "<rect id='box' width='8em' height='8'/>",
      "<circle id='dot' r='-1'/>", "<ellipse id='oval' rx='2' ry='-1'/>", "<line id='edge' x1='1em' x2='8'/>",
      "<polyline id='route' points='0,0 4,invalid'/>", "<polygon id='area' points='0,0 4,0 4,4 99'/>",
    ] {
    assert_unsupported_never_proves_equality(unsupported_document(content))
  }
}

///|
test "unsupported stroke geometry never proves equality" {
  for
    attributes in [
      "stroke='black' stroke-width='-1'", "stroke='black' stroke-width='2em'", "stroke='black' stroke-linecap='triangle'",
      "stroke='black' stroke-linejoin='sharp'", "stroke='black' stroke-miterlimit='-1'",
      "stroke='black' stroke-dasharray='4 -1'", "stroke='black' stroke-dasharray='4,,2'",
      "stroke='black' stroke-dashoffset='2em'", "stroke='black' vector-effect='non-rotation'",
    ] {
    assert_unsupported_never_proves_equality(
      unsupported_document(
        "<line id='edge' x1='1' y1='1' x2='14' y2='14' \{attributes}/>",
      ),
    )
  }
}

///|
test "unsupported marker semantics never prove equality" {
  for
    content in [
      "<line id='edge' x1='1' y1='8' x2='14' y2='8' marker-end='url(#missing)'/>",
      "<defs><linearGradient id='m'/></defs><line id='edge' x1='1' y1='8' x2='14' y2='8' marker-end='url(#m)'/>",
      "<line id='edge' x1='1' y1='8' x2='14' y2='8' marker-end='url(https://example.com/m.svg#m)'/>",
      "<defs><marker id='m' markerWidth='2em'/></defs><line id='edge' x1='1' y1='8' x2='14' y2='8' marker-end='url(#m)'/>",
      "<defs><marker id='m' markerHeight='-1'/></defs><line id='edge' x1='1' y1='8' x2='14' y2='8' marker-end='url(#m)'/>",
      "<defs><marker id='m' orient='sideways'/></defs><line id='edge' x1='1' y1='8' x2='14' y2='8' marker-end='url(#m)'/>",
      "<defs><marker id='m' refX='center'/></defs><line id='edge' x1='1' y1='8' x2='14' y2='8' marker-end='url(#m)'/>",
      "<defs><marker id='m' overflow='visible'/></defs><line id='edge' x1='1' y1='8' x2='14' y2='8' marker-end='url(#m)'/>",
    ] {
    assert_unsupported_never_proves_equality(unsupported_document(content))
  }
}

///|
test "unsupported CSS paint resource and compositing families never prove equality" {
  let cases = [
    "<rect width='8' height='8' fill='revert-layer'/>", "<rect width='8' height='8' fill='url(#missing)'/>",
    "<rect width='8' height='8' style='unknown-paint:red'/>", "<style>rect:hover { fill: red; }</style><rect width='8' height='8'/>",
    "<g opacity='0.5'><rect width='8' height='8'/></g>", "<svg opacity='0.5'><rect width='8' height='8'/></svg>",
    "<defs><linearGradient id='other'><stop stop-color='red'/></linearGradient></defs><rect id='box' width='8' height='8' fill='url(#other)'/>",
  ]
  for content in cases {
    assert_unsupported_never_proves_equality(unsupported_document(content))
  }
}

///|
test "CSS-wide keywords in ordinary inheritance are computed" {
  let source = unsupported_document(
    "<g stroke-linecap='inherit'><line id='edge' x1='0' y1='4' x2='8' y2='4'/></g>",
  )
  let report = @engine.compare(
    source,
    source,
    @engine.ComparisonProfile::v1_default(),
  )
  assert_eq(report.analysis_status, "complete")
  assert_false(
    report.diagnostics.any(diagnostic => {
      diagnostic.code == "css_wide_keyword_unsupported"
    }),
  )
}

///|
test "unproven renderer conformance families never prove equality" {
  for
    content in [
      "<rect id='box' x='0.99999' y='2' width='8' height='8'/>", "<rect id='box' x='2' y='2' width='8' height='8' opacity='0.5'/>",
      "<defs><linearGradient id='gradient'><stop offset='0' stop-color='red'/><stop offset='1' stop-color='blue'/></linearGradient></defs><rect id='box' x='2' y='2' width='8' height='8' fill='url(#gradient)'/>",
      "<rect id='box' x='2' y='2' width='8' height='8' transform='skewX(20)'/>",
      "<rect id='box' x='2' y='2' width='8' height='8' rx='2'/>", "<polygon id='area' points='2,2 14,2 8,14'/>",
      "<defs><marker id='m' markerUnits='userSpaceOnUse' markerWidth='3' markerHeight='3'><path d='M0 0L3 1.5L0 3Z'/></marker></defs><line id='edge' x1='2' y1='8' x2='14' y2='8' marker-end='url(#m)'/>",
    ] {
    assert_unsupported_never_proves_equality(unsupported_document(content))
  }
}

///|
test "unsupported transform boundaries never prove equality" {
  for
    content in [
      "<rect id='box' width='8' height='8' transform='translate(1,)'/>", "<defs><linearGradient id='gradient' gradientTransform='translate(1)'/></defs>",
      "<defs><pattern id='tile' patternTransform='scale(2)'/></defs>",
    ] {
    assert_unsupported_never_proves_equality(unsupported_document(content))
  }
}
