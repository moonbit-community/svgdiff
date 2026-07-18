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
sh scripts/package-release.sh --allow-dirty --archive --output "$tmp/dist" >"$tmp/package.out"
bundle=$(find "$tmp/dist" -mindepth 1 -maxdepth 1 -type d)
test -n "$bundle"
test -f "$bundle/LICENSE"
test -f "$bundle/THIRD_PARTY_NOTICES.md"
test -f "$bundle/provenance.json"
test -f "$bundle/SHA256SUMS"
executable_name=$(jq -r '.subject.name' "$bundle/provenance.json")
test -f "$bundle/$executable_name"
case "${RUNNER_OS-}" in
  Linux) expected_os=linux ;;
  Windows) expected_os=windows ;;
  macOS) expected_os=macos ;;
  "")
    case "$(uname -s)" in
      Linux) expected_os=linux ;;
      Darwin) expected_os=macos ;;
      *) exit 1 ;;
    esac
    ;;
  *) exit 1 ;;
esac
raw_arch=${RUNNER_ARCH-}
if [ -z "$raw_arch" ]; then
  raw_arch=$(uname -m)
fi
case "$raw_arch" in
  X64 | x86_64 | amd64) expected_arch=x64 ;;
  ARM64 | arm64 | aarch64) expected_arch=arm64 ;;
  *) exit 1 ;;
esac
test "$(jq -r '.build.target_os' "$bundle/provenance.json")" = "$expected_os"
test "$(jq -r '.build.target_architecture' "$bundle/provenance.json")" = "$expected_arch"
expected_version=$(awk -F '"' '$1 ~ /^version = / { print $2; exit }' moon.mod)
expected_bundle="svgdiff-$expected_version-$expected_os-$expected_arch"
test "$(basename "$bundle")" = "$expected_bundle"
if [ "$expected_os" = windows ]; then
  test "$executable_name" = svgdiff.exe
else
  test "$executable_name" = svgdiff
  test -x "$bundle/$executable_name"
fi
cmp LICENSE "$bundle/LICENSE"
(
  cd "$bundle"
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 -c SHA256SUMS >/dev/null
  else
    sha256sum -c SHA256SUMS >/dev/null
  fi
)

archive="$bundle.tar.gz"
test -f "$archive"
mkdir -p "$tmp/extracted"
tar -xzf "$archive" -C "$tmp/extracted"
diff -r "$bundle" "$tmp/extracted/$(basename "$bundle")" >/dev/null

if command -v shasum >/dev/null 2>&1; then
  artifact_sha256=$(shasum -a 256 "$bundle/$executable_name" | awk '{ print $1 }')
else
  artifact_sha256=$(sha256sum "$bundle/$executable_name" | awk '{ print $1 }')
fi
source_revision=$(git rev-parse HEAD)
module_version=$(awk -F '"' '$1 ~ /^version = / { print $2; exit }' moon.mod)
jq -e \
  --arg sha "$artifact_sha256" \
  --arg revision "$source_revision" \
  --arg version "$module_version" \
  --arg executable_name "$executable_name" '
  .schema_version == "svgdiff-release-provenance/2" and
  .subject == {"name": $executable_name, "sha256": $sha} and
  .source.revision == $revision and
  .source.dirty == true and
  .build.command == "moon build --target native --release cmd/svgdiff" and
  (.build.toolchain | startswith("moon ")) and
  (.build.target_os | length) > 0 and
  (.build.target_architecture | length) > 0 and
  .product.module_version == $version and
  .product.report_schema_version == "1.45" and
  .product.agent_projection_version == "svgdiff-agent-projection/1" and
  .product.renderer_conformance_profile_id == "svgdiff-renderer-conformance-profile/25" and
  .product.ordering_policy_id == "v2_domain_lexicographic" and
  .product.impact_policy_id == "event_rendered_pareto/v1" and
  (.resolved_dependencies | length) == 9
' "$bundle/provenance.json" >/dev/null

test "$(jq '.dependencies | length' release/dependencies.v1.json)" = 9
moon tree >"$tmp/tree.txt"
jq -r '.dependencies[] | "\(.name)@\(.version)"' release/dependencies.v1.json |
  while IFS= read -r dependency; do
    grep -F "$dependency" "$tmp/tree.txt" >/dev/null
    grep -F "\`$dependency\`" "$bundle/THIRD_PARTY_NOTICES.md" >/dev/null
  done

"$bundle/$executable_name" --version | grep -Fx "svgdiff $module_version" >/dev/null
"$bundle/$executable_name" --version | grep -Fx "agent-projection: svgdiff-agent-projection/1" >/dev/null
"$bundle/$executable_name" --version | grep -Fx "impact-policy: event_rendered_pareto/v1" >/dev/null
"$bundle/$executable_name" testdata/before.svg testdata/after.svg \
  >"$tmp/bundle-report.json"
"$bundle/$executable_name" testdata/before.svg testdata/after.svg \
  --agent-projection >"$tmp/bundle-projection.jsonl"
python3 evaluation/agent-projection/validate.py \
  --report "$tmp/bundle-report.json" \
  --projection "$tmp/bundle-projection.jsonl" >/dev/null
"$bundle/$executable_name" testdata/before.svg testdata/after.svg \
  --summary "$tmp/bundle-summary.md" >"$tmp/bundle-summary-report.json"
cmp "$tmp/bundle-report.json" "$tmp/bundle-summary-report.json"
grep -q '^# SVG Diff Summary$' "$tmp/bundle-summary.md"
grep -q 'Structured Report JSON is authoritative' "$tmp/bundle-summary.md"
sh scripts/check-release-tag.sh "v$module_version" >/dev/null
if sh scripts/check-release-tag.sh "$module_version" >"$tmp/tag.out" 2>"$tmp/tag.err"; then
  printf 'Release tag without v prefix unexpectedly succeeded\n' >&2
  exit 1
fi
grep -F "expected v$module_version" "$tmp/tag.err" >/dev/null
grep -F 'Created ' "$tmp/package.out" >/dev/null
printf 'Release bundle: archive, checksums, provenance, license, notices, and tag gate: ok\n'
