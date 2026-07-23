#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

if [ "$#" -ne 1 ]; then
  printf 'Usage: %s TAG\n' "$0" >&2
  exit 2
fi

module_version=$(awk -F '"' '$1 ~ /^version = / { print $2; exit }' "$root/modules/svgdiff/moon.mod")
expected_tag="v$module_version"
if [ "$1" != "$expected_tag" ]; then
  printf 'Release tag %s does not match module version %s; expected %s\n' \
    "$1" "$module_version" "$expected_tag" >&2
  exit 1
fi

printf 'Release tag matches module version: %s\n' "$expected_tag"
