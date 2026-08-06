/// Parsing of Items (RFC 9651 §4.2.3) and the public `parse_item` entry
/// points.

///|
/// Parses an Item: a bare item followed by its parameters.
pub fn parse_item_cursor(
  cursor : Cursor,
  limits : ParseLimits,
) -> Result[Item, SfError] {
  let bare = match parse_bare_item_cursor(cursor, limits) {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  let parameters = match parse_parameters_cursor(cursor, limits) {
    Err(e) => return Err(e)
    Ok(v) => v
  }
  Ok({ bare, parameters })
}

///|
/// Parses `input` as an Item field value.
pub fn parse_item(input : String) -> Result[Item, SfError] {
  parse_item_bytes(@utf8.encode(input, bom=false))
}

///|
/// Parses `input` as an Item field value, in UTF-8 bytes. Avoids a
/// redundant string-to-bytes conversion when the input is already bytes.
pub fn parse_item_bytes(input : Bytes) -> Result[Item, SfError] {
  parse_field_bytes(input, ParseLimits::default(), parse_item_cursor)
}

///|
/// Parses `input` as an Item field value with custom limits.
pub fn parse_item_with_limits(
  input : String,
  limits : ParseLimits,
) -> Result[Item, SfError] {
  parse_field_bytes(@utf8.encode(input, bom=false), limits, parse_item_cursor)
}
