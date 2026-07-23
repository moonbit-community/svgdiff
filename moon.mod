// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "Milky2018/svgdiff"

version = "0.7.0"

readme = "PACKAGE.mbt.md"

license = "Apache-2.0"

keywords = [ "svg", "diff", "visual-semantics", "structured-report", "agent" ]

preferred_target = "native"

description = "Deterministic visual-semantic SVG comparison with typed reports for programs and text-only agents."

import {
  "moonbitlang/async@0.19.1",
  "mizchi/pixelmatch@0.6.1",
  "Milky2018/xml@0.4.0",
  "moonbitlang/x@0.4.40",
  "moonbitlang/quickcheck@0.14.0",
  "Milky2018/svgdiff-raster-codec@0.1.1",
  "Milky2018/svg@0.3.1",
  "moonbit-community/miniio@0.2.1",
}

options(
  exclude: [
    "cmd/svgdiff",
    "cmd/svgdiff_wasm",
    "completions",
    "docs",
    "evaluation",
    "issues",
    "schema",
    "scripts",
    "testdata",
    "web",
  ],
)
