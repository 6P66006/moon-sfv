/// Percent-encoding helpers for Display Strings (RFC 9651 §4.1.11 and
/// §4.2.10).
///
/// Display String wire text percent-encodes UTF-8 bytes with *lowercase*
/// hex digits; the parser rejects uppercase hex in `%`-escapes and the
/// serializer always emits lowercase.

///|
/// Percent-encoding hex digits in Display Strings must be `0-9` or
/// lowercase `a-f` (RFC 9651 §4.2.10 step 4.3.2).
pub fn is_lower_hex(b : Byte) -> Bool {
  (b >= b'0' && b <= b'9') || (b >= b'a' && b <= b'f')
}

///|
/// Writes a byte as two lowercase hexadecimal digits (RFC 9651 §4.1.11
/// step 4.1.3).
pub fn write_hex_byte(buf : @buffer.Buffer, b : Byte) -> Unit {
  let hi = (b.to_int() >> 4) & 0x0F
  let lo = b.to_int() & 0x0F
  buf.write_byte(digit_hex(hi))
  buf.write_byte(digit_hex(lo))
}

///|
/// Maps a nibble to a lowercase hex digit byte.
fn digit_hex(n : Int) -> Byte {
  if n < 10 {
    (0x30 + n).to_byte()
  } else {
    (0x61 + n - 10).to_byte()
  }
}
