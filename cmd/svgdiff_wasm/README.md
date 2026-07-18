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
  "viewport_height": 600,
  "perceptual_background": "#ffffff",
  "flip_pixels_per_degree": 60,
  "flip_error_threshold": 0.05,
  "max_checkpoints": 1000000
}
```

Every field shown above is required. `perceptual_background` may instead be
`null`; `flip_pixels_per_degree` and `flip_error_threshold` must then also be
`null`. A background may be supplied without FLIP, but FLIP requires a
background and a threshold requires FLIP Viewing Conditions. Colors use the
same opaque deterministic sRGB parser as the public MoonBit interface; PPD is
bounded to `[1, 4096]` and the threshold to `[0, 1]`. `max_checkpoints` must be
positive and applies the core engine's deterministic work budget; exhaustion
returns host error kind `7` and no partial report.

This is the only accepted ABI version 1 request shape. The earlier request
shape with optional viewport fields and no perceptual-profile fields was
removed without a compatibility path. Unknown or missing fields are rejected.
The entry accepts no paths, URLs, files, network handles, resource bundles, or
ambient browser state.
