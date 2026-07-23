# Structured Report compatibility

Schema `2.0` is the sole retained product JSON contract. This repository does
not ship legacy schemas, canonical legacy examples, or migration wrappers.

The compatibility gate verifies that:

- the registry contains exactly the current Schema `2.0`;
- its canonical examples validate;
- the current producer emits `2.0`;
- an unknown schema is rejected before fields are interpreted.

Run:

```sh
sh scripts/test-compatibility.sh
```

The project validator implements only the JSON Schema vocabulary used by the
current checked-in contract; it is not a general-purpose JSON Schema
implementation.
