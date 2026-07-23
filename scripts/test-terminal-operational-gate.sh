#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/svgdiff-terminal-operational.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
manifest=evaluation/terminal-operational-gate/manifest.v1.json
validator=evaluation/terminal-operational-gate/validate.py

assert_status() {
  expected=$1
  shift
  set +e
  "$@"
  actual=$?
  set -e
  if [ "$actual" -ne "$expected" ]; then
    printf 'Expected exit status %s, got %s: %s\n' "$expected" "$actual" "$*" >&2
    exit 1
  fi
}

cd "$root"
python3 "$validator" "$manifest"
python3 -m json.tool "$manifest" >/dev/null

jq 'del(.obligations[0])' "$manifest" >"$tmp/missing-obligation.json"
assert_status 1 python3 "$validator" "$tmp/missing-obligation.json" >/dev/null 2>&1
for field in controls authorities suites; do
  jq --arg field "$field" 'del(.obligations[0][$field])' "$manifest" \
    >"$tmp/missing-$field.json"
  assert_status 1 python3 "$validator" "$tmp/missing-$field.json" >/dev/null 2>&1
done
jq 'del(.supported_environments[0])' "$manifest" >"$tmp/missing-environment.json"
assert_status 1 python3 "$validator" "$tmp/missing-environment.json" >/dev/null 2>&1
jq '.supported_environments[0].runner = "ubuntu-latest"' "$manifest" \
  >"$tmp/wrong-runner.json"
assert_status 1 python3 "$validator" "$tmp/wrong-runner.json" >/dev/null 2>&1
jq 'del(.security_non_guarantees[0])' "$manifest" >"$tmp/missing-boundary.json"
assert_status 1 python3 "$validator" "$tmp/missing-boundary.json" >/dev/null 2>&1
jq 'del(.suite_commands[0])' "$manifest" >"$tmp/missing-suite.json"
assert_status 1 python3 "$validator" "$tmp/missing-suite.json" >/dev/null 2>&1

sed '/platform: windows-x64/d' .github/workflows/ci.yml >"$tmp/incomplete-ci.yml"
assert_status 1 python3 "$validator" "$manifest" \
  --ci-workflow "$tmp/incomplete-ci.yml" >/dev/null 2>&1
sed 's/sh scripts\/test-release-bundle.sh/sh scripts\/missing-release-gate.sh/' \
  .github/workflows/release.yml >"$tmp/incomplete-release.yml"
assert_status 1 python3 "$validator" "$manifest" \
  --release-workflow "$tmp/incomplete-release.yml" >/dev/null 2>&1

moon test --target native \
  modules/svgdiff/engine/internal/diff/resource_limits_wbtest.mbt \
  modules/svgdiff/engine/internal/diff/resource_bundle_wbtest.mbt \
  modules/svgdiff/engine/internal/diff/resource_dependency_graph_wbtest.mbt \
  modules/svgdiff/engine/internal/diff/resource_outcome_policy_wbtest.mbt
sh scripts/test-report-determinism.sh
sh scripts/test-cross-platform-determinism.sh
sh scripts/test-install.sh
sh scripts/test-release-bundle.sh
sh scripts/test-module-package.sh
sh scripts/test-versioning.sh
sh scripts/test-compatibility.sh
sh scripts/test-cli.sh
sh scripts/test-fuzz-smoke.sh
sh scripts/test-adversarial.sh
sh scripts/test-html-security.sh

printf 'Terminal operational readiness gate: passed\n'
