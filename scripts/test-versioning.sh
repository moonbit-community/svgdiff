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
ordering_policy=$(jq -r '.["$defs"].atomicDifference.properties.domain_ordering.properties.policy_id.const' schema/svgdiff-report.schema.json)

printf '%s\n' "$schema_version" | grep -Eq '^[1-9][0-9]*\.[0-9]+$'
grep -Fx "schema: $schema_version" "$tmp/version.txt" >/dev/null
grep -Fx "renderer-conformance-profile: $conformance_profile" "$tmp/version.txt" >/dev/null
grep -Fx "ordering-policy: $ordering_policy" "$tmp/version.txt" >/dev/null
jq -e '
  .properties.profile.properties.renderer_id ==
    {"type": "string", "minLength": 1} and
  .properties.profile.properties.renderer_conformance_profile_id ==
    {"type": "string", "minLength": 1}
' schema/svgdiff-report.schema.json >/dev/null

test "$(jq -r '.conformance_profile_id' evaluation/renderer-conformance/baseline.v1.json)" = "$conformance_profile"
test "$(jq -r '.conformance_profile_id' evaluation/renderer-conformance/dispositions.v1.json)" = "$conformance_profile"
jq -e --arg schema "$schema_version" --arg renderer "$renderer_id" \
  --arg profile "$conformance_profile" --arg policy "$ordering_policy" '
  (.consumer_policy.accepted_schema_versions | index($schema)) != null and
  (.consumer_policy.accepted_renderer_ids | index($renderer)) != null and
  (.consumer_policy.accepted_renderer_conformance_profile_ids |
    index($profile)) != null and
  (.consumer_policy.accepted_ordering_policy_ids | index($policy)) != null
' evaluation/compatibility/manifest.v1.json >/dev/null

moon run --target native cmd/svgdiff -- \
  testdata/before.svg testdata/after.svg --agent-json >"$tmp/report.json"
jq -e --arg schema "$schema_version" \
  --arg renderer "$renderer_id" --arg profile "$conformance_profile" \
  --arg policy "$ordering_policy" '
  .schema_version == $schema and
  .profile.renderer_id == $renderer and
  .profile.renderer_conformance_profile_id == $profile and
  all(.atomic_differences[]; .domain_ordering.policy_id == $policy)
' "$tmp/report.json" >/dev/null

printf 'Version identities: module=%s schema=%s renderer=%s ordering=%s conformance=%s\n' \
  "$module_version" "$schema_version" "$renderer_id" "$ordering_policy" \
  "$conformance_profile"
