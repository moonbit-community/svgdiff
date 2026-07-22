///|
fn production_domain_count(report : StructuredReport, prefix : String) -> Int {
  report.atomic_differences
  .filter(difference => difference.domain.has_prefix(prefix))
  .length()
}

///|
fn production_example_profile() -> ComparisonProfile {
  {
    ..ComparisonProfile::v1_default(),
    viewport_width: 256,
    viewport_height: 256,
  }
}

///|
test "currentColor circle insertion remains an Atomic Difference" {
  let before =
    #|<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/></svg>
  let after =
    #|<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><circle cx="12" cy="12" r="1"/></svg>
  let report = compare(before, after, production_example_profile())
  let canvas_changed = report.canvas_outcome.magnitude.map(magnitude => {
    magnitude.changed_pixels > 0
  })
  assert_eq(canvas_changed, Some(true))
  assert_true(
    report.atomic_differences.any(difference => {
      difference.domain == "presence.insertion" &&
      difference.subject_alignment_id is Some(_)
    }),
  )
  assert_true(
    report.events.any(event => {
      event.atomic_difference_ids.any(id => {
        report.atomic_differences.any(difference => {
          difference.id == id && difference.domain == "presence.insertion"
        })
      })
    }),
  )
}

///|
test "currentColor path repair retains geometry beside stacking" {
  let before =
    #|<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9"/><path d="M10.3 21a1.94 1.94 0 0 0 3.4 0"/></svg>
  let after =
    #|<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M10.268 21a2 2 0 0 0 3.464 0"/><path d="M3.262 15.326A1 1 0 0 0 4 17h16a1 1 0 0 0 .74-1.673C19.41 13.956 18 12.499 18 8A6 6 0 0 0 6 8c0 4.499-1.411 5.956-2.738 7.326"/></svg>
  let report = compare(before, after, production_example_profile())
  let region_counts = [
    for event in report.events => event.difference_regions.length()
  ]
  assert_true(region_counts.all(count => count <= 50))
  assert_true(production_domain_count(report, "geometry.path.") > 0)
  assert_true(
    report.atomic_differences.any(difference => {
      difference.domain == "document.structure.stacking_order"
    }),
  )
  let path_events = report.events.filter(event => {
    event.atomic_difference_ids.any(id => {
      report.atomic_differences.any(difference => {
        difference.id == id && difference.domain.has_prefix("geometry.path.")
      })
    })
  })
  assert_eq(path_events.length(), 2)
  assert_true(path_events.all(event => !event.difference_regions.is_empty()))
  assert_true(
    path_events[0].difference_regions.fold(init=0, (sum, region) => {
      sum + region.changed_pixels
    }) !=
    path_events[1].difference_regions.fold(init=0, (sum, region) => {
      sum + region.changed_pixels
    }),
  )
}

///|
test "one inherited path outcome has one entity Event owner" {
  let before =
    #|<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path stroke-linecap="round" stroke-linejoin="round" d="M3 8C3 4 8 2 12 6C16 2 21 4 21 8C21 14 12 20 12 20S3 14 3 8Z"/></svg>
  let after =
    #|<svg width="24" height="24" viewBox="0 0 24 24" fill="currentColor"><path d="M2 8C2 3 8 1 12 5C16 1 22 3 22 8C22 15 12 21 12 21S2 15 2 8Z"/></svg>
  let report = compare(before, after, production_example_profile())
  assert_true(production_domain_count(report, "geometry.path.") > 0)
  assert_true(
    report.atomic_differences.any(difference => {
      difference.domain == "paint.fill" || difference.domain == "paint.stroke"
    }),
  )
  let entity_alignment_ids = [
    for difference in report.atomic_differences if difference.subject_role ==
    "entity" &&
    difference.subject_alignment_id is Some(id) => id
  ]
  assert_true(!entity_alignment_ids.is_empty())
  let alignment_id = entity_alignment_ids[0]
  assert_true(entity_alignment_ids.all(id => id == alignment_id))
  let owning_events = report.events.filter(event => {
    event.atomic_difference_ids.any(id => {
      report.atomic_differences.any(difference => {
        difference.id == id &&
        difference.subject_alignment_id == Some(alignment_id)
      })
    })
  })
  assert_eq(owning_events.length(), 1)
}

///|
test "overlapping Event bounds crop one shared canvas component" {
  let before =
    #|<svg width="20" height="20"><rect id="a" x="2" y="2" width="6" height="6" fill="red"/><rect id="b" x="8" y="2" width="6" height="6" fill="blue"/></svg>
  let after =
    #|<svg width="20" height="20"><rect id="a" x="2" y="2" width="6" height="8" fill="red"/><rect id="b" x="8" y="2" width="6" height="10" fill="blue"/></svg>
  let report = compare(before, after, production_example_profile())
  let size_events = report.events.filter(event => {
    event.atomic_difference_ids.any(id => {
      report.atomic_differences.any(difference => {
        difference.id == id && difference.domain == "geometry.size"
      })
    })
  })
  assert_eq(size_events.length(), 2)
  assert_true(size_events.all(event => event.difference_regions.length() == 1))
  let first = size_events[0].difference_regions[0]
  let second = size_events[1].difference_regions[0]
  assert_true(
    first.pixel_x != second.pixel_x ||
    first.pixel_y != second.pixel_y ||
    first.pixel_width != second.pixel_width ||
    first.pixel_height != second.pixel_height ||
    first.changed_pixels != second.changed_pixels,
  )
}

///|
test "disjoint arc Events do not inherit the whole canvas difference mask" {
  let before =
    #|<svg width="40" height="20" viewBox="0 0 40 20" fill="none" stroke="black" stroke-width="2"><path id="a" d="M2 8A4 4 0 0 1 10 8"/><path id="b" d="M22 8A4 4 0 0 1 30 8"/></svg>
  let after =
    #|<svg width="40" height="20" viewBox="0 0 40 20" fill="none" stroke="black" stroke-width="2"><path id="a" d="M2 8A5 5 0 0 1 12 8"/><path id="b" d="M22 8A3 3 0 0 1 28 8"/></svg>
  let report = compare(before, after, production_example_profile())
  let path_events = report.events.filter(event => {
    event.atomic_difference_ids.any(id => {
      report.atomic_differences.any(difference => {
        difference.id == id && difference.domain.has_prefix("geometry.path.")
      })
    })
  })
  assert_eq(path_events.length(), 2)
  assert_true(path_events.all(event => !event.difference_regions.is_empty()))
  let first = path_events[0].difference_regions
  let second = path_events[1].difference_regions
  assert_true(
    first.length() != second.length() ||
    first.any(region => {
      !second.any(other => {
        region.pixel_x == other.pixel_x &&
        region.pixel_y == other.pixel_y &&
        region.pixel_width == other.pixel_width &&
        region.pixel_height == other.pixel_height &&
        region.changed_pixels == other.changed_pixels
      })
    }),
  )
}
