# Deliver a self-contained HTML report

Each comparison will produce a self-contained HTML Diff Report with the complete Structured Report embedded and available in an expandable JSON view. This gives humans an interactive visual comparison and gives non-multimodal agents stable machine-readable evidence without requiring separate artifacts, a running server, or two independently generated representations of the result.

The report is a presentation over the supplied Structured Report, not a second comparison implementation. It displays the exact analysis and Impact Assessment status, every Atomic Difference grouped by full domain, non-null magnitude evidence, linked Visual Events and Difference Regions, conservative Cause Envelope candidates, linked Diagnostics, and the complete JSON. It must not derive severity, visibility, equality, total ordering, or unique causality.

Both original SVG sources render only in empty-sandbox `srcdoc` iframes with a fixed `default-src 'none'` policy. Report-controlled top-level values are inserted through DOM construction and `textContent`. Hover and keyboard focus provide temporary region overlays; an explicit Locate control provides persistent selection. Review checkboxes remain independent from region selection. Empty, partial, failed, tied, incomparable, and unavailable-measurement states must be stated explicitly.
