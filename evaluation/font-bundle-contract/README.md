# Font Bundle Contract Vectors

Status: accepted input-contract fixtures; no font execution

Last verified: 2026-07-17

This directory makes the [`svgdiff-font-bundle/1`](../../docs/font-resource-bundle.md) identity rules executable without adding a font parser or runtime dependency.

[`vectors.v1.json`](vectors.v1.json) contains:

- one strict synthetic manifest;
- a legal/provenance-only mutation that preserves the Font Bundle Fingerprint while changing the complete manifest digest;
- a raw font-byte mutation that changes both identities;
- representative invalid mutations for version, fields, ordering, uniqueness, hashes, face ranges, license references, distribution review, limits, and encoding.

[`validate.py`](validate.py) uses only the Python standard library. Its synthetic hashes and byte lengths do not claim that the vectors contain real font binaries. Actual byte, container, face, decompression, table, glyph, variation, and embedded-content validation belongs to the future bounded loader and Font Execution Profile.

Run:

```sh
sh scripts/test-font-bundle-contract.sh
```

The test also rejects any font-bundle implementation leak into the MoonBit module, product engine, Structured Report schema, CLI, or default CI. Current `font_analysis_deferred` behavior remains authoritative.
