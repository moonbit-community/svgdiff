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

Missing positional operands never imply stdin. The command reads the complete stream before comparison; Phase 11 input limits and cancellation remain future work.

## Outputs

| Condition | stdout | stderr |
| --- | --- | --- |
| Default comparison | One canonical Structured Report JSON document followed by a newline | Empty on success |
| `--output report.json` | Empty | Empty on success; JSON is written to the selected file |
| `--html report.html` | Unchanged from the JSON rule | Empty on success; HTML is written independently |
| `--help` or `--version` | Requested informational text | Empty |
| Invalid argument or I/O failure | Empty | Human-readable error |
| Analysis status `failed` | A parseable failed Structured Report unless `--output` is used | Empty unless a separate I/O error occurs |

The exit statuses associated with these outcomes are summarized in [`analysis-status.md`](analysis-status.md). A later exit-code stabilization item may version their consumer policy, but it must preserve the stdout/stderr separation above.

## Rationale

Machine callers can safely parse stdout as JSON for every comparison invocation that does not select `--output`. Explicit stdin avoids accidental blocking when arguments are missing. Rejecting two stream operands keeps the interface simple and leaves any future framed multi-document protocol as a separate decision.
