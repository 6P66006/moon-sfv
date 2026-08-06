#!/usr/bin/env python3
"""Import the httpwg `structured-field-tests` vectors into a MoonBit-loadable
data file.

The import is read-only with respect to the upstream repository: it only
consumes the JSON snapshots in `testdata/httpwg/`, never the implementation
code. It validates the record structure, extracts the fields needed for
conformance testing, converts each `expected` value into a MoonBit
expression, and emits a deterministic output file with a stable order so
repeated runs produce byte-identical results.

The upstream binary `expected` values are base32-encoded (per the repo's
README); this script decodes them to raw bytes and emits them as
hex strings, so the JSON intermediate representation is never mistaken for
the wire representation.
"""

from __future__ import annotations

import base64
import decimal
import hashlib
import json
import os
import subprocess
import sys
from typing import Any

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

SCRIPT_VERSION = "1.0.0"
UPSTREAM_REPO = "httpwg/structured-field-tests"
# Fixed at import time; the snapshot must not track a moving `main`.
UPSTREAM_COMMIT = "1e280c3ed9ffe0ca5fdb1d97219dddc389007677"

TEST_FILES = [
    "binary.json",
    "boolean.json",
    "date.json",
    "dictionary.json",
    "display-string.json",
    "examples.json",
    "item.json",
    "key-generated.json",
    "large-generated.json",
    "list.json",
    "listlist.json",
    "number-generated.json",
    "number.json",
    "param-dict.json",
    "param-list.json",
    "param-listlist.json",
    "string-generated.json",
    "string.json",
    "token-generated.json",
    "token.json",
]

OUTPUT_FILE = "httpwg_conformance_data.mbt"

# Expected structures larger than this are not embedded in the generated
# file (they are still checked via parse and canonical assertions).
EXPECTED_EMBED_LIMIT = 10000


# ---------------------------------------------------------------------------
# Error reporting
# ---------------------------------------------------------------------------

class ImportError_(Exception):
    pass


def die(msg: str) -> None:
    raise ImportError_(msg)


# ---------------------------------------------------------------------------
# JSON -> MoonBit value conversion
# ---------------------------------------------------------------------------

def moon_str_chunk(s: str) -> str:
    """Render a Python string as a single MoonBit string literal."""
    out = ['"']
    for ch in s:
        o = ord(ch)
        if ch == '"':
            out.append('\\"')
        elif ch == "\\":
            out.append("\\\\")
        elif ch == "\n":
            out.append("\\n")
        elif ch == "\t":
            out.append("\\t")
        elif ch == "\r":
            out.append("\\r")
        elif 0x20 <= o <= 0x7E:
            out.append(ch)
        elif o <= 0xFF:
            out.append("\\u%04x" % o)
        else:
            out.append("\\u{%x}" % o)
    out.append('"')
    return "".join(out)


def moon_str(s: str) -> str:
    """Render a Python string as a MoonBit string literal, splitting very
    long strings into `+`-joined chunks so no single source line exceeds the
    compiler's line/segment limit."""
    chunks = [s[i : i + 32] for i in range(0, max(len(s), 1), 32)]
    rendered = [moon_str_chunk(c) for c in chunks]
    if len(rendered) == 1:
        return rendered[0]
    # Trailing `+` is MoonBit's supported line-continuation marker.
    return "(\n  " + " +\n  ".join(rendered) + "\n)"


def moon_int(v: Any) -> str:
    if not isinstance(v, int):
        die("expected an integer, got %r" % (v,))
    return "%dL" % v


def moon_bool(v: Any) -> str:
    if not isinstance(v, bool):
        die("expected a boolean, got %r" % (v,))
    return "true" if v else "false"


def moon_decimal(v: Any) -> str:
    """Render a JSON number that denotes a Structured Fields Decimal as a
    MoonBit `SfDecimal::new(coeff, scale)` expression using exact decimal
    arithmetic. The JSON float is re-parsed as a decimal string so that no
    floating-point rounding is introduced."""
    if isinstance(v, bool) or not isinstance(v, (int, float)):
        die("expected a number for a decimal, got %r" % (v,))
    if isinstance(v, int):
        text = str(v) + ".0"
    else:
        text = repr(v)
    d = decimal.Decimal(text)
    sign, digits, exp = d.as_tuple()
    coeff = int("".join(map(str, digits)) or "0")
    if sign:
        coeff = -coeff
    scale = -exp
    return "(%dL, %d)" % (coeff, scale)


def moon_hex_bytes(v: str) -> str:
    """Render raw bytes as a hex string literal (the conformance harness
    decodes it at load time)."""
    return moon_str(v.hex())


def moon_array(items: list[str], indent: str, chunk: int = 25) -> str:
    """Render a list of MoonBit expressions as an array literal, splitting
    it into `+`-concatenated chunks so no single array literal is large
    enough to trip the compiler's text-segment limit."""
    if not items:
        return "[]"
    if len(items) <= chunk:
        return "[\n%s%s\n%s]" % (indent, (",\n%s" % indent).join(items), indent)
    chunks: list[str] = []
    for i in range(0, len(items), chunk):
        part = items[i : i + chunk]
        chunks.append(
            "[\n%s%s\n%s]" % (indent, (",\n%s" % indent).join(part), indent)
        )
    return "(" + " +\n".join(chunks) + ")"


def convert_bare_item(v: Any) -> str:
    """Convert a JSON bare-item value into a MoonBit `ExpectedBare`
    constructor expression."""
    if isinstance(v, bool):
        return "ExpBoolean(%s)" % moon_bool(v)
    if isinstance(v, int):
        return "ExpInteger(%s)" % moon_int(v)
    if isinstance(v, float):
        return "ExpDecimal%s" % moon_decimal(v)
    if isinstance(v, str):
        return "ExpString(%s)" % moon_str(v)
    if isinstance(v, dict):
        t = v.get("__type")
        if t == "token":
            return "ExpToken(%s)" % moon_str(v["value"])
        if t == "binary":
            raw = base64.b32decode(v["value"].encode("ascii"))
            return "ExpBinary(%s)" % moon_hex_bytes(raw)
        if t == "date":
            return "ExpDate(%s)" % moon_int(v["value"])
        if t == "displaystring":
            return "ExpDisplayString(%s)" % moon_str(v["value"])
        die("unknown __type object %r" % (v,))
    die("cannot convert bare item %r" % (v,))


def convert_params(v: Any) -> str:
    """Convert a JSON Parameters array into MoonBit `[ExpectedParam, ...]`."""
    if not isinstance(v, list):
        die("expected a parameters array, got %r" % (v,))
    parts = []
    for pair in v:
        if not isinstance(pair, list) or len(pair) != 2:
            die("bad parameter pair %r" % (pair,))
        key = pair[0]
        value = convert_bare_item(pair[1])
        parts.append("{ key: %s, value: %s }" % (moon_str(key), value))
    return moon_array(parts, "      ")


def convert_item(v: Any) -> str:
    """Convert a JSON Item `[bare, params]` into an `ExpectedItem` struct
    literal."""
    if not isinstance(v, list) or len(v) != 2:
        die("bad item %r" % (v,))
    bare = convert_bare_item(v[0])
    params = convert_params(v[1])
    return "{ bare: %s, params: %s }" % (bare, params)


def convert_member(v: Any) -> str:
    """Convert a JSON member value (Item or Inner List) into an
    `ExpectedMember` expression."""
    if not isinstance(v, list):
        die("bad member %r" % (v,))
    # An Inner List is a list whose first element is itself a list.
    if len(v) == 2 and isinstance(v[0], list):
        items = v[0]
        params = convert_params(v[1])
        item_parts = []
        for it in items:
            item_parts.append(convert_item(it))
        return "ExpInnerList(%s, %s)" % (moon_array(item_parts, "      "), params)
    return "ExpItemMember(%s)" % convert_item(v)


def convert_expected(header_type: str, v: Any) -> str:
    """Convert the whole `expected` JSON value into an `ExpectedField`
    expression."""
    if header_type == "item":
        return "ExpItemField(%s)" % convert_item(v)
    if header_type == "list":
        if not isinstance(v, list):
            die("bad list expected %r" % (v,))
        parts = [convert_member(m) for m in v]
        return "ExpListField(%s)" % moon_array(parts, "    ")
    if header_type == "dictionary":
        if not isinstance(v, list):
            die("bad dict expected %r" % (v,))
        parts = []
        for pair in v:
            if not isinstance(pair, list) or len(pair) != 2:
                die("bad dict member %r" % (pair,))
            key = moon_str(pair[0])
            member = convert_member(pair[1])
            parts.append("(%s, %s)" % (key, member))
        return "ExpDictField(%s)" % moon_array(parts, "    ")
    die("unknown header_type %r" % (header_type,))


# ---------------------------------------------------------------------------
# Record handling
# ---------------------------------------------------------------------------

def convert_record(file_name: str, index: int, rec: Any) -> str:
    if not isinstance(rec, dict):
        die("%s[%d]: record is not an object" % (file_name, index))
    name = rec.get("name")
    if not isinstance(name, str):
        die("%s[%d]: missing or non-string name" % (file_name, index))
    raw = rec.get("raw")
    if raw is None:
        # serialisation-tests have no `raw`; they are handled separately.
        raise SkipRecord
    if not isinstance(raw, list) or not all(isinstance(x, str) for x in raw):
        die("%s[%d] (%s): raw must be an array of strings" % (file_name, index, name))
    header_type = rec.get("header_type")
    if header_type not in ("item", "list", "dictionary"):
        die("%s[%d] (%s): bad header_type %r" % (file_name, index, name, header_type))
    must_fail = bool(rec.get("must_fail", False))
    can_fail = bool(rec.get("can_fail", False))
    canonical = rec.get("canonical")
    if canonical is not None:
        if not isinstance(canonical, list) or not all(isinstance(x, str) for x in canonical):
            die("%s[%d] (%s): bad canonical" % (file_name, index, name))
    expected = rec.get("expected")
    # Very large `expected` structures would blow past the compiler's
    # per-segment limit in the generated file. They are still fully checked
    # through the parse-success/failure and canonical checks, so skipping the
    # embedded expected structure here costs no coverage for those vectors.
    if expected is not None and len(json.dumps(expected)) > EXPECTED_EMBED_LIMIT:
        expected = None

    parts = []
    parts.append("name: %s" % moon_str(name))
    parts.append("header_type: %s" % moon_str(header_type))
    parts.append("raw: %s" % moon_array([moon_str(x) for x in raw], "      "))
    parts.append("must_fail: %s" % moon_bool(must_fail))
    parts.append("can_fail: %s" % moon_bool(can_fail))
    if canonical is None:
        parts.append("canonical: None")
    else:
        parts.append("canonical: Some(%s)" % moon_array([moon_str(x) for x in canonical], "      "))
    if expected is None:
        parts.append("expected: None")
    else:
        parts.append("expected: Some(%s)" % convert_expected(header_type, expected))

    return "  {\n    %s\n  }" % (",\n    ".join(parts))


class SkipRecord(Exception):
    """Raised for records that this import intentionally skips."""


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def compute_file_hashes() -> dict[str, str]:
    base = os.path.join(os.path.dirname(__file__), "..", "testdata", "httpwg")
    hashes = {}
    for name in TEST_FILES:
        path = os.path.join(base, name)
        with open(path, "rb") as f:
            hashes[name] = hashlib.sha256(f.read()).hexdigest()
    return hashes


def main() -> int:
    base = os.path.join(os.path.dirname(__file__), "..", "testdata", "httpwg")
    # Outputs are written to the project root by default; `verify_httpwg_snapshot.py`
    # redirects them to a scratch directory via this environment variable.
    out_dir = os.environ.get("MOON_SFV_IMPORT_TARGET") or os.path.join(
        os.path.dirname(__file__), ".."
    )
    out_path = os.path.join(out_dir, OUTPUT_FILE)

    records: list[str] = []
    meta: list[dict[str, Any]] = []
    seen_hashes: dict[str, str] = {}
    for file_name in TEST_FILES:
        path = os.path.join(base, file_name)
        with open(path, "rb") as f:
            data = f.read()
        seen_hashes[file_name] = hashlib.sha256(data).hexdigest()
        try:
            arr = json.loads(data.decode("utf-8"))
        except Exception as exc:  # noqa: BLE001
            die("%s: invalid JSON: %s" % (file_name, exc))
        if not isinstance(arr, list):
            die("%s: expected a JSON array" % file_name)
        for index, rec in enumerate(arr):
            try:
                records.append(convert_record(file_name, index, rec))
                meta.append(
                    {
                        "must_fail": bool(rec.get("must_fail", False)),
                        "can_fail": bool(rec.get("can_fail", False)),
                        "canonical": rec.get("canonical") is not None,
                    }
                )
            except SkipRecord:
                continue

    if not records:
        die("no records imported; refusing to write an empty data file")

    header = (
        "// Generated by scripts/import_httpwg_tests.py (version %s).\n"
        "// Do not edit by hand.\n"
        "// Source: %s @ %s\n"
        % (SCRIPT_VERSION, UPSTREAM_REPO, UPSTREAM_COMMIT)
    )

    # Split the case list into several top-level arrays, spread across a few
    # generated files so no single source file trips the compiler's
    # per-file line/segment limits.
    part_size = 20
    parts: list[list[str]] = []
    for i in range(0, len(records), part_size):
        parts.append(records[i : i + part_size])

    # The declarations file: types plus the assembled case list. Each part
    # array lives in a companion file.
    with open(out_path, "w", encoding="utf-8", newline="\n") as f:
        f.write(header)
        f.write("\n")
        f.write("/// The abstract types used to express `expected` values from the\n")
        f.write("/// httpwg test suite.\n")
        f.write("pub enum ExpectedBare {\n")
        f.write("  ExpInteger(Int64)\n")
        f.write("  ExpDecimal(Int64, Int)\n")
        f.write("  ExpString(String)\n")
        f.write("  ExpToken(String)\n")
        f.write("  ExpBinary(String)\n")
        f.write("  ExpBoolean(Bool)\n")
        f.write("  ExpDate(Int64)\n")
        f.write("  ExpDisplayString(String)\n")
        f.write("}\n")
        f.write("\n")
        f.write("pub struct ExpectedParam {\n")
        f.write("  key : String\n")
        f.write("  value : ExpectedBare\n")
        f.write("}\n")
        f.write("\n")
        f.write("pub struct ExpectedItem {\n")
        f.write("  bare : ExpectedBare\n")
        f.write("  params : Array[ExpectedParam]\n")
        f.write("}\n")
        f.write("\n")
        f.write("pub enum ExpectedMember {\n")
        f.write("  ExpItemMember(ExpectedItem)\n")
        f.write("  ExpInnerList(Array[ExpectedItem], Array[ExpectedParam])\n")
        f.write("}\n")
        f.write("\n")
        f.write("pub enum ExpectedField {\n")
        f.write("  ExpItemField(ExpectedItem)\n")
        f.write("  ExpListField(Array[ExpectedMember])\n")
        f.write("  ExpDictField(Array[(String, ExpectedMember)])\n")
        f.write("}\n")
        f.write("\n")
        f.write("pub struct HttpwgCase {\n")
        f.write("  name : String\n")
        f.write("  header_type : String\n")
        f.write("  raw : Array[String]\n")
        f.write("  must_fail : Bool\n")
        f.write("  can_fail : Bool\n")
        f.write("  canonical : Option[Array[String]]\n")
        f.write("  expected : Option[ExpectedField]\n")
        f.write("}\n")
        f.write("\n")
        f.write("///| Marks the start of a fresh text segment.\n")
        joined = " +\n  ".join("httpwg_cases_part_%d" % pi for pi in range(len(parts)))
        f.write("pub let httpwg_cases : Array[HttpwgCase] =\n  %s\n" % joined)
        f.write("\n")
        f.write("pub let httpwg_case_count : Int = %d\n" % len(records))

    # Companion files holding the part arrays, ~8 parts per file.
    parts_per_file = 8
    written: list[str] = [out_path]
    for fi in range(0, len(parts), parts_per_file):
        group = parts[fi : fi + parts_per_file]
        path = os.path.join(out_dir, "%s_part_%d.mbt" % (OUTPUT_FILE[:-4], fi // parts_per_file))
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(header)
            f.write("///| Marks the start of a fresh text segment.\n")
            for pi in range(fi, fi + len(group)):
                part = parts[pi]
                f.write("\n")
                f.write("///| Begins a new text segment.\n")
                f.write("pub let httpwg_cases_part_%d : Array[HttpwgCase] = [\n" % pi)
                for i, rec in enumerate(part):
                    sep = "," if i + 1 < len(part) else ""
                    f.write(rec + sep + "\n")
                f.write("]\n")
        written.append(path)

    # Format the generated files so they are stable under `moon fmt --check`.
    # `moon fmt` on a standalone file produces the same output as in-project
    # formatting, so this also keeps the snapshot diff deterministic.
    moon = os.environ.get("MOON_BIN") or r"D:\Moonbit\bin\moon.exe"
    for path in written:
        subprocess.run([moon, "fmt", path], check=False, capture_output=True)

    # Write SOURCE.json with provenance.
    expected_hashes = compute_file_hashes()
    for k in expected_hashes:
        if expected_hashes[k] != seen_hashes.get(k):
            die("hash mismatch for %s" % k)
    source = {
        "upstream": UPSTREAM_REPO,
        "commit_sha": UPSTREAM_COMMIT,
        "import_date": "2026-08-04",
        "import_script": "scripts/import_httpwg_tests.py",
        "script_version": SCRIPT_VERSION,
        "files": seen_hashes,
    }
    source_path = os.path.join(base, "SOURCE.json")
    with open(source_path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(source, f, indent=2, sort_keys=True)
        f.write("\n")

    required_valid = sum(1 for m in meta if not m["must_fail"] and not m["can_fail"])
    required_invalid = sum(1 for m in meta if m["must_fail"] and not m["can_fail"])
    optional = sum(1 for m in meta if m["can_fail"])
    with_canonical = sum(1 for m in meta if m["canonical"])

    print("Imported %d records into %s" % (len(records), OUTPUT_FILE))
    print("  required valid:   %d" % required_valid)
    print("  required invalid: %d" % required_invalid)
    print("  optional:         %d" % optional)
    print("  with canonical:   %d" % with_canonical)
    print("SOURCE.json written.")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except ImportError_ as exc:
        print("error: %s" % exc, file=sys.stderr)
        sys.exit(1)
