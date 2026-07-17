#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"

python3 evaluation/cache-investigation/validate.py
python3 -m json.tool evaluation/cache-investigation/candidates.v1.json >/dev/null
