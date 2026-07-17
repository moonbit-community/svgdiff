#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/svgdiff-terminal-agent.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
manifest=evaluation/terminal-agent-reliability-gate/manifest.v1.json
validator=evaluation/terminal-agent-reliability-gate/validate.py

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
jq '.obligations[0].target = 0' "$manifest" >"$tmp/wrong-target.json"
assert_status 1 python3 "$validator" "$tmp/wrong-target.json" >/dev/null 2>&1
jq '.observation.profile.model = "unknown"' "$manifest" >"$tmp/wrong-profile.json"
assert_status 1 python3 "$validator" "$tmp/wrong-profile.json" >/dev/null 2>&1
jq '.obligations[0].evidence[0] = "docs/not-real.md"' "$manifest" \
  >"$tmp/missing-evidence.json"
assert_status 1 python3 "$validator" "$tmp/missing-evidence.json" >/dev/null 2>&1
jq 'del(.required_non_guarantees[0])' "$manifest" >"$tmp/missing-boundary.json"
assert_status 1 python3 "$validator" "$tmp/missing-boundary.json" >/dev/null 2>&1

cp -R evaluation/language-model-benchmark/observation.v1 "$tmp/corrupt-observation"
printf '\n' >>"$tmp/corrupt-observation/answers.jsonl"
assert_status 1 python3 "$validator" "$manifest" \
  --observation "$tmp/corrupt-observation" >/dev/null 2>&1

sh scripts/test-agent-harness.sh
sh scripts/test-evaluation-metrics.sh
sh scripts/test-language-model-observation.sh
sh scripts/test-m2-soundness-gate.sh

printf 'Terminal text-only Agent reliability gate: passed\n'
