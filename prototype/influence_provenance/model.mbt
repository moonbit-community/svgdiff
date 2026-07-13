///|
struct TileSample {
  value : Int
  tokens : Array[String]
}

///|
struct Raster {
  tiles : Array[TileSample]
}

///|
struct Scenario {
  key : String
  name : String
  purpose : String
  delta : Array[String]
  before : Raster
  after : Raster
  actual_causes : Array[String]
  fallback_all_delta : Bool
  coverage_complete : Bool
  fallback_scope : String
}

///|
struct Analysis {
  difference_tiles : Array[Int]
  envelope : Array[String]
  missing_actual_causes : Array[String]
  false_positives : Array[String]
  guarantee : String
  verdict : String
}

///|
fn contains_string(xs : ArrayView[String], needle : String) -> Bool {
  for item in xs {
    if item == needle {
      return true
    }
  }
  false
}

///|
fn push_unique(xs : Array[String], item : String) -> Unit {
  if !contains_string(xs, item) {
    xs.push(item)
  }
}

///|
fn copy_tokens(xs : ArrayView[String]) -> Array[String] {
  let copied : Array[String] = []
  for item in xs {
    copied.push(item)
  }
  copied
}

///|
fn blank_raster(width : Int) -> Raster {
  let tiles : Array[TileSample] = []
  for _ in 0..<width {
    tiles.push({ value: 0, tokens: [] })
  }
  { tiles, }
}

///|
fn paint(
  width : Int,
  painted_tiles : ArrayView[Int],
  value : Int,
  tokens : ArrayView[String],
) -> Raster {
  let raster = blank_raster(width)
  for tile in painted_tiles {
    raster.tiles[tile] = { value, tokens: copy_tokens(tokens) }
  }
  raster
}

///|
fn blur(
  input : Raster,
  radius : Int,
  operation_tokens : ArrayView[String],
) -> Raster {
  let width = input.tiles.length()
  let output = blank_raster(width)
  for tile in 0..<width {
    let start = if tile - radius < 0 { 0 } else { tile - radius }
    let end = if tile + radius + 1 > width { width } else { tile + radius + 1 }
    let mut value = 0
    let tokens : Array[String] = []
    for source_tile in start..<end {
      let sample = input.tiles[source_tile]
      if sample.value != 0 {
        value += sample.value
        for token in sample.tokens {
          push_unique(tokens, token)
        }
      }
    }
    if value != 0 {
      for token in operation_tokens {
        push_unique(tokens, token)
      }
      output.tiles[tile] = { value, tokens }
    }
  }
  output
}

///|
fn composite(
  backdrop : Raster,
  foreground : Raster,
  operation_tokens : ArrayView[String],
) -> Raster {
  let width = backdrop.tiles.length()
  let output = blank_raster(width)
  for tile in 0..<width {
    let back = backdrop.tiles[tile]
    let front = foreground.tiles[tile]
    let value = back.value + front.value
    let tokens : Array[String] = []
    if value != 0 {
      for token in back.tokens {
        push_unique(tokens, token)
      }
      for token in front.tokens {
        push_unique(tokens, token)
      }
      for token in operation_tokens {
        push_unique(tokens, token)
      }
      output.tiles[tile] = { value, tokens }
    }
  }
  output
}

///|
fn changed_tiles(before : Raster, after : Raster) -> Array[Int] {
  let changed : Array[Int] = []
  for tile in 0..<before.tiles.length() {
    if before.tiles[tile].value != after.tiles[tile].value {
      changed.push(tile)
    }
  }
  changed
}

///|
fn analyze(scenario : Scenario) -> Analysis {
  let difference_tiles = changed_tiles(scenario.before, scenario.after)
  let envelope : Array[String] = []
  if scenario.fallback_all_delta {
    for fact in scenario.delta {
      push_unique(envelope, fact)
    }
  } else {
    for tile in difference_tiles {
      for token in scenario.before.tiles[tile].tokens {
        if contains_string(scenario.delta, token) {
          push_unique(envelope, token)
        }
      }
      for token in scenario.after.tiles[tile].tokens {
        if contains_string(scenario.delta, token) {
          push_unique(envelope, token)
        }
      }
    }
  }
  let missing_actual_causes : Array[String] = []
  for cause in scenario.actual_causes {
    if !contains_string(envelope, cause) {
      missing_actual_causes.push(cause)
    }
  }
  let false_positives : Array[String] = []
  for candidate in envelope {
    if !contains_string(scenario.actual_causes, candidate) {
      false_positives.push(candidate)
    }
  }
  let guarantee = if scenario.coverage_complete {
    "sound-overapproximation"
  } else {
    "not-established"
  }
  let verdict = if !scenario.coverage_complete {
    "NOT CLAIMED"
  } else if missing_actual_causes.is_empty() {
    "PASS"
  } else {
    "FAIL"
  }
  {
    difference_tiles,
    envelope,
    missing_actual_causes,
    false_positives,
    guarantee,
    verdict,
  }
}

///|
fn direct_paint_scenario() -> Scenario {
  {
    key: "1",
    name: "direct paint",
    purpose: "A changed paint value produces one changed tile; unrelated metadata is pruned.",
    delta: ["paint.fill", "metadata.title"],
    before: paint(6, [2], 10, ["paint.fill"]),
    after: paint(6, [2], 20, ["paint.fill"]),
    actual_causes: ["paint.fill"],
    fallback_all_delta: false,
    coverage_complete: true,
    fallback_scope: "tile",
  }
}

///|
fn movement_scenario() -> Scenario {
  {
    key: "2",
    name: "before/after movement",
    purpose: "The renderer derives a vacated before tile and an occupied after tile from one geometry change.",
    delta: ["geometry.x", "metadata.label"],
    before: paint(6, [1], 10, ["geometry.x"]),
    after: paint(6, [4], 10, ["geometry.x"]),
    actual_causes: ["geometry.x"],
    fallback_all_delta: false,
    coverage_complete: true,
    fallback_scope: "tile",
  }
}

///|
fn filter_scenario() -> Scenario {
  let base = paint(6, [2], 10, ["input.content"])
  let conservative_tokens : Array[String] = [
    "filter.radius", "clip.outside-shape",
  ]
  {
    key: "3",
    name: "filter expansion",
    purpose: "A wider blur derives changed neighboring tiles while conservative effect provenance accepts one false positive.",
    delta: ["filter.radius", "clip.outside-shape", "metadata.footer"],
    before: blur(base, 0, conservative_tokens),
    after: blur(base, 1, conservative_tokens),
    actual_causes: ["filter.radius"],
    fallback_all_delta: false,
    coverage_complete: true,
    fallback_scope: "group-layer",
  }
}

///|
fn compositing_scenario() -> Scenario {
  let before_backdrop = paint(6, [3], 10, ["backdrop.fill"])
  let after_backdrop = paint(6, [3], 11, ["backdrop.fill"])
  let before_foreground = paint(6, [3], 10, ["foreground.opacity"])
  let after_foreground = paint(6, [3], 20, ["foreground.opacity"])
  {
    key: "4",
    name: "compositing dependencies",
    purpose: "Foreground, backdrop, and a conservative blend token are unioned by the composite operation.",
    delta: ["foreground.opacity", "backdrop.fill", "group.blend-mode"],
    before: composite(before_backdrop, before_foreground, ["group.blend-mode"]),
    after: composite(after_backdrop, after_foreground, ["group.blend-mode"]),
    actual_causes: ["foreground.opacity", "backdrop.fill"],
    fallback_all_delta: false,
    coverage_complete: true,
    fallback_scope: "tile",
  }
}

///|
fn unknown_fallback_scenario() -> Scenario {
  {
    key: "5",
    name: "unknown-operation fallback",
    purpose: "Changed output exists without a safe transfer rule, so analysis widens to all Changed Facts.",
    delta: ["effect.unknown", "path.fill", "metadata.note"],
    before: paint(6, [2], 10, []),
    after: paint(6, [2], 20, []),
    actual_causes: ["effect.unknown"],
    fallback_all_delta: true,
    coverage_complete: true,
    fallback_scope: "all-delta",
  }
}

///|
fn unsupported_scenario() -> Scenario {
  {
    key: "6",
    name: "unsupported operation",
    purpose: "An uncovered operation produces changed output but cannot establish a complete envelope.",
    delta: ["foreignObject.content", "path.fill"],
    before: paint(6, [2], 10, ["path.fill"]),
    after: paint(6, [2], 20, ["path.fill"]),
    actual_causes: ["foreignObject.content"],
    fallback_all_delta: false,
    coverage_complete: false,
    fallback_scope: "unsupported",
  }
}

///|
fn all_scenarios() -> Array[Scenario] {
  [
    direct_paint_scenario(),
    movement_scenario(),
    filter_scenario(),
    compositing_scenario(),
    unknown_fallback_scenario(),
    unsupported_scenario(),
  ]
}

///|
fn scenario_by_key(key : String) -> Scenario? {
  for scenario in all_scenarios() {
    if scenario.key == key {
      return Some(scenario)
    }
  }
  None
}
