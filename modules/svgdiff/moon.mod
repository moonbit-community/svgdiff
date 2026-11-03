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

version = "0.10.6"

readme = "README.mbt.md"

license = "Apache-2.0"

repository = "https://github.com/Milky2018/svgdiff"

keywords = [ "svg", "diff", "visual-semantics", "structured-report", "agent" ]

preferred_target = "wasm"

description = "Deterministic visual-semantic SVG comparison with typed reports for programs and text-only agents."

import {
  "moonbitlang/async@0.22.7",
  "Milky2018/svgdiff-pixelmatch@0.1.0",
  "Milky2018/xml@0.6.1",
  "moonbitlang/x@0.5.7",
  "Milky2018/svgdiff-raster-codec@0.1.3",
  "Milky2018/svg@0.6.1",
}
