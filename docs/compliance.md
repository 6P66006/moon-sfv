# Compliance report

Status is based only on the actual test results recorded below. Labels are
`Implemented`, `Tested`, `Partially Tested`, or `Not Yet Tested`.

## Data types

| Type            | Parsing | Serialization | Status            |
|-----------------|---------|---------------|-------------------|
| Integer         | yes     | yes           | Implemented, Tested |
| Decimal         | yes     | yes           | Implemented, Tested |
| String          | yes     | yes           | Implemented, Tested |
| Token           | yes     | yes           | Implemented, Tested |
| Byte Sequence   | yes     | yes           | Implemented, Tested |
| Boolean         | yes     | yes           | Implemented, Tested |
| Date            | yes     | yes           | Implemented, Tested |
| Display String  | yes     | yes           | Implemented, Tested |
| Parameters      | yes     | yes           | Implemented, Tested |
| Item            | yes     | yes           | Implemented, Tested |
| Inner List      | yes     | yes           | Implemented, Tested |
| List            | yes     | yes           | Implemented, Tested |
| Dictionary      | yes     | yes           | Implemented, Tested |

## RFC 9651 behaviors

| Behavior                                       | Status             |
|------------------------------------------------|--------------------|
| Integer range −999,999,999,999,999 … 999,999,999,999,999 | Implemented, Tested |
| Decimal: ≤12 integer digits, ≤3 fraction digits | Implemented, Tested |
| Decimal serialization rounding (ties-to-even)   | Implemented, Tested |
| Decimal: at least one fractional digit on output | Implemented, Tested |
| String: printable ASCII + `\"`/`\\` escapes     | Implemented, Tested |
| Token: `tchar`/`:`/`/`, ALPHA-or-`*` start      | Implemented, Tested |
| Byte Sequence: standard base64, missing padding tolerated | Implemented, Tested |
| Boolean `?0`/`?1`; `=?1` → omitted, `=?0` kept   | Implemented, Tested |
| Date: `@` + integer, no timezone conversion      | Implemented, Tested |
| Display String: lowercase percent-encoding, UTF-8 validation | Implemented, Tested |
| Parameters: Boolean true value omitted           | Implemented, Tested |
| Duplicate parameter keys → last value, first position | Implemented, Tested |
| Duplicate dictionary keys → last value, first position | Implemented, Tested |
| List/Dictionary member separator OWS (incl. HTAB) | Implemented, Tested |
| Inner-list separators: SP only                   | Implemented, Tested |
| Empty List/Dictionary → field omitted           | Implemented, Tested |
| Multi-line field combination                     | Implemented, Tested |
| Trailing input after a value fails               | Implemented, Tested |
| Erratum 8869: Display String is an Item type     | Implemented, Tested |

## Resource requirements from the RFC

| Requirement                                   | Default | Satisfied |
|-----------------------------------------------|---------|-----------|
| ≥1024 List members                            | 100 000 | yes       |
| ≥256 Inner List members                       | 100 000 | yes       |
| ≥256 parameters on an Item/Inner List         | 100 000 | yes       |
| ≥64-char parameter/dictionary keys            | 1 MiB   | yes       |
| ≥1024 String characters                       | 1 MiB   | yes       |
| ≥512 Token characters                         | 1 MiB   | yes       |
| ≥16384 decoded Byte Sequence octets           | 1 MiB   | yes       |

## Official test vector results (pinned snapshot)

Source: `httpwg/structured-field-tests` at commit
`1e280c3ed9ffe0ca5fdb1d97219dddc389007677`, imported 2026-08-04.

| Category            | Passed / Total | Result |
|---------------------|----------------|--------|
| required valid      | 721 / 721      | PASS   |
| required invalid    | 864 / 864      | PASS   |
| canonical round-trip| 721 / 721      | PASS   |
| optional (can_fail) | 6 / 6          | PASS   |
| expected structure  | 717 / 717      | PASS   |
| failures            | 0              | PASS   |

These numbers are produced by `conformance_test.mbt` / `sfv-tool
conformance`; they are not fabricated or filtered. A required failure would
fail the test run.

## Not yet verified

- **stdin input for `sfv-tool`** — the CLI reads input only from a
  command-line argument. Documented in README.
- **Field-level semantics** beyond grammar (e.g., what a specific field
  *means*) are out of scope.
- **Long-running fuzz campaigns** — the bundled fuzzer is deterministic and
  bounded; it is not a substitute for a property-based fuzz harness under
  many seeds. See docs/testing.md.

## Notes

The conformance data files (`httpwg_conformance_data*.mbt`) are generated
from the pinned snapshots; `scripts/verify_httpwg_snapshot.py` fails if the
snapshots or the generated data drift out of sync. Test data provenance and
licensing are in `THIRD_PARTY_NOTICES.md` and `testdata/httpwg/README.md`.
