# Own Source Semantics as a workspace module

Status: superseded by [ADR 0026](0026-adopt-milky-xml-for-authored-parsing.md)

Strict authored parsing and Source Span provenance will be implemented by the separate workspace module `Milky2018/svgdiff_source_semantics`, with the main comparison module consuming only its document and diagnostic interface. `moonbit-community/XMLParser@0.2.5` preserved useful DOM values but accepted trailing input, mismatched tags, and duplicate attributes and exposed no per-node spans; owning the smallest failing source layer keeps those correctness guarantees local without coupling rendering or computed SVG semantics to a custom XML representation.
