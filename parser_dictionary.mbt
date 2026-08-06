/// Parsing of Dictionaries (RFC 9651 §4.2.2) and the public
/// `parse_dictionary` entry points.
///
/// Members are `key=value` pairs separated by `","` with surrounding OWS.
/// A member without `=value` is a Boolean true Item with its own
/// parameters. Duplicate keys collapse to their last occurrence.

///|
/// Parses a Dictionary.
pub fn parse_dictionary_cursor(
  cursor : Cursor,
  limits : ParseLimits,
) -> Result[SfDictionary, SfError] {
  let dict = SfDictionary::new()
  while !cursor.is_end() {
    let key = match parse_key(cursor) {
      Err(e) => return Err(e)
      Ok(k) => k
    }
    let dict_member = if cursor.peek() == Some(b'=') {
      let _ = cursor.consume()
      match parse_item_or_inner_list_cursor(cursor, limits) {
        Err(e) => return Err(e)
        Ok(v) => v
      }
    } else {
      let parameters = match parse_parameters_cursor(cursor, limits) {
        Err(e) => return Err(e)
        Ok(v) => v
      }
      ItemMember({ bare: Boolean(true), parameters })
    }
    dict.set(key, dict_member)
    if dict.len() > limits.max_members {
      return Err(err_at(cursor, TooManyMembers))
    }
    cursor.skip_ows()
    if cursor.is_end() {
      break
    }
    if !cursor.consume_if(b',') {
      return Err(err_at(cursor, TrailingInput))
    }
    cursor.skip_ows()
    if cursor.is_end() {
      return Err(err_at(cursor, TrailingInput))
    }
  }
  Ok(dict)
}

///|
/// Parses `input` as a Dictionary field value.
pub fn parse_dictionary(input : String) -> Result[SfDictionary, SfError] {
  parse_dictionary_bytes(@utf8.encode(input, bom=false))
}

///|
/// Parses `input` as a Dictionary field value, in UTF-8 bytes.
pub fn parse_dictionary_bytes(input : Bytes) -> Result[SfDictionary, SfError] {
  parse_field_bytes(input, ParseLimits::default(), parse_dictionary_cursor)
}

///|
/// Parses `input` as a Dictionary field value with custom limits.
pub fn parse_dictionary_with_limits(
  input : String,
  limits : ParseLimits,
) -> Result[SfDictionary, SfError] {
  parse_field_bytes(
    @utf8.encode(input, bom=false),
    limits,
    parse_dictionary_cursor,
  )
}
