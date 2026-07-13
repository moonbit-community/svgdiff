# SVG Diff Source Semantics

This workspace module strictly parses the authored XML surface needed by SVG Diff while preserving element, attribute, value, and text source spans.

Its interface is deliberately independent of rendering and computed SVG semantics:

```mbt check
///|
test {
  let source = "<svg><rect fill=\"red\"/></svg>"
  let document = @svgdiff_source_semantics.parse(source).unwrap()
  let rect = document.elements_named("rect")[0]
  assert_eq(rect.attribute("fill").unwrap().value, "red")
}
```
