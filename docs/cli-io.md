# CLI Input and Output Contract

Status: current command contract

Last verified: 2026-07-16

## Inputs

`svgdiff` requires two positional SVG operands. A path reads a UTF-8 file. `-` reads one complete UTF-8 SVG document from stdin.

| Invocation shape | Meaning |
| --- | --- |
| `svgdiff before.svg after.svg` | Read both inputs from files. |
| `cat before.svg \| svgdiff - after.svg` | Read the before SVG from stdin. |
| `cat after.svg \| svgdiff before.svg -` | Read the after SVG from stdin. |
| `svgdiff - -` | Invalid: one stdin stream cannot supply two independently bounded documents. |
| `svgdiff before.svg after.svg --before-resource asset.png image/png before.png --after-resource asset.png image/png after.png` | Supply exact-match bytes for `asset.png` independently on each side. |
| `svgdiff before.svg after.svg --perceptual-background white` | Record one normalized opaque sRGB8 Perceptual Background without changing current transparent-canvas raw evidence. |

Missing positional operands never imply stdin. Resource options are repeatable `LOCATOR MEDIA_TYPE FILE` triplets; their file operand may not be `-`. The CLI reads only those explicitly named resource files, and the engine treats each locator as an opaque key rather than opening it as a path. `--perceptual-background COLOR` accepts only deterministic resolved opaque sRGB colors; contextual, system, invalid, and translucent values are rejected before comparison. The command reads the complete SVG stream and explicit resource files before comparison, then the engine applies the fixed source and bundle budgets before XML or image analysis. This bounds comparison work but not the CLI's initial file-read allocation; streaming admission and CLI cancellation remain future work. Cooperative controls are available only to callers of the MoonBit library.

## Outputs

| Condition | stdout | stderr |
| --- | --- | --- |
| Default comparison | One canonical Structured Report JSON document followed by a newline | Empty on success |
| `--output report.json` | Empty | Empty on success; JSON is written to the selected file |
| `--html report.html` | Unchanged from the JSON rule | Empty on success; HTML is written independently |
| `--help` or `--version` | Requested informational text | Empty |
| Invalid argument or I/O failure | Empty | Human-readable error |
| Analysis status `failed` | A parseable failed Structured Report unless `--output` is used | Empty unless a separate I/O error occurs |

The stable exit statuses associated with these outcomes are defined in [`cli-exit-codes.md`](cli-exit-codes.md). They preserve the stdout/stderr separation above.

## Rationale

Machine callers can safely parse stdout as JSON for every comparison invocation that does not select `--output`. Explicit stdin avoids accidental blocking when arguments are missing. Rejecting two stream operands keeps the interface simple and leaves any future framed multi-document protocol as a separate decision.
