/// Serialization of Items (RFC 9651 §4.1.3) and the public `serialize_item`
/// entry point.

///|
/// Serializes an Item into `buf`.
pub fn serialize_item_impl(
  buf : @buffer.Buffer,
  item : Item,
) -> Result[Unit, SfError] {
  match serialize_bare_item(buf, item.bare) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  match serialize_parameters(buf, item.parameters) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  Ok(())
}

///|
/// Serializes an Item to its ASCII wire form.
pub fn serialize_item(value : Item) -> Result[String, SfError] {
  let buf = @buffer.Buffer(size_hint=32)
  match serialize_item_impl(buf, value) {
    Err(e) => Err(e)
    Ok(_) => Ok(bytes_to_ascii(buf.to_bytes()))
  }
}
