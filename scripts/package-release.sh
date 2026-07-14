#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
output_root="$root/dist"
allow_dirty=false

usage() {
  printf 'Usage: %s [--output DIR] [--allow-dirty]\n' "$0"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --output)
      if [ "$#" -lt 2 ]; then
        usage >&2
        exit 2
      fi
      output_root=$2
      shift 2
      ;;
    --allow-dirty)
      allow_dirty=true
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
done

for command in git jq moon shasum; do
  if ! command -v "$command" >/dev/null 2>&1; then
    printf '%s is required to package a release bundle\n' "$command" >&2
    exit 1
  fi
done

cd "$root"
source_dirty=false
if [ -n "$(git status --porcelain --untracked-files=normal)" ]; then
  source_dirty=true
fi
if [ "$source_dirty" = true ] && [ "$allow_dirty" != true ]; then
  printf 'Refusing to package a release from a dirty worktree; use --allow-dirty only for local inspection\n' >&2
  exit 1
fi

dependency_manifest="$root/release/dependencies.v1.json"
test "$(jq -r '.schema_version' "$dependency_manifest")" = "svgdiff-release-dependencies/1"
dependency_tree=$(moon tree)
jq -r '.dependencies[] | "\(.name)@\(.version)"' "$dependency_manifest" |
  while IFS= read -r dependency; do
    if ! printf '%s\n' "$dependency_tree" | grep -F "$dependency" >/dev/null; then
      printf 'Resolved dependency is missing or changed: %s\n' "$dependency" >&2
      exit 1
    fi
  done
test "$(jq '[.dependencies[].name] | unique | length' "$dependency_manifest")" = "$(jq '.dependencies | length' "$dependency_manifest")"
tree_dependency_count=$(printf '%s\n' "$dependency_tree" | grep -Eo '[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+@[0-9][^ )]*' | grep -v '^Milky2018/svgdiff@' | sort -u | wc -l | tr -d ' ')
test "$tree_dependency_count" = "$(jq '.dependencies | length' "$dependency_manifest")"
test "$(jq '[.dependencies[] | select(.license != "Apache-2.0")] | length' "$dependency_manifest")" = 0

module_version=$(awk -F '"' '$1 ~ /^version = / { print $2; exit }' moon.mod)
target_os=$(uname -s | tr '[:upper:]' '[:lower:]')
target_arch=$(uname -m)
bundle="$output_root/svgdiff-$module_version-$target_os-$target_arch"

moon build --target native --release cmd/svgdiff >/dev/null
binary="$root/_build/native/release/build/cmd/svgdiff/svgdiff.exe"
if [ ! -x "$binary" ]; then
  printf 'Release binary was not produced at %s\n' "$binary" >&2
  exit 1
fi

rm -rf "$bundle"
mkdir -p "$bundle"
install -m 0755 "$binary" "$bundle/svgdiff"
install -m 0644 "$root/LICENSE" "$bundle/LICENSE"

{
  printf '# Third-Party Notices\n\n'
  printf 'This native bundle contains code from the resolved MoonBit packages below. Each package manifest declares Apache-2.0. The complete Apache License 2.0 text is included as `LICENSE`. No resolved package contains a `NOTICE` file.\n\n'
  printf 'A missing package-local license file is disclosed explicitly; it is not represented as stronger evidence than the resolved manifest declaration.\n\n'
  jq -r '.dependencies[] | "- `\(.name)@\(.version)` (\(.relationship)): [upstream](\(.repository)); `\(.license)` declared by the resolved package manifest; package-local license file: \(if .packaged_license_file then "present" else "absent" end)."' "$dependency_manifest"
} >"$bundle/THIRD_PARTY_NOTICES.md"

artifact_sha256=$(shasum -a 256 "$bundle/svgdiff" | awk '{ print $1 }')
source_revision=$(git rev-parse HEAD)
moon_version=$(moon version | sed -n '1p')
version_output=$($bundle/svgdiff --version)
schema_version=$(printf '%s\n' "$version_output" | sed -n 's/^schema: //p')
renderer_id=$(printf '%s\n' "$version_output" | sed -n 's/^renderer: //p')
conformance_profile=$(printf '%s\n' "$version_output" | sed -n 's/^renderer-conformance-profile: //p')
ordering_policy=$(printf '%s\n' "$version_output" | sed -n 's/^ordering-policy: //p')

jq -n \
  --arg artifact_sha256 "$artifact_sha256" \
  --arg module_version "$module_version" \
  --arg source_revision "$source_revision" \
  --argjson source_dirty "$source_dirty" \
  --arg moon_version "$moon_version" \
  --arg target_os "$target_os" \
  --arg target_arch "$target_arch" \
  --arg schema_version "$schema_version" \
  --arg renderer_id "$renderer_id" \
  --arg conformance_profile "$conformance_profile" \
  --arg ordering_policy "$ordering_policy" \
  --slurpfile dependency_data "$dependency_manifest" \
  '{
    schema_version: "svgdiff-release-provenance/1",
    subject: { name: "svgdiff", sha256: $artifact_sha256 },
    source: { revision: $source_revision, dirty: $source_dirty },
    build: {
      toolchain: $moon_version,
      target_os: $target_os,
      target_architecture: $target_arch,
      command: "moon build --target native --release cmd/svgdiff"
    },
    product: {
      module_version: $module_version,
      report_schema_version: $schema_version,
      renderer_id: $renderer_id,
      renderer_conformance_profile_id: $conformance_profile,
      ordering_policy_id: $ordering_policy
    },
    resolved_dependencies: ($dependency_data[0].dependencies | map({name, version, repository, license}))
  }' >"$bundle/provenance.json"

(
  cd "$bundle"
  shasum -a 256 LICENSE THIRD_PARTY_NOTICES.md provenance.json svgdiff >SHA256SUMS
)

printf 'Created %s\n' "$bundle"
printf 'Verify with: (cd %s && shasum -a 256 -c SHA256SUMS)\n' "$bundle"
