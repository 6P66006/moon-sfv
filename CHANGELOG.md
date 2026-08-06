# Changelog

All notable changes to this project are recorded here. The project is in
local development; no releases have been published.

## [0.1.0-dev] — 2026-08-04

Initial local development build.

### Added

- Core RFC 9651 implementation:
  - all eight bare-item types (integer, decimal, string, token, byte
    sequence, boolean, date, display string);
  - parameters, items, inner lists, lists, and dictionaries as ordered maps;
  - exact decimal arithmetic (`coefficient × 10^-scale`) with ties-to-even
    rounding to three places;
  - strict parsing following RFC 9651 §4.2, including multi-line field
    combination and duplicate-key handling;
  - canonical serialization following RFC 9651 §4.1, including the
    omit-empty-field rule for Lists and Dictionaries;
  - structured errors (`SfErrorKind`, UTF-8 byte offsets, bounded context);
  - configurable `ParseLimits` for hostile-input safety.
- `cmd/sfv-tool` CLI with `parse`, `validate`, `canonicalize`, `roundtrip`,
  and `conformance` commands.
- Examples under `examples/`.
- Conformance harness importing the official HTTP Working Group
  `structured-field-tests` vectors (1591 records at commit
  `1e280c3ed9ffe0ca5fdb1d97219dddc389007677`).
- Import and snapshot-verification scripts under `scripts/`.
- Unit, property, truncation-safety, and conformance tests (113 tests; all
  targets green).

### Test results (initial)

- Required valid: 721/721
- Required invalid: 864/864
- Canonical round-trip: 721/721
- Optional (can_fail): 6/6
- Expected structure: 717/717
- 0 errors, 0 warnings on native / js / wasm-gc.
