#!/usr/bin/env python3

import copy
import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from evaluation.schema_validation import audit_schema, validate_instance


schema = json.loads(
    (ROOT / "schema/svgdiff-source-audit.schema.json").read_text(encoding="utf-8")
)
example = json.loads(
    (ROOT / "schema/examples/nonvisual-source-audit.json").read_text(
        encoding="utf-8"
    )
)

audit_schema(schema)
validate_instance(example, schema, schema)

invalid = copy.deepcopy(example)
del invalid["differences"][0]["before"]["source_span"]
try:
    validate_instance(invalid, schema, schema)
except ValueError:
    pass
else:
    raise ValueError("source-audit schema accepted a fact without provenance")

print("Source audit schema: example accepted, missing provenance rejected")
