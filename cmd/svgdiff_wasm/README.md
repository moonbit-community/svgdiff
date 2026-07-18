# svgdiff WebAssembly entry

`cmd/svgdiff_wasm` is the no-I/O browser entry for the core SVG comparison
library. Build it with:

```sh
moon build cmd/svgdiff_wasm --target wasm --release
```

The module exports `memory`, `abi_version`, `transfer_ptr`,
`transfer_capacity`, `compare`, `result_len`, `result_error_kind`, and
`result_required_len`.

Write one UTF-8 JSON request into `memory` at `transfer_ptr()`, call
`compare(requestLength)`, then read `result_len()` bytes from the same address.
Status `0` returns a compact Structured Report JSON document. Status `1`
returns a UTF-8 host-request error and exposes its numeric kind through
`result_error_kind()`.

ABI version 1 accepts:

```json
{
  "version": 1,
  "before_svg": "<svg>...</svg>",
  "after_svg": "<svg>...</svg>",
  "viewport_width": 800,
  "viewport_height": 600
}
```

Viewport fields are optional and default to 16. Unknown fields are rejected.
The entry accepts no paths, URLs, files, network handles, or ambient browser
state. Explicit resource bundles and perceptual-profile options are not part of
ABI version 1.
