/// Lenient base64 decoding for Byte Sequences (RFC 9651 §4.2.7).
///
/// RFC 9651 says parsers SHOULD NOT fail when `=` padding is missing or
/// when the final sextet has non-zero pad bits, because many base64
/// implementations cannot reject them. The decoder here therefore
/// synthesizes missing padding and ignores the low bits of the final
/// sextet, while still rejecting characters outside the base64 alphabet,
/// padding in the middle, and line feeds (which the RFC makes MUST-fail).

///|
/// Decodes base64 content with missing-padding and non-zero-pad-bit
/// tolerance. The content must already have been alphabet-validated by the
/// caller. `base_offset` is the byte offset of `content` inside the
/// original input, used for error reporting.
pub fn decode_base64_lenient(
  content : Bytes,
  base_offset : Int,
) -> Result[Bytes, SfError] {
  let mut acc : Int = 0
  let mut bits : Int = 0
  let mut pad_seen = false
  let mut pad_count = 0
  let mut nonpad = 0
  let out : Array[Byte] = []
  for i in 0..<content.length() {
    let b = content[i]
    if b == b'=' {
      pad_seen = true
      pad_count = pad_count + 1
    } else {
      if pad_seen {
        return Err(
          SfError::make(
            InvalidBase64,
            base_offset + i,
            "padding before base64 content",
          ),
        )
      }
      nonpad = nonpad + 1
      acc = (acc << 6) | base64_value(b)
      bits = bits + 6
      if bits >= 8 {
        bits = bits - 8
        out.push(((acc >> bits) & 0xFF).to_byte())
        acc = acc & ((1 << bits) - 1)
      }
    }
  }
  if pad_count > 2 {
    return Err(
      SfError::make(
        InvalidBase64,
        base_offset + content.length() - 1,
        "too much padding",
      ),
    )
  }
  if nonpad % 4 == 1 {
    return Err(
      SfError::make(InvalidBase64, base_offset, "invalid base64 length"),
    )
  }
  Ok(Bytes::from_array(out))
}

///|
/// The 6-bit value of a base64 alphabet byte.
fn base64_value(b : Byte) -> Int {
  if b >= b'A' && b <= b'Z' {
    b.to_int() - 0x41
  } else if b >= b'a' && b <= b'z' {
    b.to_int() - 0x61 + 26
  } else if b >= b'0' && b <= b'9' {
    b.to_int() - 0x30 + 52
  } else if b == b'+' {
    62
  } else {
    63
  }
}
