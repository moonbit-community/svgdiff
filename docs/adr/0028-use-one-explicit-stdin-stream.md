# Use one explicit stdin stream

`svgdiff` will interpret `-` as stdin for either the before or after SVG, but never both in one invocation. A single undelimited byte stream cannot represent two complete SVG documents without adding a second framing protocol, so `svgdiff - -` is an invalid argument rather than an ambiguous concatenation convention.

JSON is written to stdout only when no `--output` file is selected. Help and version are also intentional stdout products. Argument errors, input failures, and output failures use stderr so a caller never receives prose mixed into a JSON stream. Missing positional arguments do not imply stdin; stream input must remain explicit.
