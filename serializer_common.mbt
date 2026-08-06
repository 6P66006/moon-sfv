///|
/// Shared serialization infrastructure: the buffer writer helpers and the
/// `key` serializer (RFC 9651 §4.1.1.3).
const INT64_MIN_VALID : Int64 = -999_999_999_999_999L

///|
const INT64_MAX_VALID : Int64 = 999_999_999_999_999L

///|
/// A serialization failure with a short reason.
fn serr(reason : String) -> SfError {
  SfError::make(SerializationError, 0, reason)
}

///|
/// Writes a byte into the output buffer.
fn wb(buf : @buffer.Buffer, b : Byte) -> Unit {
  buf.write_byte(b)
}

///|
/// Writes an ASCII string into the output buffer.
fn ws(buf : @buffer.Buffer, s : String) -> Unit {
  buf.write_string_utf8(s)
}

///|
/// Serializes a key (RFC 9651 §4.1.1.3). The key must start with `lcalpha`
/// or `*` and otherwise contain only key characters.
pub fn serialize_key(
  buf : @buffer.Buffer,
  key : String,
) -> Result[Unit, SfError] {
  let bytes = @utf8.encode(key, bom=false)
  if bytes.is_empty() {
    return Err(serr("empty key"))
  }
  let first = bytes[0]
  if !is_key_start(first) {
    return Err(serr("key does not start with a valid character"))
  }
  for i in 0..<bytes.length() {
    let b = bytes[i]
    if !is_key_char(b) {
      return Err(serr("key contains an invalid character"))
    }
  }
  ws(buf, key)
  Ok(())
}

///|
/// Serializes Parameters (RFC 9651 §4.1.1.2). A Boolean true parameter
/// omits its value.
pub fn serialize_parameters(
  buf : @buffer.Buffer,
  parameters : Parameters,
) -> Result[Unit, SfError] {
  let entries = parameters.entries()
  for i in 0..<entries.length() {
    let p = entries[i]
    wb(buf, b';')
    match serialize_key(buf, p.key) {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
    let is_true = match p.value {
      Boolean(v) => v
      _ => false
    }
    if !is_true {
      wb(buf, b'=')
      match serialize_bare_item(buf, p.value) {
        Err(e) => return Err(e)
        Ok(_) => ()
      }
    }
  }
  Ok(())
}
