# Compatibility and Versioning Contract

Status: current release contract

Last verified: 2026-07-14

`svgdiff` has several independently versioned compatibility domains. A release must change every identity whose contract changed, but must not increment unrelated identities merely to keep their numbers visually aligned.

## Version domains

| Domain | Current identity | Authority | What it versions |
| --- | --- | --- | --- |
| MoonBit module and CLI | `0.3.1` | `moon.mod` | Public MoonBit declarations, root-package behavior, CLI syntax, stream behavior, and exit statuses. |
| Structured Report | `1.3` | `schema/svgdiff-report.schema.json` and public report types | Serialized fields, value meanings, requiredness, units, references, and interpretation rules. |
| Diagnostics | Schema `1.3` plus each stable `Diagnostic.code` | `docs/feature-coverage.md`, public report types, and producer tests | Machine-readable limitation or failure meanings, source locations, and the evidence layers they constrain. |
| Same-domain ordering | `v1_domain_lexicographic` | emitted `DomainOrdering.policy_id` and its tests | Component construction, order, direction, null behavior, and tie-breaking. |
| Renderer conformance | `svgdiff-renderer-conformance-profile/1` | comparison profile and renderer-conformance artifacts | Accepted fixtures, divergences, guards, tolerances, and Rendered Evidence claims. |

The renderer package identity and raster representation are also report semantics, but their upgrade rules are already defined in [Component Upgrade Procedures](upgrade-procedures.md). They are not aliases for any version above.

## MoonBit module SemVer

The module version follows SemVer. While the module is below `1.0.0`, this project uses a stricter policy than “anything may change”:

- `0.MINOR.0` may contain a source- or behavior-incompatible public change;
- `0.MINOR.PATCH` contains only backward-compatible fixes and additions within that minor line;
- deprecation should precede removal when a usable migration path exists.

At and after `1.0.0`:

- MAJOR changes may break public source compatibility or documented behavior;
- MINOR changes add backward-compatible public operations or capabilities;
- PATCH changes fix defects without invalidating conforming callers.

Adding a function is compatible. Removing or renaming a public declaration, changing parameters or results, adding a required field to a publicly constructible record, or changing documented behavior incompatibly is breaking. The generated root `pkg.generated.mbti` is the review artifact. The CLI executable and `engine:` line use the module version; they are not separately released products today.

## Structured Report schema versions

`schema_version` uses `MAJOR.MINOR`, not the module SemVer.

- Increment MINOR for a backward-readable addition whose absence has explicit old behavior, such as a new optional field. New producers emit the new minor identity even when tolerant older consumers could safely ignore the field.
- Increment MAJOR when an old consumer could reject the report or misinterpret it: required-field changes, removal or rename, type or unit changes, changed null/absence meaning, identifier-reference changes, closed-enum additions, or any reuse of an existing field for new semantics.
- Do not change the version for prose clarification, formatting, or a validator correction that provably changes neither the set nor the meaning of conforming reports. Any ambiguous correction receives a new version.

The optional fields historically added while schema `1.0` was being established remain part of `1.0`; this rule applies to changes after this contract was accepted. Consumers must reject unknown schema identities before semantic interpretation unless an explicit compatibility policy and migration test accepts them. “Additive” describes migration risk, not permission to silently retain an old producer identity.

Every released schema identity has one entry in the [released Schema registry](../schema/registry.v1.json), a checked-in Schema, canonical examples, compatibility fixtures, and an explicit accept, migrate, or reject decision. Module and schema versions move independently: a new library helper need not change the report schema, while a schema change requires the appropriate module release but does not copy the module version number.

## Diagnostic compatibility

`Diagnostic.code` is the stable machine-readable discriminator. `Diagnostic.id` is a report-local reference that may include a subject or property and must not be used as a cross-release discriminator.

Consumers must preserve and surface unknown codes, use `affected_evidence_layers` and the coverage matrix for safety, and must not treat an unknown code as success. Producers follow these allocation rules:

- adding a code for a newly recognized condition is additive and requires at least a schema MINOR plus a compatible module release;
- removing a code because the condition is now fully supported is behavior-additive, but still requires a schema MINOR so consumers can review changed coverage outcomes;
- renaming a code, reusing it for another condition, changing which evidence it constrains, or weakening/strengthening its conclusion in a way that can change consumer interpretation is schema MAJOR and module-breaking;
- changing only report-local `Diagnostic.id` construction is not a code rename, but must preserve all in-report references and deterministic output.

Diagnostic strings deliberately remain open rather than a JSON Schema enum so an older safety-oriented consumer can surface an unknown limitation. The feature coverage matrix is the current catalog; a code is not stable until it has direct producer and report-level regression coverage.

## Ranking-policy compatibility

`DomainOrdering.policy_id` is an opaque compatibility identity, not a number consumers should parse. Any change to component membership, component order, direction, normalization, units, missing-value behavior, or deterministic tie-breaking allocates a new ID.

Tuples with different policy IDs are incomparable. Consumers must reject or explicitly migrate an unknown policy before ranking, and must never fall back to comparing its raw component array. Adding a second policy is compatible; changing the default emitted policy is a module-breaking behavior change even though the JSON shape is unchanged. The report schema changes only when the serialized ordering shape or field meaning changes.

## Release review matrix

| Change | Module | Schema | Diagnostic code | Ordering policy | Conformance profile |
| --- | --- | --- | --- | --- | --- |
| Backward-compatible public helper | MINOR, or pre-1.0 PATCH | Same | Same | Same | Same |
| Breaking public API or CLI behavior | MAJOR, or pre-1.0 MINOR | Same unless report meaning changed | Review | Review | Review |
| Optional report field added | Compatible module release | MINOR | Same | Same | Same |
| Required/type/unit/report-meaning change | Breaking module release | MAJOR | Review | Review | Review |
| New or retired Diagnostic condition | Compatible module release | MINOR | Add or retire without reuse | Same unless ranking changed | Review if renderer claim changed |
| Diagnostic rename or semantic reuse | Breaking module release | MAJOR | Allocate a new code; do not reuse | Review | Review |
| Ordering tuple semantics change | Breaking module release if it becomes the default | Same unless shape changed | Same | New ID | Same |
| Renderer fixture, disposition, guard, tolerance, or accepted claim changes | Compatible or breaking according to behavior | Same unless report meaning changed | Review | Same unless magnitude ordering changed | New profile ID |

“Review” means determine the result from the domain rules; it does not mean increment automatically. Before release, run `sh scripts/test-versioning.sh`, `sh scripts/test-release-bundle.sh`, the compatibility corpus, `moon info`, and the full validation gate in the upgrade procedures.
