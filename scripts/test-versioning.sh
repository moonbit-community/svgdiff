#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=${TMPDIR:-/tmp}/svgdiff-versioning-$$
mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT

cd "$root"

module_version=$(awk -F '"' '$1 ~ /^version = / { print $2; exit }' modules/svgdiff/moon.mod)
test -n "$module_version"
printf '%s\n' "$module_version" | grep -Eq '^(0|[1-9][0-9]*)\.[0-9]+\.[0-9]+$'

moon run --target native modules/svgdiff/cmd/svgdiff -- --version >"$tmp/version.txt"
grep -Fx "svgdiff $module_version" "$tmp/version.txt" >/dev/null
grep -Fx "engine: $module_version" "$tmp/version.txt" >/dev/null
native_binary=_build/native/debug/build/Milky2018/svgdiff/cmd/svgdiff/svgdiff.exe
windows_named_binary="$tmp/C:\\tools\\svgdiff.exe"
cp "$native_binary" "$windows_named_binary"
"$windows_named_binary" --version >"$tmp/windows-path-version.txt"
grep -Fx "svgdiff $module_version" "$tmp/windows-path-version.txt" >/dev/null
grep -Fx "moon add Milky2018/svgdiff@$module_version" modules/svgdiff/README.mbt.md >/dev/null
grep -F "moon add Milky2018/svgdiff@$module_version" README.mbt.md >/dev/null
grep -F "moon add Milky2018/svgdiff@$module_version" docs/library-api.md >/dev/null

schema_version=$(jq -r '.properties.schema_version.const' schema/svgdiff-report.schema.json)
renderer_id=$(sed -n 's/^renderer: //p' "$tmp/version.txt")
conformance_profile=$(sed -n 's/^renderer-conformance-profile: //p' "$tmp/version.txt")
ordering_policy=$(sed -n 's/^ordering-policy: //p' "$tmp/version.txt")
impact_policy=$(sed -n 's/^impact-policy: //p' "$tmp/version.txt")
agent_projection=$(jq -r '.["$defs"].headerRecord.properties.projection_version.const' schema/svgdiff-agent-projection.schema.json)

printf '%s\n' "$schema_version" | grep -Eq '^[1-9][0-9]*\.[0-9]+$'
renderer_dependency_version=$(sed -n \
  's/^[[:space:]]*"Milky2018\/svg@\([^"]*\)",[[:space:]]*$/\1/p' \
  modules/svgdiff/moon.mod)
test -n "$renderer_dependency_version"
case "$renderer_id" in
  *"+Milky2018/svg@$renderer_dependency_version") ;;
  *)
    printf 'Renderer identity %s does not match Milky2018/svg@%s\n' \
      "$renderer_id" "$renderer_dependency_version" >&2
    exit 1
    ;;
esac
test "$(jq -r '.renderer_id' evaluation/renderer-conformance/baseline.v1.json)" = \
  "Milky2018/svg@$renderer_dependency_version"
grep -Fx "schema: $schema_version" "$tmp/version.txt" >/dev/null
grep -Fx "renderer-conformance-profile: $conformance_profile" "$tmp/version.txt" >/dev/null
grep -Fx "ordering-policy: $ordering_policy" "$tmp/version.txt" >/dev/null
grep -Fx "impact-policy: $impact_policy" "$tmp/version.txt" >/dev/null
grep -Fx "agent-projection: $agent_projection" "$tmp/version.txt" >/dev/null
jq -e '
  .required == [
    "schema_version", "analysis_status", "comparison", "canvas",
    "changed_facts", "scene", "difference_groups", "events", "limitations"
  ]
' schema/svgdiff-report.schema.json >/dev/null

test "$(jq -r '.conformance_profile_id' evaluation/renderer-conformance/baseline.v1.json)" = "$conformance_profile"
test "$(jq -r '.conformance_profile_id' evaluation/renderer-conformance/dispositions.v1.json)" = "$conformance_profile"
jq -e --arg schema "$schema_version" '
  .consumer_policy.current_schema_version == $schema and
  (.consumer_policy.accepted_schema_versions | index($schema)) != null
' evaluation/compatibility/manifest.v1.json >/dev/null

moon run --target native modules/svgdiff/cmd/svgdiff -- \
  testdata/before.svg testdata/after.svg --agent-json >"$tmp/report.json"
jq -e --arg schema "$schema_version" '
  .schema_version == $schema and
  .comparison.viewport == {"width":16,"height":16} and
  ([.difference_groups[].items[]] | length) == 1
' "$tmp/report.json" >/dev/null

printf 'Version identities: module=%s schema=%s projection=%s renderer=%s ordering=%s impact=%s conformance=%s\n' \
  "$module_version" "$schema_version" "$agent_projection" "$renderer_id" \
  "$ordering_policy" "$impact_policy" "$conformance_profile"
