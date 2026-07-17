#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/svgdiff-language-model-observation-test.XXXXXX")
trap 'rm -rf "$tmp"' EXIT

cd "$root"
observation=evaluation/language-model-benchmark/observation.v1
python3 evaluation/language-model-benchmark/validate_observation.py "$observation"

cp -R "$observation" "$tmp/integrity"
printf '\n' >>"$tmp/integrity/answers.jsonl"
if python3 evaluation/language-model-benchmark/validate_observation.py "$tmp/integrity" >/dev/null 2>&1; then
  printf 'expected altered answer artifact to fail integrity validation\n' >&2
  exit 1
fi

cp -R "$observation" "$tmp/checks"
jq '.checks = []' "$tmp/checks/gate.json" >"$tmp/checks/gate.changed.json"
mv "$tmp/checks/gate.changed.json" "$tmp/checks/gate.json"
if python3 evaluation/language-model-benchmark/validate_observation.py "$tmp/checks" >/dev/null 2>&1; then
  printf 'expected missing threshold decisions to fail observation validation\n' >&2
  exit 1
fi

printf 'Language-model observation: identity, thresholds, and integrity: ok\n'
