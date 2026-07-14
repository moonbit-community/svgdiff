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
  .schema_version == "1.0" and
  .profile.renderer_conformance_profile_id ==
    "svgdiff-renderer-conformance-profile/1" and
  .analysis_status == "complete" and
  .renderer_capability_gaps == [] and
  (.atomic_differences | length) == 1
' report.json >/dev/null
PATH="$bindir:$PATH" svgdiff --help >help.txt
PATH="$bindir:$PATH" svgdiff --version >version.txt
grep -q '^Usage: svgdiff ' help.txt
grep -q '^svgdiff 0.1.0$' version.txt
grep -q '^schema: 1.0$' version.txt
grep -q '^renderer: mizchi/svg@0.2.1$' version.txt
grep -q '^renderer-conformance-profile: svgdiff-renderer-conformance-profile/1$' version.txt

PATH="$bindir:$PATH" svgdiff \
  "$root/testdata/before.svg" \
  "$root/testdata/after.svg" --agent-json >agent.json 2>agent.err
test ! -s agent.err
test "$(wc -l <agent.json | tr -d ' ')" -eq 1
jq -e '.schema_version == "1.0" and .profile.renderer_conformance_profile_id == "svgdiff-renderer-conformance-profile/1" and (.atomic_differences | length) == 1' agent.json >/dev/null

cat "$root/testdata/before.svg" | PATH="$bindir:$PATH" svgdiff \
  - "$root/testdata/after.svg" >stdin-report.json 2>stdin-report.err
test ! -s stdin-report.err
jq -e '.schema_version == "1.0" and .analysis_status == "complete"' stdin-report.json >/dev/null

cat "$root/testdata/after.svg" | PATH="$bindir:$PATH" svgdiff \
  "$root/testdata/before.svg" - >stdin-after-report.json 2>stdin-after-report.err
test ! -s stdin-after-report.err
jq -e '.schema_version == "1.0" and .analysis_status == "complete"' stdin-after-report.json >/dev/null

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
