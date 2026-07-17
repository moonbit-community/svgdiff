#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"

python3 evaluation/m2-core-static-coverage/validate.py
python3 -m json.tool evaluation/m2-core-static-coverage/gate.v1.json >/dev/null
