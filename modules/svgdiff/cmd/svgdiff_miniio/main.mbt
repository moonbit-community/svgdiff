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
fn read_svg(path : String) -> String raise IoError {
  if path == "-" {
    @miniio.stdin.read_all().text() catch {
      error => raise IoError("Failed to read stdin: \{error}")
    }
  } else {
    @miniio.read_text_file(path) catch {
      error => raise IoError("Failed to read \{path}: \{error}")
    }
  }
}

///|
fn read_resource_bundle(
  resources : Array[@cli.Resource],
) -> @svgdiff.ResourceBundle raise IoError {
  let entries : Array[@svgdiff.ResourceBundleEntry] = []
  for resource in resources {
    let bytes = @miniio.read_file(resource.path).binary() catch {
      error =>
        raise IoError("Failed to read resource \{resource.path}: \{error}")
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
  @miniio.write_text_file(path, contents) catch {
    error => raise IoError("Failed to write \{path}: \{error}")
  }
}

///|
fn write_stdout(contents : String) -> Unit raise IoError {
  @miniio.stdout.write_text(contents) catch {
    error => raise IoError("Failed to write report: \{error}")
  }
}

///|
fn write_error(message : String) -> Unit noraise {
  @miniio.stderr.write_text(message + "\n") catch {
    _ => ()
  }
}

///|
fn execute(config : @cli.Config) -> Int {
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
        write_file(
          path,
          @svgdiff.render_html_report(before_svg, after_svg, report),
        )
      None => ()
    }
    match config.summary_path {
      Some(path) => write_file(path, @svgdiff.render_markdown_summary(report))
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
  }
}

///|
fn run(args : ArrayView[String]) -> Int {
  let config = @cli.parse(args) catch {
    InvalidArguments(message) => {
      write_error(message)
      return 2
    }
  }
  execute(config)
}

///|
fn main {
  let args = @miniio.args_get() catch {
    error => {
      write_error("Failed to read command arguments: \{error}")
      @miniio.exit(2)
      return
    }
  }
  let code = run(args)
  if code != 0 {
    @miniio.exit(code)
  }
}
