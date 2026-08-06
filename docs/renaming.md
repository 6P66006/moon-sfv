# Renaming guide

The module currently uses the temporary local namespace `localdev/moon-sfv`
in `moon.mod`:

```toml
name = "localdev/moon-sfv"
```

This is a placeholder that avoids attaching any real identity to the
project before a final maintainer/namespace is decided. **It must not be
published with the placeholder name.** Once a final identity is chosen,
replace `localdev/moon-sfv` everywhere it appears.

## Files that reference the module name

The name appears in two kinds of places:

1. **`moon.mod`** — the module declaration itself.
2. **Package dependency declarations** — every `moon.pkg` that imports the
   library:
   - `cmd/sfv-tool/moon.pkg`
   - `examples/parse_item/moon.pkg`
   - `examples/parse_list/moon.pkg`
   - `examples/parse_dictionary/moon.pkg`
   - `examples/canonicalize/moon.pkg`

   Each contains a line of the form:
   ```
   import {
     "localdev/moon-sfv" @lib,
   }
   ```
   The alias `@lib` can stay the same.

3. **Documentation** — `README.md`, `docs/*.md`, and `THIRD_PARTY_NOTICES.md`
   mention the package name in prose. Update these for consistency.

## What to change

Replace the string `localdev/moon-sfv` with the final name, e.g.
`owner/moon-sfv`, in:

- `moon.mod`
- `cmd/sfv-tool/moon.pkg`
- `examples/parse_item/moon.pkg`
- `examples/parse_list/moon.pkg`
- `examples/parse_dictionary/moon.pkg`
- `examples/canonicalize/moon.pkg`
- `README.md`
- `docs/architecture.md`
- `docs/testing.md`

A simple find-and-replace across the repository is sufficient. After
renaming:

1. Run `moon clean && moon check && moon test` for each target to confirm
   the resolution still works.
2. Run `scripts/verify_httpwg_snapshot.py` (it does not embed the module
   name, but re-verify anyway).

## What NOT to change

- **Do not** edit the generated files `httpwg_conformance_data*.mbt` —
  they are produced by `scripts/import_httpwg_tests.py` and do not contain
  the module name.
- **Do not** edit `testdata/httpwg/SOURCE.json` — its provenance fields
  describe the upstream repository, not this project.
- **Do not** set `repository` in `moon.mod` or add author/email fields in
  this phase.

This phase intentionally keeps the placeholder; perform the rename only when
the final identity is decided.
