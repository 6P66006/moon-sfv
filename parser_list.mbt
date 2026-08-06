/// Parsing of Lists (RFC 9651 §4.2.1) and the public `parse_list` entry
/// points.
///
/// Members are separated by `","` with surrounding OWS. Empty members and
/// trailing commas fail the whole parse.

///|
/// Parses a List: comma-separated Items and Inner Lists.
pub fn parse_list_cursor(
  cursor : Cursor,
  limits : ParseLimits,
) -> Result[SfList, SfError] {
  let members : Array[ListMember] = []
  while !cursor.is_end() {
    let list_member = match parse_item_or_inner_list_cursor(cursor, limits) {
      Err(e) => return Err(e)
      Ok(v) => v
    }
    members.push(list_member)
    if members.length() > limits.max_members {
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
  Ok({ members, })
}

///|
/// Parses `input` as a List field value.
pub fn parse_list(input : String) -> Result[SfList, SfError] {
  parse_list_bytes(@utf8.encode(input, bom=false))
}

///|
/// Parses `input` as a List field value, in UTF-8 bytes.
pub fn parse_list_bytes(input : Bytes) -> Result[SfList, SfError] {
  parse_field_bytes(input, ParseLimits::default(), parse_list_cursor)
}

///|
/// Parses `input` as a List field value with custom limits.
pub fn parse_list_with_limits(
  input : String,
  limits : ParseLimits,
) -> Result[SfList, SfError] {
  parse_field_bytes(@utf8.encode(input, bom=false), limits, parse_list_cursor)
}
