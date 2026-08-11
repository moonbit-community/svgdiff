// Copyright 2026 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
priv suberror IoError {
  IoError(String)
}

///|
async fn read_svg(path : String) -> String {
  if path == "-" {
    @stdio.stdin.read_all().text() catch {
      error => raise IoError("Failed to read stdin: \{error}")
    }
  } else {
    @fs.read_file_to_string(path, encoding="utf8") catch {
      error => raise IoError("Failed to read \{path}: \{Repr(error)}")
    }
  }
}

///|
fn read_resource_bundle(
  resources : Array[@cli.Resource],
) -> @lib.ResourceBundle raise IoError {
  let entries : Array[@lib.ResourceBundleEntry] = []
  for resource in resources {
    let bytes = @fs.read_file_to_bytes(resource.path) catch {
      error =>
        raise IoError(
          "Failed to read resource \{resource.path}: \{Repr(error)}",
        )
    }
    entries.push({
      locator: resource.locator,
      media_type: resource.media_type,
      bytes,
    })
  }
  { entries, }
}

///|
fn write_file(path : String, contents : String) -> Unit raise IoError {
  @fs.write_string_to_file(path, contents, encoding="utf8") catch {
    error => raise IoError("Failed to write \{path}: \{Repr(error)}")
  }
}

///|
async fn write_stdout(contents : String) -> Unit {
  @stdio.stdout.write(contents) catch {
    error => raise IoError("Failed to write report: \{error}")
  }
}

///|
async fn write_error(message : String) -> Unit noraise {
  @stdio.stderr.write(message + "\n") catch {
    _ => ()
  }
}

///|
async fn execute(config : @cli.Config) -> Int noraise {
  try {
    let before_svg = read_svg(config.before_path)
    let after_svg = read_svg(config.after_path)
    let before_resources = read_resource_bundle(config.before_resources)
    let after_resources = read_resource_bundle(config.after_resources)
    let report = @cli.compare_sources(
      before_svg, after_svg, config, before_resources, after_resources,
    ) catch {
      CheckpointBudgetExceeded(max_checkpoints~) => {
        write_error(
          "Deterministic checkpoint budget \{max_checkpoints} exhausted",
        )
        return 1
      }
      Cancelled => {
        write_error("Comparison cancelled")
        return 1
      }
    }
    let json = @cli.serialize_report(report, config)
    match config.output_path {
      Some(path) =>
        write_file(
          path,
          if config.agent_projection {
            json + "\n"
          } else {
            json
          },
        )
      None => write_stdout(json + "\n")
    }
    match config.html_path {
      Some(path) =>
        write_file(path, @lib.render_html_report(before_svg, after_svg, report))
      None => ()
    }
    match config.summary_path {
      Some(path) => write_file(path, @lib.render_markdown_summary(report))
      None => ()
    }
    if report.analysis_status == "failed" {
      1
    } else {
      0
    }
  } catch {
    IoError(message) => {
      write_error(message)
      2
    }
    error => {
      write_error("Command failed: \{error}")
      2
    }
  }
}

///|
async fn run(args : ArrayView[String]) -> Int noraise {
  let config = @cli.parse(args) catch {
    InvalidArguments(message) => {
      write_error(message)
      return 2
    }
  }
  execute(config)
}

///|
async fn main {
  let code = run(@env.args())
  if code != 0 {
    @sys.exit(code)
  }
}
