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
fn read_resource_bundle(
  resources : Array[@cli.Resource],
) -> ResourceInputResult {
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
  let config = match @cli.parse(args) {
    Ok(config) => config
    Err(message) => {
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
  let report = @cli.compare_sources(
    before_svg, after_svg, config, before_resources, after_resources,
  ) catch {
    CheckpointBudgetExceeded(max_checkpoints~) => {
      write_error(
        "Deterministic checkpoint budget \{max_checkpoints} exhausted",
      )
      @sys.exit(1)
      return
    }
    Cancelled => {
      write_error("Comparison cancelled")
      @sys.exit(1)
      return
    }
  }
  let json = @cli.serialize_report(report, config)
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
    None => @stdio.stdout.write(json + "\n")
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
  match config.summary_path {
    Some(path) => {
      let summary = @lib.render_markdown_summary(report)
      @fs.write_string_to_file(path, summary, encoding="utf8") catch {
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
