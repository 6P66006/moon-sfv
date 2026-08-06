# Testing

This document records every verification command and how the test statistics
are computed.

## Prerequisites

The project targets the MoonBit toolchain installed at `D:\Moonbit\bin`:

- `moon` 0.1.20260713
- `moonc` v0.10.4
- `moonrun` 0.1.20260713

All three targets — `native`, `js`, and `wasm-gc` — are available on this
machine and are verified below.

## Full verification

Run the whole suite (format, check, build, test, package list) for all
targets in one shot:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify_all.ps1
```

The script performs, in order:

```
moon clean
moon fmt --check
moon check --target wasm-gc && moon build --target wasm-gc && moon test --target wasm-gc
moon check --target js      && moon build --target js      && moon test --target js
moon check --target native  && moon build --target native  && moon test --target native
moon package --list
```

Any step that fails stops the script with a non-zero exit code and a clear
message. If a target is missing on a machine, the script reports the exact
command and error without modifying code or pretending the tests passed.

## Manual test commands

```powershell
# All tests on a single target
moon test --target native
moon test --target js
moon test --target wasm-gc

# Formatting must be clean
moon fmt --check

# Check/build without tests
moon check --target native
moon build --target native
```

## Test statistics

### Unit and property tests

`moon test` runs every `test "..."` block in the root package and reports
`Total tests: N, passed: P, failed: F`. The suite currently has **113** tests
across nine files:

| File                     | Focus                                                      |
|--------------------------|------------------------------------------------------------|
| `model_test.mbt`         | data model, ordered maps, duplicate-key semantics          |
| `decimal_test.mbt`       | exact decimals, rounding, comparison                       |
| `parser_item_test.mbt`   | all eight scalar types + item parameters                   |
| `parser_list_test.mbt`   | lists, inner lists, separators                             |
| `parser_dictionary_test.mbt` | dictionaries, implicit booleans, duplicate keys        |
| `serializer_test.mbt`    | canonical serialization of every type                      |
| `roundtrip_test.mbt`     | parse∘serialize, canonicalize idempotence, fixed-seed fuzz |
| `invalid_input_test.mbt` | truncation-at-every-byte, limits, error offsets            |
| `field_lines_test.mbt`   | multi-line combination rules                               |
| `conformance_test.mbt`   | official vectors + report                                  |

The fixed-seed fuzzer in `roundtrip_test.mbt` generates 2000 pseudo-random
items (xorshift PRNG, seed `0xC0FFEE`) and asserts every one survives
`parse(serialize(v)) == v`; it is deterministic so CI is reproducible.

### Conformance statistics

`conformance_test.mbt` and `sfv-tool conformance` both call
`run_conformance()`, which iterates the 1591 imported official vectors and
produces:

- `required_valid_total` / `required_valid_passed` — vectors that must parse.
- `required_invalid_total` / `required_invalid_passed` — vectors that must
  fail.
- `canonical_total` / `canonical_passed` — required-valid vectors whose
  serialization matches the official canonical (or raw) wire form.
- `optional_total` / `optional_passed` / `optional_failed` — `can_fail`
  vectors, reported but not failing.
- `expected_total` / `expected_passed` — supplementary abstract-structure
  comparison.

The required counts are asserted in the test; a single required failure
fails the suite. The counts are the actual results — failing vectors are
never skipped or filtered.

### Snapshot integrity

`scripts/verify_httpwg_snapshot.py` re-runs the importer in a scratch
directory and diffs the output against the committed generated files, and
checks that every `testdata/httpwg/*.json` still matches the SHA-256 recorded
in `testdata/httpwg/SOURCE.json`. It exits non-zero if anything is out of
sync, so the committed vectors and the generated data cannot drift.

## CLI smoke commands

```powershell
moon run cmd/sfv-tool -- parse --type item "5; foo=bar"
moon run cmd/sfv-tool -- validate --type list "1, 42"
moon run cmd/sfv-tool -- canonicalize --type dictionary "a=1,  b=2;c"
moon run cmd/sfv-tool -- roundtrip --type item "0002"
moon run cmd/sfv-tool -- conformance
```

Invalid input makes `sfv-tool` exit non-zero and print the error kind and
byte offset.
