/// Serialization of bare items (RFC 9651 §4.1.3.1) and each scalar type
/// (§4.1.4 through §4.1.11).

///|
/// Serializes a bare item, dispatching on its variant.
pub fn serialize_bare_item(
  buf : @buffer.Buffer,
  bare : BareItem,
) -> Result[Unit, SfError] {
  match bare {
    Integer(v) => serialize_integer(buf, v)
    Decimal(d) =>
      match d.to_canonical_string() {
        Err(e) => Err(e)
        Ok(s) => {
          ws(buf, s)
          Ok(())
        }
      }
    StringItem(s) => serialize_string(buf, s)
    Token(s) => serialize_token(buf, s)
    ByteSequence(b) => serialize_byte_sequence(buf, b)
    Boolean(v) => serialize_boolean(buf, v)
    Date(v) => serialize_date(buf, v)
    DisplayString(s) => serialize_display_string(buf, s)
  }
}

///|
/// Serializes an Integer (RFC 9651 §4.1.4), validating the fifteen-digit
/// range.
pub fn serialize_integer(
  buf : @buffer.Buffer,
  v : Int64,
) -> Result[Unit, SfError] {
  if v < INT64_MIN_VALID || v > INT64_MAX_VALID {
    return Err(serr("integer out of range"))
  }
  if v < 0L {
    wb(buf, b'-')
  }
  ws(buf, v.abs().to_string())
  Ok(())
}

///|
/// Serializes a String (RFC 9651 §4.1.6), escaping `"` and `\`.
pub fn serialize_string(
  buf : @buffer.Buffer,
  s : String,
) -> Result[Unit, SfError] {
  let units = s.code_units()
  for i in 0..<units.length() {
    let u = units[i]
    if u < 0x20 || u > 0x7E {
      return Err(serr("string contains a non-visible character"))
    }
  }
  let bytes = @utf8.encode(s, bom=false)
  wb(buf, b'"')
  for i in 0..<bytes.length() {
    let b = bytes[i]
    if b == b'\\' || b == b'"' {
      wb(buf, b'\\')
    }
    wb(buf, b)
  }
  wb(buf, b'"')
  Ok(())
}

///|
/// Serializes a Token (RFC 9651 §4.1.7).
pub fn serialize_token(
  buf : @buffer.Buffer,
  s : String,
) -> Result[Unit, SfError] {
  let bytes = @utf8.encode(s, bom=false)
  if bytes.is_empty() {
    return Err(serr("empty token"))
  }
  let first = bytes[0]
  if !is_alpha(first) && first != b'*' {
    return Err(serr("token does not start with a valid character"))
  }
  for i in 0..<bytes.length() {
    let b = bytes[i]
    if !is_token_char(b) {
      return Err(serr("token contains an invalid character"))
    }
  }
  ws(buf, s)
  Ok(())
}

///|
/// Serializes a Byte Sequence (RFC 9651 §4.1.8) using canonical padded
/// base64.
pub fn serialize_byte_sequence(
  buf : @buffer.Buffer,
  b : Bytes,
) -> Result[Unit, SfError] {
  wb(buf, b':')
  ws(buf, @base64.encode(b, padding=true))
  wb(buf, b':')
  Ok(())
}

///|
/// Serializes a Boolean (RFC 9651 §4.1.9).
pub fn serialize_boolean(
  buf : @buffer.Buffer,
  v : Bool,
) -> Result[Unit, SfError] {
  wb(buf, b'?')
  wb(buf, if v { b'1' } else { b'0' })
  Ok(())
}

///|
/// Serializes a Date (RFC 9651 §4.1.10): `@` followed by an Integer.
/// The value is a UTC seconds delta; no timezone conversion is performed.
pub fn serialize_date(buf : @buffer.Buffer, v : Int64) -> Result[Unit, SfError] {
  wb(buf, b'@')
  serialize_integer(buf, v)
}

///|
/// Serializes a Display String (RFC 9651 §4.1.11): `%"..."` with
/// percent-encoded UTF-8 bytes. Percent hex digits are lowercase.
pub fn serialize_display_string(
  buf : @buffer.Buffer,
  s : String,
) -> Result[Unit, SfError] {
  if !has_no_lone_surrogates(s) {
    return Err(serr("display string contains an unpaired surrogate"))
  }
  let bytes = @utf8.encode(s, bom=false)
  wb(buf, b'%')
  wb(buf, b'"')
  for i in 0..<bytes.length() {
    let b = bytes[i]
    if b == b'%' || b == b'"' || b < b' ' || b >= (0x7F).to_byte() {
      wb(buf, b'%')
      write_hex_byte(buf, b)
    } else {
      wb(buf, b)
    }
  }
  wb(buf, b'"')
  Ok(())
}

///|
/// Checks that a String contains no unpaired UTF-16 surrogate code units.
/// Unpaired surrogates would not round-trip through UTF-8 encoding.
fn has_no_lone_surrogates(s : String) -> Bool {
  let units = s.code_units()
  let mut i = 0
  while i < units.length() {
    let u = units[i]
    if u >= 0xD800 && u <= 0xDBFF {
      // High surrogate: the following unit must be a low surrogate.
      if i + 1 >= units.length() {
        return false
      }
      let nxt = units[i + 1]
      if !(nxt >= 0xDC00 && nxt <= 0xDFFF) {
        return false
      }
      i = i + 2
    } else if u >= 0xDC00 && u <= 0xDFFF {
      return false
    } else {
      i = i + 1
    }
  }
  true
}
