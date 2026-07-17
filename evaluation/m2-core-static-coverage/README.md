# M2 Core Static Coverage Gate

`gate.v1.json` maps the nine capabilities named by the first M2 milestone gate to their admitted slice, evidence status, limiting Diagnostics, feature-coverage wording, and focused MoonBit tests.

Run:

```sh
python3 evaluation/m2-core-static-coverage/validate.py
```

The validator rejects a missing capability, missing guard for a bounded slice, stale feature-coverage marker, absent test file, or a test file without executable test blocks. It validates traceability, not the feature implementation by itself; the focused and full MoonBit suites remain required.
