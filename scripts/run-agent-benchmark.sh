#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
manifest="$root/evaluation/corpus/manifest.json"
thresholds="$root/evaluation/benchmark-thresholds.v1.json"
agent="python3 evaluation/harness/evidence_test_agent.py"
output=""
invocation_dir=$(pwd)

usage() {
  printf 'Usage: %s --output DIR [--agent COMMAND] [--thresholds FILE]\n' "$0"
}

while [ "$#" -gt 0 ]; do
  if [ "$#" -lt 2 ]; then
    usage >&2
    exit 2
  fi
  case "$1" in
    --output)
      output=$2
      shift 2
      ;;
    --agent)
      agent=$2
      shift 2
      ;;
    --thresholds)
      thresholds=$2
      shift 2
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
done

if [ -z "$output" ]; then
  usage >&2
  exit 2
fi
case "$output" in
  /*) ;;
  *) output="$invocation_dir/$output" ;;
esac
case "$thresholds" in
  /*) ;;
  *) thresholds="$invocation_dir/$thresholds" ;;
esac
if [ -e "$output" ] && [ -n "$(find "$output" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]; then
  printf 'Benchmark output directory must be empty: %s\n' "$output" >&2
  exit 2
fi

reports="$output/reports"
tasks="$output/tasks.jsonl"
answers="$output/answers.jsonl"
metrics="$output/metrics.json"
gate="$output/gate.json"
mkdir -p "$reports"

cd "$root"
jq -c '.cases[]' "$manifest" | while IFS= read -r case_json; do
  id=$(printf '%s' "$case_json" | jq -r '.id')
  before=$(printf '%s' "$case_json" | jq -r '.before')
  after=$(printf '%s' "$case_json" | jq -r '.after')
  width=$(printf '%s' "$case_json" | jq -r '.viewport.width')
  height=$(printf '%s' "$case_json" | jq -r '.viewport.height')
  moon run --target native cmd/svgdiff -- \
    "$root/evaluation/corpus/$before" \
    "$root/evaluation/corpus/$after" \
    --width "$width" --height "$height" >"$reports/$id.json"
done

python3 evaluation/harness/harness.py prepare --reports "$reports" --output "$tasks"
python3 evaluation/harness/harness.py run \
  --tasks "$tasks" --output "$answers" --agent "$agent"
python3 evaluation/harness/score.py \
  --tasks "$tasks" --answers "$answers" --output "$metrics"
python3 evaluation/harness/check_thresholds.py \
  --metrics "$metrics" --thresholds "$thresholds" --output "$gate"

jq '{metrics_version, case_count, aggregate}' "$metrics"
printf 'Benchmark thresholds: passed (%s)\n' "$gate"
