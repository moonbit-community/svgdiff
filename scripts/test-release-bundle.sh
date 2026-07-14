#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=${TMPDIR:-/tmp}/svgdiff-release-bundle-$$
dirty_marker="$root/.svgdiff-release-dirty-test-$$"
mkdir -p "$tmp"
trap 'rm -rf "$tmp"; rm -f "$dirty_marker"' EXIT

cd "$root"
: >"$dirty_marker"
if sh scripts/package-release.sh --output "$tmp/rejected" >"$tmp/rejected.out" 2>"$tmp/rejected.err"; then
  printf 'Dirty release packaging unexpectedly succeeded\n' >&2
  exit 1
fi
grep -F 'Refusing to package a release from a dirty worktree' "$tmp/rejected.err" >/dev/null
sh scripts/package-release.sh --allow-dirty --output "$tmp/dist" >"$tmp/package.out"
bundle=$(find "$tmp/dist" -mindepth 1 -maxdepth 1 -type d)
test -n "$bundle"
test -x "$bundle/svgdiff"
test -f "$bundle/LICENSE"
test -f "$bundle/THIRD_PARTY_NOTICES.md"
test -f "$bundle/provenance.json"
test -f "$bundle/SHA256SUMS"
cmp LICENSE "$bundle/LICENSE"
(
  cd "$bundle"
  shasum -a 256 -c SHA256SUMS >/dev/null
)

artifact_sha256=$(shasum -a 256 "$bundle/svgdiff" | awk '{ print $1 }')
source_revision=$(git rev-parse HEAD)
module_version=$(awk -F '"' '$1 ~ /^version = / { print $2; exit }' moon.mod)
jq -e \
  --arg sha "$artifact_sha256" \
  --arg revision "$source_revision" \
  --arg version "$module_version" '
  .schema_version == "svgdiff-release-provenance/1" and
  .subject == {"name": "svgdiff", "sha256": $sha} and
  .source.revision == $revision and
  .source.dirty == true and
  .build.command == "moon build --target native --release cmd/svgdiff" and
  (.build.toolchain | startswith("moon ")) and
  (.build.target_os | length) > 0 and
  (.build.target_architecture | length) > 0 and
  .product.module_version == $version and
  .product.report_schema_version == "1.1" and
  .product.renderer_conformance_profile_id == "svgdiff-renderer-conformance-profile/1" and
  .product.ordering_policy_id == "v1_domain_lexicographic" and
  (.resolved_dependencies | length) == 7
' "$bundle/provenance.json" >/dev/null

test "$(jq '.dependencies | length' release/dependencies.v1.json)" = 7
moon tree >"$tmp/tree.txt"
jq -r '.dependencies[] | "\(.name)@\(.version)"' release/dependencies.v1.json |
  while IFS= read -r dependency; do
    grep -F "$dependency" "$tmp/tree.txt" >/dev/null
    grep -F "\`$dependency\`" "$bundle/THIRD_PARTY_NOTICES.md" >/dev/null
  done

"$bundle/svgdiff" --version | grep -Fx "svgdiff $module_version" >/dev/null
grep -F 'Created ' "$tmp/package.out" >/dev/null
printf 'Release bundle: checksums, provenance, license, and notices: ok\n'
