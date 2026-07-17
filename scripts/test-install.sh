#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=${TMPDIR:-/tmp}/svgdiff-install-$$
bindir="$tmp/bin"
mkdir -p "$tmp/work"
trap 'rm -rf "$tmp"' EXIT

cd "$root"
first_output=$(sh scripts/install.sh --bindir "$bindir")
test -x "$bindir/svgdiff"
first_hash=$(shasum -a 256 "$bindir/svgdiff" | awk '{print $1}')

cd "$tmp/work"
PATH="$bindir:$PATH" svgdiff \
  "$root/testdata/before.svg" \
  "$root/testdata/after.svg" >report.json 2>report.err
test ! -s report.err
jq -e '
  .schema_version == "1.44" and
  .profile.renderer_conformance_profile_id ==
    "svgdiff-renderer-conformance-profile/25" and
  .analysis_status == "complete" and
  .renderer_capability_gaps == [] and
  (.atomic_differences | length) == 1 and
  .impact_assessment.policy_id == "event_rendered_pareto/v1" and
  .impact_assessment.candidate_event_count == (.events | length) and
  .impact_assessment.frontier_relation == "unique"
' report.json >/dev/null
PATH="$bindir:$PATH" svgdiff --help >help.txt
PATH="$bindir:$PATH" svgdiff --version >version.txt
grep -q '^Usage: svgdiff ' help.txt
grep -q '^svgdiff 0.5.28$' version.txt
grep -q '^schema: 1.44$' version.txt
grep -q '^agent-projection: svgdiff-agent-projection/1$' version.txt
grep -q '^renderer: svgdiff/style-precedence-normalizer@3+ordinary-inheritance-normalizer@1+css-computed-value-normalizer@3+css-color3-opacity-normalizer@1+length-used-value-normalizer@1+stroke-used-geometry-normalizer@1+basic-shape-used-geometry-normalizer@1+isolated-group-compositor@1+static-mask-normalizer@1+static-mask-compositor@1+static-filter-graph-compositor@1+static-blend-compositor@1+mizchi/svg@0.2.1$' version.txt
grep -q '^renderer-conformance-profile: svgdiff-renderer-conformance-profile/25$' version.txt
grep -q '^impact-policy: event_rendered_pareto/v1$' version.txt

PATH="$bindir:$PATH" svgdiff \
  "$root/testdata/before.svg" \
  "$root/testdata/after.svg" --agent-json >agent.json 2>agent.err
test ! -s agent.err
test "$(wc -l <agent.json | tr -d ' ')" -eq 1
jq -e '.schema_version == "1.44" and .profile.renderer_conformance_profile_id == "svgdiff-renderer-conformance-profile/25" and (.atomic_differences | length) == 1 and .impact_assessment.policy_id == "event_rendered_pareto/v1"' agent.json >/dev/null

PATH="$bindir:$PATH" svgdiff \
  "$root/testdata/before.svg" \
  "$root/testdata/after.svg" --agent-projection >projection.jsonl 2>projection.err
test ! -s projection.err
python3 "$root/evaluation/agent-projection/validate.py" \
  --report report.json --projection projection.jsonl >/dev/null

PATH="$bindir:$PATH" svgdiff \
  "$root/testdata/before.svg" \
  "$root/testdata/after.svg" --summary summary.md >summary-report.json 2>summary.err
test ! -s summary.err
jq -e '.schema_version == "1.44"' summary-report.json >/dev/null
grep -q '^# SVG Diff Summary$' summary.md
grep -q 'Structured Report JSON is authoritative' summary.md

cat "$root/testdata/before.svg" | PATH="$bindir:$PATH" svgdiff \
  - "$root/testdata/after.svg" >stdin-report.json 2>stdin-report.err
test ! -s stdin-report.err
jq -e '.schema_version == "1.44" and .analysis_status == "complete"' stdin-report.json >/dev/null

cat "$root/testdata/after.svg" | PATH="$bindir:$PATH" svgdiff \
  "$root/testdata/before.svg" - >stdin-after-report.json 2>stdin-after-report.err
test ! -s stdin-after-report.err
jq -e '.schema_version == "1.44" and .analysis_status == "complete"' stdin-after-report.json >/dev/null

if printf '%s\n' '<svg/>' | PATH="$bindir:$PATH" svgdiff \
  - - >double-stdin.out 2>double-stdin.err; then
  echo "Installed CLI unexpectedly accepted two stdin operands" >&2
  exit 1
fi
test ! -s double-stdin.out
grep -q '^Only one SVG input may use stdin (-)$' double-stdin.err

cd "$root"
second_output=$(sh scripts/install.sh --bindir "$bindir")
second_hash=$(shasum -a 256 "$bindir/svgdiff" | awk '{print $1}')
test "$first_hash" = "$second_hash"
test "$first_output" = "$second_output"

printf 'Install workflow: release build: ok, PATH invocation: ok, reinstall: deterministic\n'
