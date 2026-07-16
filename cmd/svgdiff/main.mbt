///|
priv struct CliConfig {
  before_path : String
  after_path : String
  output_path : String?
  html_path : String?
  agent_json : Bool
  agent_projection : Bool
  width : Int
  height : Int
  perceptual_background : @lib.PerceptualBackground?
  flip_viewing_conditions : @lib.FlipViewingConditions?
  flip_error_threshold : @lib.FlipErrorThreshold?
  before_resources : Array[CliResource]
  after_resources : Array[CliResource]
}

///|
priv struct CliResource {
  locator : String
  media_type : String
  path : String
}

///|
priv enum CliParseResult {
  Config(CliConfig)
  Invalid(String)
}

///|
priv enum SvgInputResult {
  SvgSource(String)
  InputError(String)
}

///|
priv enum ResourceInputResult {
  LoadedResourceBundle(@lib.ResourceBundle)
  ResourceInputError(String)
}

///|
fn usage() -> String {
  "Usage: svgdiff <before.svg> <after.svg> [--width N] [--height N] [--perceptual-background COLOR] [--flip-pixels-per-degree PPD] [--flip-error-threshold VALUE] [--before-resource LOCATOR MEDIA_TYPE FILE] [--after-resource LOCATOR MEDIA_TYPE FILE] [--output report.json] [--html report.html]"
}

///|
fn help_text() -> String {
  usage() +
  "\n\nCompare two deterministic static SVG files and emit Structured Report JSON.\nUse - for exactly one input to read that SVG from stdin. Resource files are read only when named by an explicit resource option.\n\nOptions:\n  --width N          Comparison viewport width in CSS pixels (default: 16)\n  --height N         Comparison viewport height in CSS pixels (default: 16)\n  --perceptual-background COLOR\n                     Record one explicit opaque deterministic sRGB background\n  --flip-pixels-per-degree PPD\n                     Request LDR-FLIP with supported PPD in [1, 4096]\n  --flip-error-threshold VALUE\n                     Report FLIP area strictly above an explicit value in [0, 1]\n  --before-resource LOCATOR MEDIA_TYPE FILE\n                     Supply one opaque before-side PNG/JPEG resource\n  --after-resource LOCATOR MEDIA_TYPE FILE\n                     Supply one opaque after-side PNG/JPEG resource\n  --output FILE      Write JSON or Agent projection JSONL to FILE\n  --html FILE        Also write the self-contained HTML presentation\n  --agent-json       Remove JSON formatting whitespace without removing evidence\n  --agent-projection Emit lossless line-addressable Agent projection JSONL\n  --help             Show this help and exit\n  --version          Show component versions and exit\n\nExit status:\n  0  Complete or partial report produced\n  1  Analysis failed; a failed Structured Report was produced\n  2  Invalid arguments or file I/O failure"
}

///|
fn version_text() -> String {
  "svgdiff 0.5.24\nengine: 0.5.24\nschema: 1.43\nagent-projection: svgdiff-agent-projection/1\nrenderer: svgdiff/style-precedence-normalizer@3+ordinary-inheritance-normalizer@1+css-computed-value-normalizer@3+css-color3-opacity-normalizer@1+length-used-value-normalizer@1+stroke-used-geometry-normalizer@1+basic-shape-used-geometry-normalizer@1+isolated-group-compositor@1+static-mask-normalizer@1+static-mask-compositor@1+static-filter-graph-compositor@1+static-blend-compositor@1+mizchi/svg@0.2.1\nrenderer-conformance-profile: svgdiff-renderer-conformance-profile/25\nordering-policy: v2_domain_lexicographic\nimpact-policy: event_rendered_pareto/v1"
}

///|
fn parse_positive_int(value : String, option : String) -> Result[Int, String] {
  let parsed = @string.parse_int(value) catch {
    _ => return Err("\{option} requires a positive integer")
  }
  if parsed > 0 {
    Ok(parsed)
  } else {
    Err("\{option} requires a positive integer")
  }
}

///|
fn parse_flip_viewing_conditions(
  value : String,
) -> Result[@lib.FlipViewingConditions, String] {
  let parsed = @string.parse_double(value) catch {
    _ =>
      return Err(
        "--flip-pixels-per-degree requires a finite number in [1, 4096]",
      )
  }
  match @lib.FlipViewingConditions::from_pixels_per_degree(parsed) {
    Some(viewing) => Ok(viewing)
    None =>
      Err("--flip-pixels-per-degree requires a finite number in [1, 4096]")
  }
}

///|
fn parse_flip_error_threshold(
  value : String,
) -> Result[@lib.FlipErrorThreshold, String] {
  let parsed = @string.parse_double(value) catch {
    _ => return Err("--flip-error-threshold requires a finite number in [0, 1]")
  }
  match @lib.FlipErrorThreshold::from_value(parsed) {
    Some(threshold) => Ok(threshold)
    None => Err("--flip-error-threshold requires a finite number in [0, 1]")
  }
}

///|
fn parse_cli(args : Array[String]) -> CliParseResult {
  if args.length() < 3 {
    return Invalid(usage())
  }
  if args[1] == "-" && args[2] == "-" {
    return Invalid("Only one SVG input may use stdin (-)")
  }
  let mut width = 16
  let mut height = 16
  let mut perceptual_background : @lib.PerceptualBackground? = None
  let mut flip_viewing_conditions : @lib.FlipViewingConditions? = None
  let mut flip_error_threshold : @lib.FlipErrorThreshold? = None
  let mut output_path : String? = None
  let mut html_path : String? = None
  let mut agent_json = false
  let mut agent_projection = false
  let before_resources : Array[CliResource] = []
  let after_resources : Array[CliResource] = []
  let mut index = 3
  while index < args.length() {
    if args[index] == "--agent-json" {
      agent_json = true
      index += 1
      continue
    }
    if args[index] == "--agent-projection" {
      agent_projection = true
      index += 1
      continue
    }
    if args[index] == "--before-resource" || args[index] == "--after-resource" {
      if index + 3 >= args.length() {
        return Invalid("\{args[index]} requires LOCATOR MEDIA_TYPE FILE")
      }
      let resource : CliResource = {
        locator: args[index + 1],
        media_type: args[index + 2],
        path: args[index + 3],
      }
      if resource.path == "-" {
        return Invalid("Resource FILE may not use stdin (-)")
      }
      if args[index] == "--before-resource" {
        before_resources.push(resource)
      } else {
        after_resources.push(resource)
      }
      index += 4
      continue
    }
    if index + 1 >= args.length() {
      return Invalid("Missing value for \{args[index]}")
    }
    let value = args[index + 1]
    match args[index] {
      "--width" =>
        match parse_positive_int(value, "--width") {
          Ok(parsed) => width = parsed
          Err(message) => return Invalid(message)
        }
      "--height" =>
        match parse_positive_int(value, "--height") {
          Ok(parsed) => height = parsed
          Err(message) => return Invalid(message)
        }
      "--perceptual-background" =>
        match @lib.PerceptualBackground::parse_srgb(value) {
          Some(background) => perceptual_background = Some(background)
          None =>
            return Invalid(
              "--perceptual-background requires an opaque deterministic sRGB color",
            )
        }
      "--flip-pixels-per-degree" =>
        match parse_flip_viewing_conditions(value) {
          Ok(viewing) => flip_viewing_conditions = Some(viewing)
          Err(message) => return Invalid(message)
        }
      "--flip-error-threshold" =>
        match parse_flip_error_threshold(value) {
          Ok(threshold) => flip_error_threshold = Some(threshold)
          Err(message) => return Invalid(message)
        }
      "--output" => output_path = Some(value)
      "--html" => html_path = Some(value)
      option => return Invalid("Unknown option: \{option}")
    }
    index += 2
  }
  if agent_json && agent_projection {
    return Invalid("--agent-json and --agent-projection are mutually exclusive")
  }
  Config({
    before_path: args[1],
    after_path: args[2],
    output_path,
    html_path,
    agent_json,
    agent_projection,
    width,
    height,
    perceptual_background,
    flip_viewing_conditions,
    flip_error_threshold,
    before_resources,
    after_resources,
  })
}

///|
async fn read_svg(path : String) -> SvgInputResult {
  if path == "-" {
    let source = @stdio.stdin.read_all().text() catch {
        error => return InputError("Failed to read stdin: \{error}")
      }
    return SvgSource(source)
  }
  try @fs.read_file_to_string(path, encoding="utf8") catch {
    error => InputError("Failed to read \{path}: \{error}")
  } noraise {
    source => SvgSource(source)
  }
}

///|
fn read_resource_bundle(resources : Array[CliResource]) -> ResourceInputResult {
  let entries : Array[@lib.ResourceBundleEntry] = []
  for resource in resources {
    let bytes = @fs.read_file_to_bytes(resource.path) catch {
      error =>
        return ResourceInputError(
          "Failed to read resource \{resource.path}: \{error}",
        )
    }
    entries.push({
      locator: resource.locator,
      media_type: resource.media_type,
      bytes,
    })
  }
  LoadedResourceBundle({ entries, })
}

///|
async fn write_error(message : String) -> Unit {
  @stdio.stderr.write(message + "\n")
}

///|
async fn main {
  let args = @sys.get_cli_args()
  if args.any(argument => argument == "--help") {
    println(help_text())
    return
  }
  if args.any(argument => argument == "--version") {
    println(version_text())
    return
  }
  let config = match parse_cli(args) {
    Config(config) => config
    Invalid(message) => {
      write_error(message)
      @sys.exit(2)
      return
    }
  }
  let before_svg = match read_svg(config.before_path) {
    SvgSource(source) => source
    InputError(message) => {
      write_error(message)
      @sys.exit(2)
      return
    }
  }
  let after_svg = match read_svg(config.after_path) {
    SvgSource(source) => source
    InputError(message) => {
      write_error(message)
      @sys.exit(2)
      return
    }
  }
  let before_resources = match read_resource_bundle(config.before_resources) {
    LoadedResourceBundle(bundle) => bundle
    ResourceInputError(message) => {
      write_error(message)
      @sys.exit(2)
      return
    }
  }
  let after_resources = match read_resource_bundle(config.after_resources) {
    LoadedResourceBundle(bundle) => bundle
    ResourceInputError(message) => {
      write_error(message)
      @sys.exit(2)
      return
    }
  }
  let report = @lib.compare_with_resources(
    before_svg,
    after_svg,
    {
      ..@lib.ComparisonProfile::v1_default(),
      viewport_width: config.width,
      viewport_height: config.height,
      perceptual_background: config.perceptual_background,
      flip_viewing_conditions: config.flip_viewing_conditions,
      flip_error_threshold: config.flip_error_threshold,
    },
    before_resources,
    after_resources,
  )
  let json = if config.agent_projection {
    report.to_agent_projection_json_lines()
  } else if config.agent_json {
    report.to_compact_json_string()
  } else {
    report.to_json_string()
  }
  match config.output_path {
    Some(path) =>
      @fs.write_string_to_file(
        path,
        if config.agent_projection {
          json + "\n"
        } else {
          json
        },
        encoding="utf8",
      ) catch {
        error => {
          write_error("Failed to write \{path}: \{error}")
          @sys.exit(2)
        }
      }
    None => println(json)
  }
  match config.html_path {
    Some(path) => {
      let html = @lib.render_html_report(before_svg, after_svg, report)
      @fs.write_string_to_file(path, html, encoding="utf8") catch {
        error => {
          write_error("Failed to write \{path}: \{error}")
          @sys.exit(2)
        }
      }
    }
    None => ()
  }
  if report.analysis_status == "failed" {
    @sys.exit(1)
  }
}
