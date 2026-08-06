# Architecture

This document describes the internal design of `moon-sfv`. It assumes
familiarity with RFC 9651's parsing and serializing algorithms (§4).

## Overview

The crate is a single MoonBit package (`6P66006/moon-sfv`) with three
concentric layers:

```
                    +---------------------------+
                    | Public API (parse_*,      |
                    | serialize_*, canonicalize)|
                    +-------------+-------------+
                                  |
              +-------------------+-------------------+
              | Parser layer      | Serializer layer   |
              | (cursor-based,    | (buffer-based,     |
              |  byte-precise)    |  RFC 4.1)          |
              +---------+---------+---------+----------+
                        |                   |
                  +-----v-----+       +-----v-----+
                  |  Cursor   |       |  SfError  |
                  | (bytes)   |       | (kind,    |
                  +-----------+       |  offset,  |
                                      |  context) |
                  +----------------------------------+
                  |  Data model (model.mbt,          |
                  |  ordered_map.mbt, decimal.mbt)   |
                  +----------------------------------+
```

## Data model

`model.mbt` defines the abstract values of RFC 9651:

- `BareItem` — the eight scalar types, stored as an enum. `Decimal` holds an
  `SfDecimal`, never a floating-point value.
- `Item { bare, parameters }`
- `InnerList { items, parameters }`
- `ListMember` (enum: item or inner list) and `SfList { members }`
- `DictionaryEntry { key, value }` and `SfDictionary { entries }`
- `SerializedField` — the result type that lets callers distinguish an
  omitted field (`Omit`) from an empty string (`Value`).

Parameters and Dictionaries are ordered maps backed by `Array`
(`ordered_map.mbt`). Insertion order is preserved; `set` replaces in place
when a key already exists, which implements RFC 9651's rule that duplicate
keys on the wire collapse to their last occurrence while keeping the first
occurrence's position.

All types derive `Debug` and `Eq`; `SfDecimal` implements `Eq` manually as
*semantic* equality via its exact `compare`, so `1.2` and `1.20` compare
equal.

## Parser layer

Every parser is a function over a `Cursor` (see below) returning
`Result[T, SfError]`. The files mirror RFC 9651 §4.2:

| File                      | RFC §4.2.x                          |
|---------------------------|-------------------------------------|
| `parser_bare_item.mbt`    | .3.1 dispatch, .4–.10 scalar types  |
| `parser_parameters.mbt`   | .3.2 Parameters                     |
| `parser_item.mbt`         | .3 Item + public `parse_item`       |
| `parser_inner_list.mbt`   | .1.2 Inner List                     |
| `parser_list.mbt`         | .1 List + public `parse_list`       |
| `parser_dictionary.mbt`   | .2 Dictionary + public entry points |
| `parser_common.mbt`       | top-level field algorithm, `key`    |

Two small support modules are shared by both directions:

- `base64.mbt` — the lenient base64 decoder for Byte Sequences (missing
  padding and non-zero pad bits tolerated, per RFC §4.2.7).
- `percent_encoding.mbt` — lowercase percent-encoding/decoding helpers for
  Display Strings.

`parse_field_bytes` implements the RFC §4.2 top-level algorithm: discard
leading SP, parse by type, discard trailing SP, require emptiness — this is
what produces `TrailingInput` errors.

Design rules enforced throughout:

- The parser works on UTF-8 `Bytes`, so every reported offset is a *byte*
  offset. No conversion back to `String` happens mid-parse.
- All reads go through `Cursor` bounds checks.
- Integer/decimal digit accumulation is guarded by length checks *before*
  arithmetic, so overflow can never occur on well-formed input.
- List/Dictionary member separators use OWS (SP/HTAB, per the RFC note
  about line combining); inner-list and parameter separators use SP only.

## Cursor

`cursor.mbt` is a bounds-checked read cursor over `Bytes`. It exposes
`peek`, `peek_n`, `consume`, `consume_if`, `skip_spaces` (SP only),
`skip_ows` (SP/HTAB), `slice`, `checkpoint`/`restore`, and `at` (absolute
offset reads). `position` is always a valid byte offset in `[0, len]`, which
is what makes truncation-at-every-byte testing safe.

## Serializer layer

Serializers append into a `@buffer.Buffer` and return `Result[Unit,
SfError]`; the public API converts the buffer to a `String`. The files
mirror RFC 9651 §4.1:

| File                    | RFC §4.1.x |
|-------------------------|------------|
| `serializer_bare_item.mbt` | .3.1 dispatch, .4–.11 scalars |
| `serializer_common.mbt` | .1.2 Parameters, .1.3 Key       |
| `serializer_item.mbt`   | .3 Item                         |
| `serializer_list.mbt`   | .1 List, .1.1 Inner List        |
| `serializer_dictionary.mbt` | .2 Dictionary               |

Serialization validates every value before emitting: integer range, string
printability, token characters, key characters, and decimal precision. An
out-of-range or unrepresentable value fails with `SerializationError` rather
than emitting invalid output.

## Exact decimal

`decimal.mbt` stores `{ coefficient: Int64, scale: Int }` where the value is
`coefficient × 10^-scale`. `to_canonical_string` implements RFC 4.1.5:
rounding to three places with ties-to-even, rejecting more than twelve
integer digits, and always keeping at least one fractional digit. `compare`
compares values exactly without floating point, using a digit-count
shortcut followed by a bounded cross-multiplication.

## Error propagation

Every function returns `Result[T, SfError]`; no parser or serializer uses
exceptions. `SfError` is `{ kind, offset, context }`. Parse errors carry the
byte offset at which the failure occurred and a short, truncated context
snippet; serializer errors carry a reason string.

## Multi-line fields and canonicalization

`field_lines.mbt` combines field lines with `", "` before parsing, matching
the combining convention the httpwg test suite assumes. `canonicalize.mbt`
is parse-then-serialize and is idempotent by construction.

## Conformance harness

`httpwg_conformance_data*.mbt` are generated by
`scripts/import_httpwg_tests.py` from the pinned official JSON snapshots in
`testdata/httpwg/` and hold 1591 `HttpwgCase` records. `conformance.mbt`
runs them and produces categorized statistics; `conformance_test.mbt`
asserts that required behaviors hold and prints the report.
