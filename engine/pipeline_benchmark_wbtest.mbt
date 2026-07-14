///|
fn pipeline_benchmark_svg(fill : String) -> String {
  let output = StringBuilder::new()
  output.write_string(
    "<svg xmlns='http://www.w3.org/2000/svg' width='128' height='128'>",
  )
  for row in 0..<8 {
    for column in 0..<8 {
      let index = row * 8 + column
      output.write_string(
        "<rect id='r\{index}' x='\{column * 16}' y='\{row * 16}' width='8' height='8' fill='\{fill}'/>",
      )
    }
  }
  output.write_string("</svg>")
  output.to_string()
}

///|
fn pipeline_benchmark_profile() -> ComparisonProfile {
  {
    ..ComparisonProfile::v1_default(),
    viewport_width: 128,
    viewport_height: 128,
  }
}

///|
fn run_pipeline_stage_benchmarks(benchmark : @bench.T) -> Unit raise {
  let before = pipeline_benchmark_svg("red")
  let after = pipeline_benchmark_svg("blue")
  let profile = pipeline_benchmark_profile()
  let limits = default_resource_limits()
  let before_subjects = extract_source_subjects_or_raise(before)
  let after_subjects = extract_source_subjects_or_raise(after)
  guard @svg.parse_svg_document(before) is Some(before_document) else {
    fail("benchmark fixture must parse")
  }
  guard @svg.parse_svg_document(after) is Some(after_document) else {
    fail("benchmark fixture must parse")
  }
  let before_image = @svg.render_svg_document_to_image(
    before_document, 128, 128,
  )
  let after_image = @svg.render_svg_document_to_image(after_document, 128, 128)
  let report = compare(before, after, profile)
  benchmark.bench(name="parse_admission", () => {
    let before_limit = source_limit(before, "before", limits)
    let after_limit = source_limit(after, "after", limits)
    let before_preflight = preflight_source(before, profile, "before")
    let after_preflight = preflight_source(after, profile, "after")
    let before_document = @svg.parse_svg_document(before)
    let after_document = @svg.parse_svg_document(after)
    benchmark.keep(
      (
        before_limit, after_limit, before_preflight, after_preflight, before_document,
        after_document,
      ),
    )
  })
  benchmark.bench(name="alignment", () => {
    benchmark.keep(align_source_subjects(before_subjects, after_subjects))
  })
  benchmark.bench(name="rendering", () => {
    let rendered_before = @svg.render_svg_document_to_image(
      before_document, 128, 128,
    )
    let rendered_after = @svg.render_svg_document_to_image(
      after_document, 128, 128,
    )
    benchmark.keep((rendered_before, rendered_after))
  })
  benchmark.bench(name="region_extraction", () => {
    benchmark.keep(pixel_difference_regions(before_image, after_image, 65_536))
  })
  benchmark.bench(name="provenance", () => {
    benchmark.keep(attach_cause_envelopes(report))
  })
  benchmark.bench(name="serialization", () => {
    benchmark.keep((report.to_compact_json_string(), report.to_json_string()))
  })
}

///|
test "pipeline stages" (benchmark : @bench.T) {
  run_pipeline_stage_benchmarks(benchmark)
}

///|
#skip("run through scripts/run-stage-benchmarks.sh")
test "pipeline stage machine artifact" {
  let benchmark = @bench.Bench()
  run_pipeline_stage_benchmarks(benchmark)
  println(
    "SVGDIFF_STAGE_BENCHMARK_JSON={\"schema_version\":\"svgdiff-stage-benchmark-results/1\",\"suite_version\":\"svgdiff-stage-benchmark-suite/1\",\"target\":\"native\",\"build_profile\":\"release\",\"time_unit\":\"microseconds\",\"workload\":{\"id\":\"grid-64-paint-change\",\"subjects_per_input\":64,\"viewport_width\":128,\"viewport_height\":128},\"stages\":\{benchmark.dump_summaries()}}",
  )
}
