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
test "CLI help documents options and exit statuses" {
  let help = command("svgdiff").render_help()
  assert_true(help.has_prefix("Usage: svgdiff"))
  assert_true(help.contains("--width <width>"))
  assert_true(help.contains("--height <height>"))
  assert_true(help.contains("--max-checkpoints <max-checkpoints>"))
  assert_true(help.contains("--perceptual-background <perceptual-background>"))
  assert_true(
    help.contains("--flip-pixels-per-degree <flip-pixels-per-degree>"),
  )
  assert_true(help.contains("--flip-error-threshold <flip-error-threshold>"))
  assert_true(help.contains("--output <output>"))
  assert_true(help.contains("--before-resource <before-resource>"))
  assert_true(help.contains("--after-resource <after-resource>"))
  assert_true(help.contains("locator, media_type, and path"))
  assert_true(help.contains("read only when named"))
  assert_true(help.contains("--html <html>"))
  assert_true(help.contains("--summary <summary>"))
  assert_true(help.contains("--agent-json"))
  assert_true(help.contains("--agent-projection"))
  assert_true(help.contains("--help"))
  assert_true(help.contains("--version"))
  assert_true(help.contains("Use - for exactly one input"))
  assert_true(help.contains("2  Invalid arguments or file I/O failure"))
}

///|
test "CLI version exposes every contract identity" {
  assert_eq(
    version_text("svgdiff"),
    (
      #|svgdiff 0.7.0
      #|engine: 0.7.0
      #|schema: 2.0
      #|agent-projection: svgdiff-agent-projection/1
      #|renderer: svgdiff/residual-paint-normalizer@1+opacity-used-value-normalizer@1+length-unit-normalizer@1+shape-css-points-normalizer@1+stroke-length-normalizer@1+mask-edge-semantics-normalizer@1+isolated-group-compositor@1+static-mask-compositor@1+empty-filter-outcome-adapter@1+static-blend-compositor@1+Milky2018/svg@0.3.1
      #|renderer-conformance-profile: svgdiff-renderer-conformance-profile/27
      #|ordering-policy: v2_domain_lexicographic
      #|impact-policy: event_rendered_pareto/v1
    ),
  )
}
