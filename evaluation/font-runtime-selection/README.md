# Font Runtime Dependency Selection Evidence

Status: accepted dependency decision; no product runtime

Last verified: 2026-07-17

This directory records the exact source/build selection and one disposable native feasibility probe for [the font runtime dependency contract](../../docs/font-runtime-dependencies.md).

The probe SHA-verified the official HarfBuzz 14.2.1 and FreeType 2.14.3 release archives, built static libraries, and linked them into a throwaway MoonBit native module. Caller-owned bytes were opened independently by both libraries; an explicit OpenType run was shaped, an outline was inspected, and a normal grayscale glyph mask was produced for both a single-face font and collection face 1. The linked MoonBit library resolved no dynamic HarfBuzz or FreeType.

The throwaway source and local fonts are not checked in. [`results.v1.json`](results.v1.json) retains their hashes, exact host/build identities, decoded observations, and the narrower conclusion. This proves source-build and FFI feasibility only; it does not establish malformed-font safety, script coverage, conformance, repeatability across builds or targets, or accepted product behavior.

Run the dependency-free evidence validator with:

```sh
sh scripts/test-font-runtime-selection.sh
```

The gate also proves that no selected dependency, prototype, module, public API, Structured Report field, or default CI step has leaked into the current product.
