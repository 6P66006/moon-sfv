/// Parsing of bare items (RFC 9651 §4.2.3.1) and each scalar type:
/// integer, decimal, string, token, byte sequence, boolean, date, and
/// display string (§4.2.4 through §4.2.10).

///|
/// Parses a bare item, dispatching on the first byte.
pub fn parse_bare_item_cursor(
  cursor : Cursor,
  limits : ParseLimits,
) -> Result[BareItem, SfError] {
  let b = match cursor.peek() {
    None => return Err(err_end(cursor))
    Some(v) => v
  }
  if b == b'-' || is_digit(b) {
    return parse_integer_or_decimal_cursor(cursor, limits)
  }
  if b == b'"' {
    return parse_string_cursor(cursor, limits).map(s => StringItem(s))
  }
  if is_alpha(b) || b == b'*' {
    return parse_token_cursor(cursor, limits).map(s => Token(s))
  }
  if b == b':' {
    return parse_byte_sequence_cursor(cursor, limits).map(bs => ByteSequence(bs))
  }
  if b == b'?' {
    return parse_boolean_cursor(cursor).map(v => Boolean(v))
  }
  if b == b'@' {
    return parse_date_cursor(cursor, limits).map(v => Date(v))
  }
  if b == b'%' {
    return parse_display_string_cursor(cursor, limits).map(s => DisplayString(s))
  }
  Err(err_at(cursor, InvalidTopLevelType))
}

///|
/// Parses an Integer or Decimal (RFC 9651 §4.2.4). Returns an
/// [`BareItem`] carrying the parsed value.
pub fn parse_integer_or_decimal_cursor(
  cursor : Cursor,
  _limits : ParseLimits,
) -> Result[BareItem, SfError] {
  let mut sign : Int64 = 1L
  if cursor.consume_if(b'-') {
    sign = -1L
  }
  let fb = match cursor.peek() {
    None => return Err(err_at(cursor, InvalidInteger))
    Some(v) => v
  }
  if !is_digit(fb) {
    return Err(err_at(cursor, InvalidInteger))
  }
  let int_digits : Array[Byte] = []
  let frac_digits : Array[Byte] = []
  let mut seen_dot = false
  while true {
    let next = cursor.peek()
    match next {
      None => break
      Some(b2) =>
        if is_digit(b2) {
          let _ = cursor.consume()
          if seen_dot {
            frac_digits.push(b2)
            if frac_digits.length() > 3 {
              return Err(err_at(cursor, InvalidDecimal))
            }
          } else {
            int_digits.push(b2)
            if int_digits.length() > 15 {
              return Err(err_at(cursor, InvalidInteger))
            }
          }
        } else if !seen_dot && b2 == b'.' {
          if int_digits.length() > 12 {
            return Err(err_at(cursor, InvalidDecimal))
          }
          let _ = cursor.consume()
          seen_dot = true
        } else {
          break
        }
    }
  }
  if seen_dot {
    if frac_digits.is_empty() {
      return Err(err_at(cursor, InvalidDecimal))
    }
    let scale = frac_digits.length()
    let int_part = digits_to_int64(int_digits)
    let frac_part = digits_to_int64(frac_digits)
    let pow : Int64 = pow10_i64(scale)
    let coefficient = (int_part * pow + frac_part) * sign
    Ok(Decimal(SfDecimal::new(coefficient, scale)))
  } else {
    let n = digits_to_int64(int_digits) * sign
    Ok(Integer(n))
  }
}

///|
/// Parses a quoted String (RFC 9651 §4.2.5). Only printable ASCII and the
/// two permitted escapes (`\"` and `\\`) are accepted.
pub fn parse_string_cursor(
  cursor : Cursor,
  limits : ParseLimits,
) -> Result[String, SfError] {
  if !cursor.consume_if(b'"') {
    return Err(err_at(cursor, InvalidString))
  }
  let buf = @buffer.Buffer(size_hint=16)
  while true {
    let ch = cursor.consume()
    match ch {
      None => return Err(err_end(cursor))
      Some(b) => {
        if b == b'\\' {
          match cursor.consume() {
            None => return Err(err_end(cursor))
            Some(nxt) =>
              if nxt == b'"' || nxt == b'\\' {
                buf.write_byte(nxt)
              } else {
                return Err(err_at(cursor, InvalidEscape))
              }
          }
        } else if b == b'"' {
          return Ok(bytes_to_ascii(buf.to_bytes()))
        } else if !is_visible_ascii(b) {
          return Err(err_at(cursor, InvalidString))
        } else {
          buf.write_byte(b)
        }
        if buf.length() > limits.max_string_bytes {
          return Err(
            err_with(
              cursor,
              InputTooLarge,
              cursor.position(),
              "string exceeds max_string_bytes",
            ),
          )
        }
      }
    }
  }
  Err(err_end(cursor))
}

///|
/// Parses a Token (RFC 9651 §4.2.6). The first character must be ALPHA or
/// `*`; subsequent characters are `tchar` / `:` / `/`.
pub fn parse_token_cursor(
  cursor : Cursor,
  limits : ParseLimits,
) -> Result[String, SfError] {
  let first = cursor.peek()
  match first {
    None => Err(err_end(cursor))
    Some(b) =>
      if !(is_alpha(b) || b == b'*') {
        Err(err_at(cursor, InvalidToken))
      } else {
        let _ = cursor.consume()
        let buf = @buffer.Buffer(size_hint=8)
        buf.write_byte(b)
        while true {
          let next = cursor.peek()
          match next {
            None => break
            Some(b2) => {
              if !is_token_char(b2) {
                break
              }
              let _ = cursor.consume()
              buf.write_byte(b2)
              if buf.length() > limits.max_string_bytes {
                return Err(
                  err_with(
                    cursor,
                    InputTooLarge,
                    cursor.position(),
                    "token exceeds max_string_bytes",
                  ),
                )
              }
            }
          }
        }
        Ok(bytes_to_ascii(buf.to_bytes()))
      }
  }
}

///|
/// Parses a Byte Sequence (RFC 9651 §4.2.7), delimited by colons and
/// base64-encoded. Padding is synthesized when missing, matching the RFC's
/// "SHOULD NOT fail" guidance for both missing padding and non-zero pad
/// bits.
pub fn parse_byte_sequence_cursor(
  cursor : Cursor,
  limits : ParseLimits,
) -> Result[Bytes, SfError] {
  if !cursor.consume_if(b':') {
    return Err(err_at(cursor, InvalidByteSequence))
  }
  let content_start = cursor.position()
  // Find the closing ':'.
  let mut end = content_start
  let mut closed = false
  while end < cursor.input_length() {
    if cursor.at(end) == Some(b':') {
      closed = true
      break
    }
    end = end + 1
  }
  if !closed {
    return Err(err_at(cursor, InvalidByteSequence))
  }
  let content = cursor.slice(content_start, end)
  cursor.restore(end + 1)
  // Validate the base64 alphabet.
  for i in 0..<content.length() {
    let b = content[i]
    if !is_base64_char(b) {
      return Err(
        err_with(
          cursor,
          InvalidBase64,
          content_start + i,
          "character outside base64 alphabet",
        ),
      )
    }
  }
  match decode_base64_lenient(content, content_start) {
    Ok(out) => {
      if out.length() > limits.max_string_bytes {
        return Err(
          err_with(
            cursor,
            InputTooLarge,
            cursor.position(),
            "byte sequence exceeds max_string_bytes",
          ),
        )
      }
      Ok(out)
    }
    Err(e) => Err(e)
  }
}

///|
/// Parses a Boolean (RFC 9651 §4.2.8): exactly `?0` or `?1`.
pub fn parse_boolean_cursor(cursor : Cursor) -> Result[Bool, SfError] {
  if !cursor.consume_if(b'?') {
    return Err(err_at(cursor, InvalidBoolean))
  }
  if cursor.consume_if(b'1') {
    return Ok(true)
  }
  if cursor.consume_if(b'0') {
    return Ok(false)
  }
  Err(err_at(cursor, InvalidBoolean))
}

///|
/// Parses a Date (RFC 9651 §4.2.9): `@` followed by an Integer. The value
/// is kept as a UTC seconds delta; no timezone conversion is performed.
pub fn parse_date_cursor(
  cursor : Cursor,
  limits : ParseLimits,
) -> Result[Int64, SfError] {
  if !cursor.consume_if(b'@') {
    return Err(err_at(cursor, InvalidDate))
  }
  match parse_integer_or_decimal_cursor(cursor, limits) {
    Err(e) => Err(e)
    Ok(Integer(v)) => Ok(v)
    Ok(Decimal(_)) => Err(err_at(cursor, InvalidDate))
    Ok(_) => Err(err_at(cursor, InvalidDate))
  }
}

///|
/// Parses a Display String (RFC 9651 §4.2.10): `%"..."` with percent-encoded
/// UTF-8 bytes. Percent hex digits must be lowercase.
pub fn parse_display_string_cursor(
  cursor : Cursor,
  limits : ParseLimits,
) -> Result[String, SfError] {
  if !cursor.consume_if(b'%') {
    return Err(err_at(cursor, InvalidDisplayString))
  }
  if !cursor.consume_if(b'"') {
    return Err(err_at(cursor, InvalidDisplayString))
  }
  let buf = @buffer.Buffer(size_hint=16)
  while true {
    let ch = cursor.consume()
    match ch {
      None => return Err(err_end(cursor))
      Some(b) => {
        if !is_visible_ascii(b) {
          return Err(err_at(cursor, InvalidDisplayString))
        }
        if b == b'%' {
          let h1 = cursor.consume()
          let h2 = cursor.consume()
          match (h1, h2) {
            (Some(a), Some(c)) => {
              if !is_lower_hex(a) || !is_lower_hex(c) {
                return Err(err_at(cursor, InvalidPercentEncoding))
              }
              let octet = ((hex_value(a) << 4) | hex_value(c)).to_byte()
              buf.write_byte(octet)
            }
            _ => return Err(err_at(cursor, InvalidPercentEncoding))
          }
        } else if b == b'"' {
          return decode_utf8_buffer(buf, cursor)
        } else {
          buf.write_byte(b)
        }
        if buf.length() > limits.max_string_bytes {
          return Err(
            err_with(
              cursor,
              InputTooLarge,
              cursor.position(),
              "display string exceeds max_string_bytes",
            ),
          )
        }
      }
    }
  }
  Err(err_end(cursor))
}

///|
/// Decodes a byte buffer as UTF-8, mapping decode failures to an
/// [`InvalidUtf8`] error at the given position.
fn decode_utf8_buffer(
  buf : @buffer.Buffer,
  cursor : Cursor,
) -> Result[String, SfError] {
  let bytes = buf.to_bytes()
  let decoded : String = @utf8.decode(bytes) catch {
    _ => return Err(err_at(cursor, InvalidUtf8))
  }
  Ok(decoded)
}

///|
/// Converts an array of ASCII digit bytes into an `Int64` value. The array
/// is never longer than 15 digits, so no overflow is possible.
fn digits_to_int64(ds : Array[Byte]) -> Int64 {
  let mut acc : Int64 = 0L
  for d in ds {
    acc = acc * 10L + (d - b'0').to_int64()
  }
  acc
}

///|
/// `10^n` for `n ≤ 15` as an `Int64`.
fn pow10_i64(n : Int) -> Int64 {
  let mut v : Int64 = 1L
  let mut k = n
  while k > 0 {
    v = v * 10L
    k = k - 1
  }
  v
}
