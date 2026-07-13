# XMLParser 0.2.5 Evaluation

Status: rejected as the Source Semantics correctness boundary

`moonbit-community/XMLParser@0.2.5` was evaluated as a possible structural DOM parser. It preserved the authored attribute values required to distinguish `red` from `#ff0000`, accepted single- and double-quoted values, retained namespace-qualified names such as `xlink:href`, exposed nested SVG elements and resources, and preserved entity-reference spelling in tested attribute values.

It was rejected as the project's Source Semantics dependency because its convenience parser accepted trailing input, mismatched root tags, and duplicate attributes. The lower-level parser could be wrapped to reject unconsumed trailing input, but mismatched-tag errors from the context parser were not available through public accessors, and duplicate attributes had already been collapsed into a `Map`. `XMLElement` and its attributes also carried no source spans. The README advertised `xml_from_string_with_ctx`, but that function was private in the published 0.2.5 interface.

The project therefore owns a separate workspace module for strict parsing and source provenance rather than depending on XMLParser.
