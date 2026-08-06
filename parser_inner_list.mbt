///|
/// Parsing of Inner Lists (RFC 9651 §4.2.1.2).
///
/// An Inner List is `"(" SP *[item *(SP item)] ")"` followed by its own
/// parameters. Items are separated by one or more spaces.
pub fn parse_inner_list_cursor(
  cursor : Cursor,
  limits : ParseLimits,
) -> Result[InnerList, SfError] {
  if !cursor.consume_if(b'(') {
    return Err(err_at(cursor, InvalidInnerList))
  }
  let items : Array[Item] = []
  while !cursor.is_end() {
    cursor.skip_spaces()
    if cursor.peek() == Some(b')') {
      let _ = cursor.consume()
      let parameters = match parse_parameters_cursor(cursor, limits) {
        Err(e) => return Err(e)
        Ok(v) => v
      }
      return Ok({ items, parameters })
    }
    let item = match parse_item_cursor(cursor, limits) {
      Err(e) => return Err(e)
      Ok(v) => v
    }
    items.push(item)
    if items.length() > limits.max_inner_list_items {
      return Err(err_at(cursor, TooManyMembers))
    }
    // After an item, the next character must be SP or ')'. This rejects
    // members that are not separated by whitespace.
    match cursor.peek() {
      None => return Err(err_at(cursor, InvalidInnerList))
      Some(b) =>
        if !(b == b' ' || b == b')') {
          return Err(err_at(cursor, InvalidInnerList))
        }
    }
  }
  Err(err_at(cursor, InvalidInnerList))
}
