#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
manifest="$root/evaluation/browser-oracle/manifest.json"
playwright_config="$root/.playwright/cli.config.json"
playwright_version=${SVGDIFF_PLAYWRIGHT_CLI_VERSION:-0.1.17}
playwright_cli_bin=${SVGDIFF_PLAYWRIGHT_CLI_BIN:-}

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 OUTPUT_DIRECTORY" >&2
  exit 2
fi
if [ ! -f "$playwright_config" ]; then
  echo "Browser oracle config is missing: $playwright_config" >&2
  exit 2
fi
if [ -z "$playwright_cli_bin" ] && ! command -v npx >/dev/null 2>&1; then
  echo "Browser oracle requires npx from Node.js/npm" >&2
  exit 2
fi
if [ -n "$playwright_cli_bin" ]; then
  if [ ! -x "$playwright_cli_bin" ]; then
    echo "Browser oracle CLI override is not executable: $playwright_cli_bin" >&2
    exit 2
  fi
  if [ "$("$playwright_cli_bin" --version)" != "$playwright_version" ]; then
    echo "Browser oracle CLI override must be version $playwright_version" >&2
    exit 2
  fi
fi

output=$1
mkdir -p "$output"
if find "$output" -mindepth 1 -print -quit | grep -q .; then
  echo "Browser oracle output directory must be empty: $output" >&2
  exit 2
fi
output=$(CDPATH= cd -- "$output" && pwd)
work=${TMPDIR:-/tmp}/svgdiff-browser-oracle-$$
mkdir -p "$work"
records="$work/cases.jsonl"
log="$work/playwright.log"
session="svgdiff-browser-oracle-$$"

pw() {
  if [ "$1" = open ]; then
    if [ -n "$playwright_cli_bin" ]; then
      "$playwright_cli_bin" --session "$session" "$@" \
        --config "$playwright_config"
      return
    fi
    npx --yes --package "@playwright/cli@$playwright_version" \
      playwright-cli --session "$session" "$@" \
      --config "$playwright_config"
    return
  fi
  if [ -n "$playwright_cli_bin" ]; then
    "$playwright_cli_bin" --session "$session" "$@"
    return
  fi
  npx --yes --package "@playwright/cli@$playwright_version" \
    playwright-cli --session "$session" "$@"
}

cleanup() {
  exit_status=$?
  trap - EXIT INT TERM
  pw close >>"$log" 2>&1 || true
  if [ "$exit_status" -ne 0 ]; then
    tail -80 "$log" >&2 || true
  fi
  rm -rf "$work"
  exit "$exit_status"
}
trap cleanup EXIT INT TERM

cd "$root"
jq -e '
  .schema_version == "svgdiff-browser-oracle-input/1" and
  (.fixtures | length) > 0 and
  ([.fixtures[].id] | length == (unique | length)) and
  all(.fixtures[];
    (.id | type == "string" and length > 0) and
    (.source | type == "string" and length > 0) and
    (.width | type == "number" and . > 0) and
    (.height | type == "number" and . > 0)
  )
' "$manifest" >/dev/null

cd "$work"
pw open about:blank >>"$log" 2>&1
pw network-state-set offline >>"$log" 2>&1
environment=$(pw --raw run-code \
  "async (page) => await page.evaluate(() => ({ user_agent: navigator.userAgent, device_pixel_ratio: window.devicePixelRatio }))" \
  2>>"$log")
environment=$(printf '%s' "$environment" | jq -c \
  --arg engine chromium \
  --arg cli_version "$playwright_version" \
  '. + {browser_engine: $engine, playwright_cli_version: $cli_version}')

jq -c '.fixtures[]' "$manifest" | while IFS= read -r fixture; do
  id=$(printf '%s' "$fixture" | jq -r '.id')
  source=$(printf '%s' "$fixture" | jq -r '.source')
  width=$(printf '%s' "$fixture" | jq -r '.width')
  height=$(printf '%s' "$fixture" | jq -r '.height')
  case "$source" in
    /* | *..*)
      echo "Unsafe browser oracle source path: $source" >&2
      exit 2
      ;;
  esac
  if [ ! -f "$root/$source" ]; then
    echo "Missing browser oracle source: $source" >&2
    exit 2
  fi
  data=$(base64 <"$root/$source" | tr -d '\n')
  png="$output/$id.png"
  png_json=$(printf '%s' "$png" | jq -Rs .)
  pw resize "$width" "$height" >>"$log" 2>&1
  pw run-code \
    "async (page) => { await page.setContent('<style>html,body{margin:0;width:${width}px;height:${height}px;background:transparent;overflow:hidden}img{display:block;width:${width}px;height:${height}px}</style><img src=\"data:image/svg+xml;base64,$data\">'); await page.locator('img').evaluate(image => image.decode()); await page.screenshot({ path: $png_json, omitBackground: true, scale: 'css', type: 'png' }); }" \
    >>"$log" 2>&1
  source_hash=$(shasum -a 256 "$root/$source" | awk '{print $1}')
  png_hash=$(shasum -a 256 "$png" | awk '{print $1}')
  jq -n -c \
    --arg id "$id" \
    --arg source "$source" \
    --arg source_hash "$source_hash" \
    --arg png "$id.png" \
    --arg png_hash "$png_hash" \
    --argjson width "$width" \
    --argjson height "$height" \
    '{id: $id, source: $source, source_sha256: $source_hash, png: $png, png_sha256: $png_hash, width: $width, height: $height}' \
    >>"$records"
done

cases=$(jq -s . "$records")
jq -n \
  --arg schema_version "svgdiff-browser-oracle-output/1" \
  --argjson environment "$environment" \
  --argjson cases "$cases" \
  '{schema_version: $schema_version, environment: $environment, cases: $cases}' \
  >"$output/oracle-report.json"

python3 "$root/evaluation/browser-oracle/validate.py" "$output"
