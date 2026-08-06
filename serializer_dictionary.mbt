/// Serialization of Dictionaries (RFC 9651 §4.1.2) and the public
/// `serialize_dictionary` entry point.

///|
/// Serializes a Dictionary into `buf`. Empty Dictionaries are not written
/// here; the top-level [`serialize_dictionary`] reports [`Omit`] for them.
pub fn serialize_dictionary_impl(
  buf : @buffer.Buffer,
  dict : SfDictionary,
) -> Result[Unit, SfError] {
  for i in 0..<dict.entries.length() {
    let entry = dict.entries[i]
    match serialize_key(buf, entry.key) {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
    match entry.value {
      ItemMember(item) => {
        let is_true = match item.bare {
          Boolean(v) => v
          _ => false
        }
        if is_true {
          match serialize_parameters(buf, item.parameters) {
            Err(e) => return Err(e)
            Ok(_) => ()
          }
        } else {
          wb(buf, b'=')
          match serialize_item_impl(buf, item) {
            Err(e) => return Err(e)
            Ok(_) => ()
          }
        }
      }
      InnerListMember(il) => {
        wb(buf, b'=')
        match serialize_inner_list(buf, il) {
          Err(e) => return Err(e)
          Ok(_) => ()
        }
      }
    }
    if i + 1 < dict.entries.length() {
      ws(buf, ", ")
    }
  }
  Ok(())
}

///|
/// Serializes a Dictionary. An empty Dictionary is represented by omitting
/// the field entirely, so the result is [`Omit`] rather than an empty
/// string.
pub fn serialize_dictionary(
  value : SfDictionary,
) -> Result[SerializedField, SfError] {
  if value.is_empty() {
    return Ok(Omit)
  }
  let buf = @buffer.Buffer(size_hint=64)
  match serialize_dictionary_impl(buf, value) {
    Err(e) => Err(e)
    Ok(_) => Ok(Value(bytes_to_ascii(buf.to_bytes())))
  }
}
