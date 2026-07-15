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

version = "0.5.4"

readme = "PACKAGE.mbt.md"

license = "Apache-2.0"

keywords = [ "svg", "diff", "visual-semantics", "structured-report", "agent" ]

preferred_target = "native"

description = "Deterministic visual-semantic SVG comparison with typed reports for programs and text-only agents."

import {
  "moonbitlang/async@0.19.1",
  "mizchi/svg@0.2.1",
  "mizchi/pixelmatch@0.6.1",
  "Milky2018/xml@0.4.0",
  "moonbitlang/x@0.4.40",
  "moonbitlang/quickcheck@0.14.0",
  "Milky2018/svgdiff-raster-codec@0.1.0",
}

options(
  exclude: [
    ".github",
    "cmd",
    "completions",
    "docs",
    "evaluation",
    "issues",
    "prototype",
    "release",
    "schema",
    "scripts",
    "testdata",
    "modules",
    "moon.work",
    "AGENTS.md",
    "CONTEXT.md",
    "README.md",
    "README.mbt.md",
    "roadmap.md",
    "*_test.mbt",
    "*_wbtest.mbt",
    "engine/README.md",
  ],
)
