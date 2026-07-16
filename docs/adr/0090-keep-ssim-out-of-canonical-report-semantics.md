# Keep SSIM and MS-SSIM out of canonical report semantics

## Context

SSIM is a mature full-reference image-quality metric, and MS-SSIM extends it across a downsampled scale pyramid. Both produce compact structural similarity values that may be useful while inspecting raster behavior. Neither algorithm was designed to explain SVG source semantics, subject correspondence, changed properties, regions, or causes.

The original SSIM guidance makes scale depend on image resolution and viewing distance. The standard five-level MS-SSIM configuration cannot run directly on the current 16×16 canonical corpus raster while retaining its 11×11 local window. A versioned evaluation therefore compared canonical SSIM with SSIM and MS-SSIM on a separately identified 16× enlarged QA raster.

Across thirteen cases, the absolute canonical-versus-enlarged SSIM difference reached `0.9779354872328625`. A `high` embedded-raster change received exact identity because the raster source lacks that renderer capability. One unsupported-path MS-SSIM product was unavailable due to a non-positive component. Human-tier pair ordering contained inversions and ties under every score: canonical SSIM was concordant for `39/59` different-tier pairs, enlarged SSIM for `42/59`, and MS-SSIM for `34/50` measured pairs.

## Decision

Accept SSIM and MS-SSIM only as optional QA-only secondary structural observations under a complete versioned diagnostic profile.

Every result must identify its raster source, renderer-conformance context, opaque compositing background, grayscale conversion, dynamic range, local window, constants, pooling, output scale, scale-pyramid downsampling, weights, source hashes, and unavailable-component behavior. Renderer gaps remain authoritative and can make the score uninterpretable.

Do not add SSIM or MS-SSIM to Structured Report, Difference Magnitude, Comparison Profile, equality, completeness, same-domain ordering, Impact Assessment, Agent tasks, benchmark acceptance, or release gates. Do not derive severity labels or human-importance order from these scores. Global values do not localize or attribute a change.

Any future proposal for canonical integration is a new decision. It must begin with an Agent task not answered by existing raw raster, DeltaEOK, FLIP, region, and causal evidence, and it must provide a canonical-scale interpretation plus complete renderer coverage without using alternate-scale QA as product evidence.

## Consequences

Developers have a deterministic experiment for investigating structural raster drift and scale sensitivity without expanding the public product contract. Exact equivalent pairs guard the implementation identity property, while guarded cases demonstrate that metric identity cannot override coverage.

Schema `1.43`, module version `0.5.23`, `event_rendered_pareto/v1`, canonical report bytes, and public interfaces remain unchanged. The complete evidence and reproduction procedure live in the [SSIM diagnostics evaluation](../../evaluation/ssim-diagnostics/README.md).
