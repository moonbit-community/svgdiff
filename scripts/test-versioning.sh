#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=${TMPDIR:-/tmp}/svgdiff-versioning-$$
mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT

cd "$root"

module_version=$(awk -F '"' '$1 ~ /^version = / { print $2; exit }' moon.mod)
test -n "$module_version"
printf '%s\n' "$module_version" | grep -Eq '^(0|[1-9][0-9]*)\.[0-9]+\.[0-9]+$'

moon run --target native cmd/svgdiff -- --version >"$tmp/version.txt"
grep -Fx "svgdiff $module_version" "$tmp/version.txt" >/dev/null
grep -Fx "engine: $module_version" "$tmp/version.txt" >/dev/null
grep -Fx "moon add Milky2018/svgdiff@$module_version" PACKAGE.mbt.md >/dev/null
grep -F "Module version \`$module_version\`" PACKAGE.mbt.md >/dev/null
grep -F "moon add Milky2018/svgdiff@$module_version" README.mbt.md >/dev/null
grep -F "moon add Milky2018/svgdiff@$module_version" docs/library-api.md >/dev/null
grep -F "scripts/check-release-tag.sh v$module_version" release/README.md >/dev/null

schema_version=$(jq -r '.properties.schema_version.const' schema/svgdiff-report.schema.json)
renderer_id=$(sed -n 's/^renderer: //p' "$tmp/version.txt")
conformance_profile=$(sed -n 's/^renderer-conformance-profile: //p' "$tmp/version.txt")
ordering_policy=$(sed -n 's/^ordering-policy: //p' "$tmp/version.txt")
impact_policy=$(sed -n 's/^impact-policy: //p' "$tmp/version.txt")
agent_projection=$(jq -r '.["$defs"].headerRecord.properties.projection_version.const' schema/svgdiff-agent-projection.schema.json)

printf '%s\n' "$schema_version" | grep -Eq '^[1-9][0-9]*\.[0-9]+$'
grep -Fx "schema: $schema_version" "$tmp/version.txt" >/dev/null
grep -Fx "renderer-conformance-profile: $conformance_profile" "$tmp/version.txt" >/dev/null
grep -Fx "ordering-policy: $ordering_policy" "$tmp/version.txt" >/dev/null
grep -Fx "impact-policy: $impact_policy" "$tmp/version.txt" >/dev/null
grep -Fx "agent-projection: $agent_projection" "$tmp/version.txt" >/dev/null
jq -e '
  .required == [
    "schema_version", "analysis_status", "comparison", "canvas",
    "difference_groups", "events", "limitations"
  ]
' schema/svgdiff-report.schema.json >/dev/null

test "$(jq -r '.conformance_profile_id' evaluation/renderer-conformance/baseline.v1.json)" = "$conformance_profile"
test "$(jq -r '.conformance_profile_id' evaluation/renderer-conformance/dispositions.v1.json)" = "$conformance_profile"
jq -e --arg schema "$schema_version" --arg renderer "$renderer_id" \
  --arg profile "$conformance_profile" --arg policy "$ordering_policy" \
  --arg impact "$impact_policy" '
  (.consumer_policy.accepted_schema_versions | index($schema)) != null and
  (.consumer_policy.accepted_renderer_ids | index($renderer)) != null and
  (.consumer_policy.accepted_renderer_conformance_profile_ids |
    index($profile)) != null and
  (.consumer_policy.accepted_ordering_policy_ids | index($policy)) != null and
  (.consumer_policy.accepted_impact_policy_ids | index($impact)) != null
' evaluation/compatibility/manifest.v1.json >/dev/null

moon run --target native cmd/svgdiff -- \
  testdata/before.svg testdata/after.svg --agent-json >"$tmp/report.json"
jq -e --arg schema "$schema_version" '
  .schema_version == $schema and
  .comparison.viewport == {"width":16,"height":16} and
  ([.difference_groups[].items[]] | length) == 1
' "$tmp/report.json" >/dev/null

printf 'Version identities: module=%s schema=%s projection=%s renderer=%s ordering=%s impact=%s conformance=%s\n' \
  "$module_version" "$schema_version" "$agent_projection" "$renderer_id" \
  "$ordering_policy" "$impact_policy" "$conformance_profile"
