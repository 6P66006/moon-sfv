///|
/// Parsing of Parameters (RFC 9651 §4.2.3.2).
///
/// Each parameter starts with `;`, optionally followed by SP, a key, and
/// an optional `=value`. A parameter with no explicit value is Boolean
/// true. Duplicate keys collapse to their last occurrence.
pub fn parse_parameters_cursor(
  cursor : Cursor,
  limits : ParseLimits,
) -> Result[Parameters, SfError] {
  let params = Parameters::new()
  while !cursor.is_end() {
    if cursor.peek() != Some(b';') {
      break
    }
    let _ = cursor.consume() // ';'
    cursor.skip_spaces()
    let key = match parse_key(cursor) {
      Err(e) => return Err(e)
      Ok(k) => k
    }
    let mut value = Boolean(true)
    if cursor.peek() == Some(b'=') {
      let _ = cursor.consume()
      value = match parse_bare_item_cursor(cursor, limits) {
        Err(e) => return Err(e)
        Ok(v) => v
      }
    }
    params.set(key, value)
    if params.len() > limits.max_parameters {
      return Err(err_at(cursor, TooManyParameters))
    }
  }
  Ok(params)
}
