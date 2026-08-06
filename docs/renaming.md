# Renaming record

This document records how the module was renamed from the temporary local
namespace `localdev/moon-sfv` to the final namespace `6P66006/moon-sfv`.

## Status: DONE

On 2026-08-04 the module namespace was changed to:

```toml
name = "6P66006/moon-sfv"
```

This is the final namespace and should be used when publishing to Mooncakes.
The temporary `localdev/moon-sfv` placeholder no longer appears anywhere in
the repository.

## What was changed

The string `localdev/moon-sfv` was replaced with `6P66006/moon-sfv` in:

- `moon.mod`
- `cmd/sfv-tool/moon.pkg`
- `examples/parse_item/moon.pkg`
- `examples/parse_list/moon.pkg`
- `examples/parse_dictionary/moon.pkg`
- `examples/canonicalize/moon.pkg`
- `examples/errors/moon.pkg`
- `README.md`
- `docs/architecture.md`
- `CONTRIBUTING.md`

The import alias `@lib` in the `moon.pkg` files is unchanged.

## What was NOT changed

- The generated files `httpwg_conformance_data*.mbt` — they are produced by
  `scripts/import_httpwg_tests.py` and do not embed the module name.
- `testdata/httpwg/SOURCE.json` — its provenance fields describe the
  upstream repository, not this project.

## Verification after the rename

- `moon clean`
- `moon check` and `moon test` on `wasm-gc`, `js`, and `native` — all pass
  (117 tests each, 0 errors, 0 warnings).
- `moon fmt --check` passes.
- `scripts/verify_httpwg_snapshot.py` passes.

## If the namespace needs to change again in the future

The same procedure applies: replace `6P66006/moon-sfv` in the files listed
above, verify with the three targets, and re-run the snapshot check.
