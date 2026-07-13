///|
priv struct CliConfig {
  before_path : String
  after_path : String
  output_path : String?
  width : Int
  height : Int
}

///|
fn usage() -> String {
  "Usage: svgdiff <before.svg> <after.svg> [--width N] [--height N] [--output report.json]"
}

///|
fn parse_positive_int(value : String, option : String) -> Int? {
  let parsed = @string.parse_int(value) catch { _ => return None }
  if parsed > 0 {
    Some(parsed)
  } else {
    println("\{option} requires a positive integer")
    None
  }
}

///|
fn parse_cli(args : Array[String]) -> CliConfig? {
  if args.length() < 3 {
    println(usage())
    return None
  }
  let mut width = 16
  let mut height = 16
  let mut output_path : String? = None
  let mut index = 3
  while index < args.length() {
    if index + 1 >= args.length() {
      println("Missing value for \{args[index]}")
      return None
    }
    let value = args[index + 1]
    match args[index] {
      "--width" =>
        match parse_positive_int(value, "--width") {
          Some(parsed) => width = parsed
          None => return None
        }
      "--height" =>
        match parse_positive_int(value, "--height") {
          Some(parsed) => height = parsed
          None => return None
        }
      "--output" => output_path = Some(value)
      option => {
        println("Unknown option: \{option}")
        return None
      }
    }
    index += 2
  }
  Some({ before_path: args[1], after_path: args[2], output_path, width, height })
}

///|
fn read_svg(path : String) -> String? {
  try @fs.read_file_to_string(path, encoding="utf8") catch {
    error => {
      println("Failed to read \{path}: \{error}")
      None
    }
  } noraise {
    source => Some(source)
  }
}

///|
fn main {
  let config = match parse_cli(@sys.get_cli_args()) {
    Some(config) => config
    None => {
      @sys.exit(2)
      return
    }
  }
  let before_svg = match read_svg(config.before_path) {
    Some(source) => source
    None => {
      @sys.exit(2)
      return
    }
  }
  let after_svg = match read_svg(config.after_path) {
    Some(source) => source
    None => {
      @sys.exit(2)
      return
    }
  }
  let report = @svgdiff.compare(before_svg, after_svg, {
    viewport_width: config.width,
    viewport_height: config.height,
  })
  let json = report.to_json_string()
  match config.output_path {
    Some(path) =>
      @fs.write_string_to_file(path, json, encoding="utf8") catch {
        error => {
          println("Failed to write \{path}: \{error}")
          @sys.exit(2)
        }
      }
    None => println(json)
  }
  if report.analysis_status == "failed" {
    @sys.exit(1)
  }
}
