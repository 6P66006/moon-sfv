/// ASCII classification helpers used by the Structured Fields parser.
///
/// Every predicate here mirrors the character classes defined in RFC 9651
/// and the "token" ABNF rule it imports from RFC 9110. These are *not* the
/// same as the rules used for JSON, URLs, or ordinary HTTP header names.

///|
/// `ALPHA`: %x41-5A / %x61-7A.
pub fn is_alpha(b : Byte) -> Bool {
  (b >= b'A' && b <= b'Z') || (b >= b'a' && b <= b'z')
}

///|
/// `DIGIT`: %x30-39.
pub fn is_digit(b : Byte) -> Bool {
  b >= b'0' && b <= b'9'
}

///|
/// `lcalpha`: %x61-7A.
pub fn is_lower_alpha(b : Byte) -> Bool {
  b >= b'a' && b <= b'z'
}

///|
/// First character of a `key`: `lcalpha` or `*`.
pub fn is_key_start(b : Byte) -> Bool {
  is_lower_alpha(b) || b == b'*'
}

///|
/// Subsequent characters of a `key`: `lcalpha` / DIGIT / "_" / "-" / "." / "*".
pub fn is_key_char(b : Byte) -> Bool {
  is_lower_alpha(b) ||
  is_digit(b) ||
  b == b'_' ||
  b == b'-' ||
  b == b'.' ||
  b == b'*'
}

///|
/// `tchar` from RFC 9110:
/// `!` / `#` / `$` / `%` / `&` / `'` / `*` / `+` / `-` / `.` / `^` / `_` /
/// `` ` `` / `|` / `~` / DIGIT / ALPHA.
pub fn is_tchar(b : Byte) -> Bool {
  if is_alpha(b) || is_digit(b) {
    return true
  }
  match b {
    b'!' => true
    b'#' => true
    b'$' => true
    b'%' => true
    b'&' => true
    b'\'' => true
    b'*' => true
    b'+' => true
    b'-' => true
    b'.' => true
    b'^' => true
    b'_' => true
    b'`' => true
    b'|' => true
    b'~' => true
    _ => false
  }
}

///|
/// A `token` character: `tchar` / ":" / "/".
pub fn is_token_char(b : Byte) -> Bool {
  is_tchar(b) || b == b':' || b == b'/'
}

///|
/// Visible ASCII for String / Display String content: %x20-7E.
pub fn is_visible_ascii(b : Byte) -> Bool {
  b >= b' ' && b <= b'~'
}

///|
/// Hex digit value, or -1 if `b` is not a hex digit.
pub fn hex_value(b : Byte) -> Int {
  if b >= b'0' && b <= b'9' {
    return b.to_int() - 0x30
  }
  if b >= b'a' && b <= b'f' {
    return b.to_int() - 0x61 + 10
  }
  -1
}

///|
/// Characters allowed in the base64 content of a Byte Sequence:
/// ALPHA / DIGIT / "+" / "/" / "=".
pub fn is_base64_char(b : Byte) -> Bool {
  is_alpha(b) || is_digit(b) || b == b'+' || b == b'/' || b == b'='
}

///|
/// Space (0x20), the only whitespace permitted by the Item grammar.
pub fn is_sp(b : Byte) -> Bool {
  b == b' '
}

///|
/// Horizontal tab (0x09), allowed only as part of OWS in List/Dictionary.
pub fn is_h_tab(b : Byte) -> Bool {
  b == b'\t'
}

///|
/// OWS from RFC 9110: SP / HTAB.
pub fn is_ows(b : Byte) -> Bool {
  is_sp(b) || is_h_tab(b)
}

///|
/// Hexadecimal digit (0-9, a-f, A-F).
pub fn is_hex_digit(b : Byte) -> Bool {
  hex_value(b) >= 0
}
