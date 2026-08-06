# moon-sfv

**RFC 9651 Structured Field Values for HTTP — parser, serializer, and
conformance toolkit for MoonBit.**

`moon-sfv` is a strict, dependency-free implementation of [RFC 9651]
("Structured Field Values for HTTP", formerly RFC 8941). It parses and
serializes the three Structured Fields top-level types — **Items**, **Lists**,
and **Dictionaries** — with exact, lossless semantics, and ships a
conformance harness that runs the official
[HTTP Working Group test vectors](https://github.com/httpwg/structured-field-tests)
against the implementation.

[RFC 9651]: https://www.rfc-editor.org/rfc/rfc9651.html

## Goals and scope

**Goal.** Provide a strict, exact, dependency-free MoonBit implementation of
RFC 9651 so MoonBit applications can build and consume Structured Fields
interoperably, plus tooling to prove conformance.

**Scope.**
- Full parse / serialize / canonicalize support for all eight bare-item
  types and all three top-level containers (Item, List, Dictionary),
  including parameters, inner lists, multi-line fields, and the
  omit-empty-field rule.
- Exact decimal arithmetic (no floating point), structured errors, and
  configurable input limits for hostile HTTP traffic.
- A conformance harness running the official HTTP Working Group test
  vectors, and a CLI (`sfv-tool`) for ad-hoc checking.

**Out of scope.** Field-specific semantics (what a given field *means*),
stdin input for the CLI, and publishing/registry integration. The module
name is a local placeholder (`localdev/moon-sfv`) until a final namespace is
chosen — see `docs/renaming.md`.

## What is RFC 9651?

HTTP headers are normally defined as opaque strings, which forces every
implementation to reinvent fragile parsing. RFC 9651 standardizes a small
set of data types — integers, decimals, strings, tokens, byte sequences,
booleans, dates, and display strings — and the exact algorithms for parsing
and serializing them. Fields built on Structured Fields get a well-defined
syntax, a canonical wire form, and interoperable behavior by construction.

Common fields already defined in terms of Structured Fields include
`Cache-Status`, `CDN-Cache-Control`, `Priority`, `Accept-CH`, and many
others.

## Supported types

`moon-sfv` implements every abstract type in RFC 9651:

| Type            | Wire example                      | `BareItem` variant   |
|-----------------|-----------------------------------|----------------------|
| Integer         | `42`, `-123456789012345`          | `Integer(Int64)`     |
| Decimal         | `4.5`, `-0.125`                   | `Decimal(SfDecimal)` |
| String          | `"hello world"`                   | `StringItem(String)` |
| Token           | `foo/bar:baz`                     | `Token(String)`      |
| Byte Sequence   | `:cHJldGVuZCB0aGlzIGlzIGJpbmFyeSBjb250ZW50Lg==:` | `ByteSequence(Bytes)` |
| Boolean         | `?1`, `?0`                        | `Boolean(Bool)`      |
| Date            | `@1659578233`                     | `Date(Int64)`        |
| Display String  | `%"hello %c3%a9"`                 | `DisplayString(String)` |

The three top-level containers are `Item`, `SfList`, and `SfDictionary`;
items can carry `Parameters`, and lists and dictionaries can contain
`InnerList` members. Decimals use an exact `coefficient × 10^-scale`
representation (no floating point), and serialization rounds to three
decimal places using ties-to-even, exactly as the RFC requires.

## Parsing

```moonbit
fn main {
  match parse_item("5; foo=bar") {
    Err(e) => println(e.to_string())
    Ok(item) => {
      // item.bare            -> Integer(5)
      // item.parameters.len() -> 1
      // item.parameters.get_by_key("foo") -> Some(Token("bar"))
    }
  }
}
```

The public entry points are `parse_item`, `parse_list`, and
`parse_dictionary` (plus `*_bytes` and `*_with_limits` variants), and the
multi-line helpers `parse_item_lines`, `parse_list_lines`, and
`parse_dictionary_lines`.

## Serialization

```moonbit
let item = parse_item("5; a=?1; b=?0")?
match serialize_item(item) {
  Err(e) => println(e.to_string())
  Ok(wire) => println(wire) // "5;a;b=?0" — Boolean true is omitted
}
```

`serialize_item` returns `Result[String, SfError]`; `serialize_list` and
`serialize_dictionary` return `Result[SerializedField, SfError]`, where the
`Omit` variant expresses the RFC 9651 rule that an *empty* List or
Dictionary is represented by omitting the field entirely — the caller can
distinguish "field omitted" from "field with an empty value".

## Canonicalization

```moonbit
// "0002"     -> "2"
// "4.500"    -> "4.5"
// "5; a=?1"  -> "5;a"
// "1, 42"    -> "1, 42"
canonicalize(input, FieldType::List)?
```

`canonicalize` parses then strictly re-serializes, producing the canonical
wire form. It is idempotent: `canonicalize(canonicalize(x))` equals
`canonicalize(x)`, and `parse(serialize(value))` is semantically equal to
`value`.

## Error handling

Errors are structured, never bare strings:

```moonbit
match parse_item("abc, def") {
  Err(e) => {
    e.kind()     // SfErrorKind::TrailingInput
    e.offset()   // 3  — a UTF-8 byte offset into the input
    e.to_string() // "trailing input after value at byte 3: near \", def\""
  }
  Ok(_) => ()
}
```

There are 25 distinct `SfErrorKind` values covering every failure category.
Offsets are UTF-8 byte offsets (the same unit the parser works in), and
error context is truncated so errors never echo unbounded input back.

## Command-line tool

`sfv-tool` is a small checker built on the library.

```
sfv-tool parse --type item "5; foo=bar"
sfv-tool validate --type list "1, 42"
sfv-tool canonicalize --type dictionary "a=1,  b=2;c"
sfv-tool roundtrip --type item "0002"
sfv-tool conformance
```

Field commands read the input from the single positional argument; errors
are printed with the error kind and byte offset and exit with a non-zero
status. Byte sequences are rendered as hex, and dates keep their raw
seconds value.

## Building and running

Requires the MoonBit toolchain (`moon`, `moonc`, `moonrun`). No external
MoonBit dependency is used beyond the standard library.

```shell
# check, build, and test on the default target
moon check
moon build
moon test

# test a specific target
moon test --target native
moon test --target js
moon test --target wasm-gc

# run the CLI
moon run cmd/sfv-tool -- --help

# run an example
moon run examples/parse_item

# run the official httpwg conformance suite
moon run cmd/sfv-tool -- conformance

# full verification for all targets (format, build, test, snapshot check)
powershell -ExecutionPolicy Bypass -File scripts/verify_all.ps1
```

## Security limits

Parsing is bounded by a configurable [`ParseLimits`] structure. The
defaults satisfy every RFC 9651 requirement (1024+ List members, 256
parameters, 1024+ String characters, 512+ Token characters, 16384+ decoded
Byte Sequence octets) while capping hostile inputs: 4 MiB of input, 100k
members, and 1 MiB per string/sequence. Every cursor read is bounds-checked,
and truncation at any byte position is covered by tests.

[`ParseLimits`]: error.mbt

## Test status

- **113 unit/property tests**, covering every type, boundaries, rounding,
  escaping, truncation safety, multi-line fields, and a fixed-seed fuzzer
  that round-trips thousands of generated values.
- **1591 official HTTP Working Group vectors** imported into the
  conformance harness. Current results: required valid 721/721, required
  invalid 864/864, canonical round-trip 721/721, optional 6/6, expected
  structure 717/717, zero failures.
- Verified on the `native`, `js`, and `wasm-gc` targets with 0 errors and
  0 warnings.

## Not yet verified / out of scope

- Reading input from stdin in `sfv-tool` (the CLI currently accepts input
  only as a command-line argument).
- Benchmarks and long-running fuzz campaigns (the bundled fuzzer is
  deterministic and bounded for CI).
- Field-level semantics beyond the RFC grammar — this library validates and
  canonicalizes syntax, it does not interpret field-specific meaning.

## Development

See [docs/architecture.md](docs/architecture.md) for the internal design,
[docs/testing.md](docs/testing.md) for how to run the full suite, and
[CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines. The import
of official test data is documented in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

This is a local development project. It is not published, and no
maintainer or author information is attached.
