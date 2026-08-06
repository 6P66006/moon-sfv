# Design decisions

This document records the rationale behind notable implementation choices.
Each decision names the problem, the chosen approach, and why.

## Why decimals are not stored as `Double`/`Float`

**Problem.** RFC 9651 decimals carry at most three fractional digits but
must round exactly (ties-to-even) on serialization, and comparisons must be
exact. IEEE-754 doubles cannot represent `0.1` exactly, so a double-backed
decimal would round incorrectly and compare incorrectly.

**Decision.** `SfDecimal` stores `coefficient × 10^-scale` exactly in an
`Int64` (`decimal.mbt`). Rounding to three places is integer arithmetic on
the coefficient; comparison is exact.

**Why it is right.** The parser never introduces representation error, and
the serializer's `0.0015 → 0.002`, `0.0025 → 0.002`, `9.9995 → 10.0` cases
match the official serialization test vectors exactly.

## Why Token and String are separate variants

**Problem.** Tokens and Strings have different character sets (tchar vs
printable ASCII), different delimiters (unquoted vs `"..."`), and different
serialization (no escaping vs `\`/`"` escaping). Collapsing them would force
the serializer to guess which wire form to emit.

**Decision.** `BareItem::Token(String)` and `BareItem::StringItem(String)`
are distinct variants, validated independently on both parse and serialize.

**Why it is right.** A token is serialized verbatim; a string is escaped and
quoted. Keeping them apart makes both directions unambiguous and lets the
conformance harness check them separately.

## Why Parameters and Dictionaries use an ordered `Array`

**Problem.** RFC 9651 requires access by index *and* by key, and duplicate
keys must collapse to their last occurrence while preserving order.

**Decision.** `Parameters` and `SfDictionary` are `Array`-backed ordered
maps. `get_by_index` is O(1); `get_by_key` and `set` are O(n) linear scans
(parameters and dictionary members are small in practice and bounded by
`ParseLimits`).

**Why it is right.** Order is part of the data model (the RFC says
"parameters are ordered"), so a `Hashmap` would need a parallel order vector
anyway. The linear scan keeps the implementation small and deterministic.

## Why error offsets are byte offsets, not character counts

**Problem.** Error offsets must be actionable regardless of how the caller
slices the input.

**Decision.** All parsing operates on UTF-8 `Bytes`; `SfError::offset` is a
byte offset into that encoding. Display string content is decoded only at
the end of its own parse, so offsets stay byte-accurate even for non-ASCII
input.

**Why it is right.** Byte offsets are the natural unit for a byte-based
parser and are well-defined even when the input contains multi-byte
sequences; character counts would require decoding mid-parse.

## Why parsing is strict by default

**Problem.** HTTP fields are untrusted input; lenient parsers silently
accept values no other implementation accepts, which is an interoperability
and security hazard.

**Decision.** The parser follows RFC 9651 §4.2 exactly: unknown top-level
bytes fail, uppercase keys fail, misplaced padding fails, stray characters
after a value fail with `TrailingInput`. There are no "fix-it" heuristics.

**Why it is right.** The RFC's own top-level algorithm (step 7: "If
input_string is not empty, fail parsing") mandates this, and the 864
required-invalid official vectors confirm the strict behavior is the
expected one.

## Why byte sequences tolerate missing padding and non-zero pad bits

**Problem.** RFC 9651 §4.2.7 says parsers SHOULD NOT fail on missing `=`
padding or non-zero pad bits, because many base64 libraries cannot reject
them.

**Decision.** The lenient decoder accepts missing padding (synthesizing it)
and ignores the low bits of the final sextet, while still rejecting
characters outside the base64 alphabet, padding in the middle, and line
feeds (which the RFC makes MUST-fail).

**Why it is right.** This matches both the RFC's SHOULD guidance and the
`can_fail` official vectors (`:aGVsbG8:`, `:iZ==:`), which we accept and
canonicalize correctly.

## Why Display Strings are a distinct type despite the §3.3 overview

RFC 9651 erratum 8869 (verified) notes that the §3.3 overview omitted
Display String from the list of Item types, but the grammar, parsing
algorithm (§4.2.10), and serialization algorithm (§4.1.11) all include it.
We implement it as a first-class `BareItem::DisplayString` variant, and the
conformance suite covers the official display-string vectors.

## Why serialization of empty List/Dictionary returns `Omit`

**Problem.** RFC 9651 §4.1 step 1 says an empty List or Dictionary is
represented by *omitting the field*. Returning a plain empty string would
make it impossible to distinguish "field omitted" from "empty field value".

**Decision.** `serialize_list`/`serialize_dictionary` return
`Result[SerializedField, SfError]` where `SerializedField` is `Omit | Value
String`. Items always produce `Value`.

## Why Backslash is not percent-encoded in Display Strings

The serialization algorithm (§4.1.11 step 4.1) percent-encodes only `%x25`,
`%x22`, and `%x00-1f`/`%x7f-ff` — backslash is not in that set, even though
the (non-normative) ABNF's `unescaped` excludes it. The RFC states that the
algorithms take precedence over the ABNF, so we follow the algorithm: `\` is
emitted literally and accepted literally on parse. Round-trips are stable.

## Why there is no automatic input tolerance

The library rejects, rather than repairs, malformed input. Auto-tolerance
would silently change the abstract value a caller receives (e.g., dropping
invalid bytes), which is worse than a structured error the caller can
handle. Callers who need leniency can pre-process; the library guarantees
that what it returns is exactly what RFC 9651 describes.
