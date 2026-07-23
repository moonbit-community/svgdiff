# Reproducible Generative Fuzzing

Status: production-boundary fuzz smoke

Last verified: 2026-07-14

The current MoonBit `moon test` command has no coverage-guided fuzz mode. This suite therefore performs deterministic generative fuzzing through the native release CLI. It is not a substitute for libFuzzer, AFL, sanitizer-guided exploration, or future MoonBit coverage-guided fuzz support.

Each seed produces four interleaved case families:

- supported basic-shape pairs that must reach parsing, semantic adaptation, rendering, report assembly, JSON serialization, and HTML generation with complete coverage;
- limited path or guarded skew-transform pairs that must retain a valid partial report;
- malformed XML that must produce a Schema-valid failed report rather than crash or corrupt output;
- well-formed SVG containing hostile `textarea`, `iframe`, and `script` boundary text inside comments, which must remain escaped inside two sandboxed previews and one JSON textarea.

Every result records the seed, case index, category, analysis status, and SHA-256 hashes of the inputs, compact report, and HTML. The smoke gate runs the same seed twice and compares the complete result manifests byte for byte.

Run the bounded smoke gate:

```sh
sh scripts/test-fuzz-smoke.sh
```

Scale exploration with another seed and case count:

```sh
moon build --target native --release modules/svgdiff/cmd/svgdiff
python3 evaluation/fuzz/run.py \
  --cli _build/native/release/build/Milky2018/svgdiff/cmd/svgdiff/svgdiff.exe \
  --seed 123456 --cases 1000 --output /tmp/svgdiff-fuzz.json
```

Replay one failure exactly with the seed, configured count, and case index printed in its ID:

```sh
python3 evaluation/fuzz/run.py \
  --cli _build/native/release/build/Milky2018/svgdiff/cmd/svgdiff/svgdiff.exe \
  --seed 123456 --cases 1000 --case-index 217 \
  --output /tmp/svgdiff-fuzz-case-217.json
```

The runner intentionally makes no resource-budget claim. Input-byte, element-count, recursion, reference-expansion, raster-size, region-count, report-size, memory, and time limits remain separate roadmap work.
