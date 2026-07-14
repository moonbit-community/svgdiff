# CLI Exit-Code Contract

Status: stable command contract

Last verified: 2026-07-14

The exit status says whether `svgdiff` delivered a usable comparison report, a failed-analysis report, or no report. It does not rank the visual importance of any difference.

| Exit status | Meaning | Structured Report available |
| ---: | --- | --- |
| `0` | A `complete` or `partial` report was produced, or an informational command completed. | Yes for comparison invocations; no for `--help` and `--version` |
| `1` | Analysis produced a Structured Report with `analysis_status: "failed"`. | Yes |
| `2` | Invalid arguments or input/output I/O prevented the requested report from being produced or delivered. | No reliable report output |

## Outcome mapping

| Outcome | Exit status | Required caller action |
| --- | ---: | --- |
| `analysis_status: "complete"` | `0` | Interpret the report within its Comparison Profile and support contract. |
| `analysis_status: "partial"` | `0` | Retain supported evidence, surface Diagnostics, and do not claim equality. |
| `analysis_status: "failed"` | `1` | Parse the report, surface Diagnostics, and stop semantic interpretation. |
| Missing or invalid arguments | `2` | Read stderr and correct the invocation. |
| Input read failure | `2` | Read stderr; no report was produced. |
| JSON or HTML output write failure | `2` | Read stderr; treat any requested output artifact as unavailable. |
| `--help` or `--version` | `0` | Consume informational stdout; no report is expected. |

Status `0` does not imply equality. A complete report can contain large differences, and a partial report can contain no Atomic Differences while still prohibiting an equality conclusion. The report's `analysis_status`, Diagnostics, and evidence remain authoritative.

The output-channel rules are defined in [`cli-io.md`](cli-io.md). The semantic guarantees of each analysis status are defined in [`analysis-status.md`](analysis-status.md).
