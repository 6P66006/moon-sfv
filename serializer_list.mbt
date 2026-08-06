/// Serialization of Inner Lists (§4.1.1.1) and Lists (§4.1.1), plus the
/// public `serialize_list` entry point.

///|
/// Serializes an Inner List into `buf`.
pub fn serialize_inner_list(
  buf : @buffer.Buffer,
  inner_list : InnerList,
) -> Result[Unit, SfError] {
  wb(buf, b'(')
  for i in 0..<inner_list.items.length() {
    match serialize_item_impl(buf, inner_list.items[i]) {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
    if i + 1 < inner_list.items.length() {
      wb(buf, b' ')
    }
  }
  wb(buf, b')')
  match serialize_parameters(buf, inner_list.parameters) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  Ok(())
}

///|
/// Serializes a List into `buf`. Empty Lists are not written here; the
/// top-level [`serialize_list`] reports [`Omit`] for them.
pub fn serialize_list_impl(
  buf : @buffer.Buffer,
  list : SfList,
) -> Result[Unit, SfError] {
  for i in 0..<list.members.length() {
    let m = list.members[i]
    match m {
      ItemMember(item) =>
        match serialize_item_impl(buf, item) {
          Err(e) => return Err(e)
          Ok(_) => ()
        }
      InnerListMember(il) =>
        match serialize_inner_list(buf, il) {
          Err(e) => return Err(e)
          Ok(_) => ()
        }
    }
    if i + 1 < list.members.length() {
      ws(buf, ", ")
    }
  }
  Ok(())
}

///|
/// Serializes a List. An empty List is represented by omitting the field
/// entirely, so the result is [`Omit`] rather than an empty string.
pub fn serialize_list(value : SfList) -> Result[SerializedField, SfError] {
  if value.is_empty() {
    return Ok(Omit)
  }
  let buf = @buffer.Buffer(size_hint=64)
  match serialize_list_impl(buf, value) {
    Err(e) => Err(e)
    Ok(_) => Ok(Value(bytes_to_ascii(buf.to_bytes())))
  }
}
