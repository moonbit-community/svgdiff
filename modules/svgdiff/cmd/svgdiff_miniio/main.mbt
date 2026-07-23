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
priv enum ResourceInputResult {
  LoadedResourceBundle(@svgdiff.ResourceBundle)
  ResourceInputError(String)
}

///|
fn read_svg(path : String) -> Result[String, String] {
  if path == "-" {
    try @miniio.stdin.read_all().text() catch {
      error => Err("Failed to read stdin: \{error}")
    } noraise {
      source => Ok(source)
    }
  } else {
    try @miniio.read_text_file(path) catch {
      error => Err("Failed to read \{path}: \{error}")
    } noraise {
      source => Ok(source)
    }
  }
}

///|
fn read_resource_bundle(
  resources : Array[@cli.Resource],
) -> ResourceInputResult {
  let entries : Array[@svgdiff.ResourceBundleEntry] = []
  for resource in resources {
    let bytes = @miniio.read_file(resource.path).binary() catch {
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
  let config = match @cli.parse(args) {
    Ok(config) => config
    Err(message) => {
      write_error(message)
      @miniio.exit(2)
      return
    }
  }
  let before_svg = match read_svg(config.before_path) {
    Ok(source) => source
    Err(message) => {
      write_error(message)
      @miniio.exit(2)
      return
    }
  }
  let after_svg = match read_svg(config.after_path) {
    Ok(source) => source
    Err(message) => {
      write_error(message)
      @miniio.exit(2)
      return
    }
  }
  let before_resources = match read_resource_bundle(config.before_resources) {
    LoadedResourceBundle(bundle) => bundle
    ResourceInputError(message) => {
      write_error(message)
      @miniio.exit(2)
      return
    }
  }
  let after_resources = match read_resource_bundle(config.after_resources) {
    LoadedResourceBundle(bundle) => bundle
    ResourceInputError(message) => {
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
