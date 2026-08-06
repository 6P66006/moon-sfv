# Contributing

Thank you for considering contributing to `moon-sfv`.

## Scope

This project implements RFC 9651 (Structured Field Values for HTTP) for
MoonBit. Contributions should stay within that scope:

- parser, serializer, and canonicalization correctness;
- conformance tooling against the official HTTP Working Group vectors;
- documentation and tests.

## Ground rules

- The only normative references are RFC 9651, its erratum list, and the
  httpwg `structured-field-tests` repository. Do not port or adapt parsing
  or serialization code from other language implementations.
- Never introduce floating point into `SfDecimal`'s value representation.
- Every public behavior change must come with tests. All three targets
  (`native`, `js`, `wasm-gc`) must stay at 0 errors and 0 warnings.
- The module namespace is `6P66006/moon-sfv`; keep it consistent across
  `moon.mod` and the `moon.pkg` files that import it (see
  `docs/renaming.md`).

## Development workflow

1. Make changes and add tests in `*_test.mbt` files.
2. Format and check:
   ```powershell
   moon fmt
   moon check --target native
   moon test --target native
   ```
3. Run the full suite: `powershell -ExecutionPolicy Bypass -File
   scripts/verify_all.ps1`.
4. If you changed how test vectors are imported, re-run
   `python scripts/import_httpwg_tests.py` and
   `python scripts/verify_httpwg_snapshot.py`.

## Adding or updating official test vectors

1. Update `UPSTREAM_COMMIT` in `scripts/import_httpwg_tests.py`.
2. Re-download the JSON files at that commit into `testdata/httpwg/`
   (read-only; never copy implementation code).
3. Regenerate: `python scripts/import_httpwg_tests.py`.
4. Verify: `python scripts/verify_httpwg_snapshot.py`.
5. Update `docs/compliance.md` and `CHANGELOG.md` with the new numbers.

## Reporting issues

Include the minimal input, the expected RFC behavior, and the actual output
(with the error kind and offset if applicable).
