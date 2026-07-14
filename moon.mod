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

version = "0.3.3"

readme = "README.mbt.md"

repository = ""

license = "Apache-2.0"

keywords = [ ]

preferred_target = "native"

description = ""

import {
  "moonbitlang/async@0.19.1",
  "mizchi/svg@0.2.1",
  "mizchi/pixelmatch@0.6.1",
  "Milky2018/xml@0.4.0",
  "moonbitlang/x@0.4.40",
  "moonbitlang/quickcheck@0.14.0",
}
