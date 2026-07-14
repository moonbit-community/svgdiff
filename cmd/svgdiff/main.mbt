///|
priv struct CliConfig {
  before_path : String
  after_path : String
  output_path : String?
  html_path : String?
  agent_json : Bool
  width : Int
  height : Int
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
fn usage() -> String {
  "Usage: svgdiff <before.svg> <after.svg> [--width N] [--height N] [--output report.json] [--html report.html]"
}

///|
fn help_text() -> String {
  usage() +
  "\n\nCompare two deterministic static SVG files and emit Structured Report JSON.\nUse - for exactly one input to read that SVG from stdin.\n\nOptions:\n  --width N          Comparison viewport width in CSS pixels (default: 16)\n  --height N         Comparison viewport height in CSS pixels (default: 16)\n  --output FILE      Write JSON to FILE instead of stdout\n  --html FILE        Also write the self-contained HTML presentation\n  --agent-json       Remove JSON formatting whitespace without removing evidence\n  --help             Show this help and exit\n  --version          Show component versions and exit\n\nExit status:\n  0  Complete or partial report produced\n  1  Analysis failed; a failed Structured Report was produced\n  2  Invalid arguments or file I/O failure"
}

///|
fn version_text() -> String {
  "svgdiff 0.4.0\nengine: 0.4.0\nschema: 1.6\nrenderer: svgdiff/style-precedence-normalizer@1+mizchi/svg@0.2.1\nrenderer-conformance-profile: svgdiff-renderer-conformance-profile/3\nordering-policy: v2_domain_lexicographic"
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
fn parse_cli(args : Array[String]) -> CliParseResult {
  if args.length() < 3 {
    return Invalid(usage())
  }
  if args[1] == "-" && args[2] == "-" {
    return Invalid("Only one SVG input may use stdin (-)")
  }
  let mut width = 16
  let mut height = 16
  let mut output_path : String? = None
  let mut html_path : String? = None
  let mut agent_json = false
  let mut index = 3
  while index < args.length() {
    if args[index] == "--agent-json" {
      agent_json = true
      index += 1
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
      "--output" => output_path = Some(value)
      "--html" => html_path = Some(value)
      option => return Invalid("Unknown option: \{option}")
    }
    index += 2
  }
  Config({
    before_path: args[1],
    after_path: args[2],
    output_path,
    html_path,
    agent_json,
    width,
    height,
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
  let report = @lib.compare(before_svg, after_svg, {
    ..@lib.ComparisonProfile::v1_default(),
    viewport_width: config.width,
    viewport_height: config.height,
  })
  let json = if config.agent_json {
    report.to_compact_json_string()
  } else {
    report.to_json_string()
  }
  match config.output_path {
    Some(path) =>
      @fs.write_string_to_file(path, json, encoding="utf8") catch {
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
