# CLI Input and Output Contract

Status: current command contract

Last verified: 2026-07-14

## Inputs

`svgdiff` requires two positional SVG operands. A path reads a UTF-8 file. `-` reads one complete UTF-8 SVG document from stdin.

| Invocation shape | Meaning |
| --- | --- |
| `svgdiff before.svg after.svg` | Read both inputs from files. |
| `cat before.svg \| svgdiff - after.svg` | Read the before SVG from stdin. |
| `cat after.svg \| svgdiff before.svg -` | Read the after SVG from stdin. |
| `svgdiff - -` | Invalid: one stdin stream cannot supply two independently bounded documents. |

Missing positional operands never imply stdin. The command reads the complete stream before comparison, then the engine applies the fixed per-source UTF-8 budget before XML parsing. This bounds comparison work but not the CLI's initial file-read allocation; streaming admission and CLI cancellation remain future work. Cooperative controls are available only to callers of the MoonBit library.

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
