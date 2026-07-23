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
priv suberror InputError {
  InputError(String)
}

///|
fn read_svg(path : String) -> String raise InputError {
  if path == "-" {
    @miniio.stdin.read_all().text() catch {
      error => raise InputError("Failed to read stdin: \{error}")
    }
  } else {
    @miniio.read_text_file(path) catch {
      error => raise InputError("Failed to read \{path}: \{error}")
    }
  }
}

///|
fn read_resource_bundle(
  resources : Array[@cli.Resource],
) -> @svgdiff.ResourceBundle raise InputError {
  let entries : Array[@svgdiff.ResourceBundleEntry] = []
  for resource in resources {
    let bytes = @miniio.read_file(resource.path).binary() catch {
      error =>
        raise InputError("Failed to read resource \{resource.path}: \{error}")
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
fn write_error(message : String) -> Unit {
  @miniio.stderr.write_text(message + "\n") catch {
    _ => ()
  }
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
  let config = @cli.parse(args) catch {
    InvalidArguments(message) => {
      write_error(message)
      @miniio.exit(2)
      return
    }
  }
  let before_svg = read_svg(config.before_path) catch {
    InputError(message) => {
      write_error(message)
      @miniio.exit(2)
      return
    }
  }
  let after_svg = read_svg(config.after_path) catch {
    InputError(message) => {
      write_error(message)
      @miniio.exit(2)
      return
    }
  }
  let before_resources = read_resource_bundle(config.before_resources) catch {
    InputError(message) => {
      write_error(message)
      @miniio.exit(2)
      return
    }
  }
  let after_resources = read_resource_bundle(config.after_resources) catch {
    InputError(message) => {
      write_error(message)
      @miniio.exit(2)
      return
    }
  }
  let report = @cli.compare_sources(
    before_svg, after_svg, config, before_resources, after_resources,
  ) catch {
    CheckpointBudgetExceeded(max_checkpoints~) => {
      write_error(
        "Deterministic checkpoint budget \{max_checkpoints} exhausted",
      )
      @miniio.exit(1)
      return
    }
    Cancelled => {
      write_error("Comparison cancelled")
      @miniio.exit(1)
      return
    }
  }
  let json = @cli.serialize_report(report, config)
  match config.output_path {
    Some(path) =>
      @miniio.write_text_file(
        path,
        if config.agent_projection {
          json + "\n"
        } else {
          json
        },
      ) catch {
        error => {
          write_error("Failed to write \{path}: \{error}")
          @miniio.exit(2)
        }
      }
    None =>
      @miniio.stdout.write_text(json + "\n") catch {
        error => {
          write_error("Failed to write report: \{error}")
          @miniio.exit(2)
          return
        }
      }
  }
  match config.html_path {
    Some(path) => {
      let html = @svgdiff.render_html_report(before_svg, after_svg, report)
      @miniio.write_text_file(path, html) catch {
        error => {
          write_error("Failed to write \{path}: \{error}")
          @miniio.exit(2)
        }
      }
    }
    None => ()
  }
  match config.summary_path {
    Some(path) => {
      let summary = @svgdiff.render_markdown_summary(report)
      @miniio.write_text_file(path, summary) catch {
        error => {
          write_error("Failed to write \{path}: \{error}")
          @miniio.exit(2)
        }
      }
    }
    None => ()
  }
  if report.analysis_status == "failed" {
    @miniio.exit(1)
  }
}
