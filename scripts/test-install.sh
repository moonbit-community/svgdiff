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
  "$root/testdata/after.svg" >report.json
jq -e '
  .schema_version == "1.0" and
  .analysis_status == "complete" and
  (.atomic_differences | length) == 1
' report.json >/dev/null
PATH="$bindir:$PATH" svgdiff --help >help.txt
PATH="$bindir:$PATH" svgdiff --version >version.txt
grep -q '^Usage: svgdiff ' help.txt
grep -q '^svgdiff 0.1.0$' version.txt
grep -q '^schema: 1.0$' version.txt
grep -q '^renderer: mizchi/svg@0.2.1$' version.txt

cd "$root"
second_output=$(sh scripts/install.sh --bindir "$bindir")
second_hash=$(shasum -a 256 "$bindir/svgdiff" | awk '{print $1}')
test "$first_hash" = "$second_hash"
test "$first_output" = "$second_output"

printf 'Install workflow: release build: ok, PATH invocation: ok, reinstall: deterministic\n'
