///|
fn list_text(xs : ArrayView[String]) -> String {
  if xs.is_empty() {
    "[]"
  } else {
    "[" + xs.join(", ") + "]"
  }
}

///|
fn int_list_text(xs : ArrayView[Int]) -> String {
  if xs.is_empty() {
    "[]"
  } else {
    let items : Array[String] = []
    for item in xs {
      items.push("\{item}")
    }
    "[" + items.join(", ") + "]"
  }
}

///|
fn render_header() -> Unit {
  println("\u001b[2J\u001b[H\u001b[1mInfluence Provenance Prototype\u001b[0m")
  println(
    "\u001b[2mPROTOTYPE — scenarios 1-6 test the model; scenario 7 tests the first real SVG integration.\u001b[0m",
  )
  println("")
}

///|
fn render_scenario(scenario : Scenario) -> Unit {
  let analysis = analyze(scenario)
  render_header()
  println("\u001b[1mScenario\u001b[0m: \{scenario.key} — \{scenario.name}")
  println("\u001b[1mPurpose\u001b[0m: \{scenario.purpose}")
  println("\u001b[1mChanged Facts\u001b[0m: \{list_text(scenario.delta)}")
  println(
    "\u001b[1mDifference Tiles\u001b[0m: \{int_list_text(analysis.difference_tiles)}",
  )
  println(
    "\u001b[1mActual Causes\u001b[0m: \{list_text(scenario.actual_causes)}",
  )
  println("")
  println("\u001b[1mCause Envelope\u001b[0m: \{list_text(analysis.envelope)}")
  println(
    "\u001b[1mMissing Actual Causes\u001b[0m: \{list_text(analysis.missing_actual_causes)}",
  )
  println(
    "\u001b[1mAccepted False Positives\u001b[0m: \{list_text(analysis.false_positives)}",
  )
  println("\u001b[1mFallback Scope\u001b[0m: \{scenario.fallback_scope}")
  println("\u001b[1mCoverage Complete\u001b[0m: \{scenario.coverage_complete}")
  println("\u001b[1mGuarantee\u001b[0m: \{analysis.guarantee}")
  println("\u001b[1mVerdict\u001b[0m: \{analysis.verdict}")
  println("")
  render_shortcuts()
}

///|
fn render_all() -> Unit {
  render_header()
  println("\u001b[1mAutomated Walkthrough\u001b[0m")
  println("")
  for scenario in all_scenarios() {
    let analysis = analyze(scenario)
    println(
      "\{scenario.key}. \{scenario.name}: \{analysis.verdict} | envelope=\{list_text(analysis.envelope)} | missing=\{list_text(analysis.missing_actual_causes)} | extras=\{list_text(analysis.false_positives)}",
    )
  }
  println("")
  println("Expected: scenarios 1-5 PASS; scenario 6 NOT CLAIMED.")
  println("")
  render_shortcuts()
}

///|
fn render_moon_svg_spike() -> Unit {
  let result = run_moon_svg_spike()
  render_header()
  println("\u001b[1mReal MoonBit SVG Integration Spike\u001b[0m")
  println("")
  println("Parser and scene lookup: \{result.normal_parsed}")
  println("Recovered x values: \{result.before_x} -> \{result.after_x}")
  println("Rendered diff pixels: \{result.normal_diff_pixels}")
  println("Rendered diff regions: \{diff_regions_text(result.normal_regions)}")
  println("Cause Envelope: \{list_text(result.cause_envelope)}")
  println("Missing Actual Causes: \{list_text(result.missing_causes)}")
  println("")
  println("Tiny geometry delta: \{result.tiny_parameter_delta}")
  println("red -> #ff0000 diff pixels: \{result.equivalent_color_diff_pixels}")
  println("1.0 -> 0.99999 diff pixels: \{result.tiny_negative_diff_pixels}")
  println("1.0 -> 1.00001 diff pixels: \{result.tiny_positive_diff_pixels}")
  println("")
  println("Verdict: \{result.verdict}")
  println("")
  render_shortcuts()
}

///|
fn render_shortcuts() -> Unit {
  println(
    "\u001b[1m1\u001b[0m direct paint  \u001b[1m2\u001b[0m movement  \u001b[1m3\u001b[0m filter",
  )
  println(
    "\u001b[1m4\u001b[0m compositing  \u001b[1m5\u001b[0m fallback  \u001b[1m6\u001b[0m unsupported",
  )
  println("\u001b[1m7\u001b[0m real MoonBit SVG + pixel diff")
  println("\u001b[1ma\u001b[0m all toy scenarios  \u001b[1mq\u001b[0m quit")
  println("")
  println("Enter a key followed by Return:")
}

///|
async fn main {
  render_scenario(direct_paint_scenario())
  while @stdio.stdin.read_until("\n") is Some(line) {
    let command = line.trim().to_owned()
    if command == "q" {
      break
    } else if command == "a" {
      render_all()
    } else if command == "7" {
      render_moon_svg_spike()
    } else {
      match scenario_by_key(command) {
        Some(scenario) => render_scenario(scenario)
        None => {
          render_header()
          println("Unknown key: \{command}")
          println("")
          render_shortcuts()
        }
      }
    }
  }
}
