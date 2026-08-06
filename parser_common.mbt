/// Shared parsing infrastructure: error construction and the `key` parser
/// (RFC 9651 §4.2.3.3), used by Parameters and Dictionary.

///|
/// Builds an [`SfError`] anchored at the cursor's current byte offset, with
/// a short surrounding-input context.
fn err_at(cursor : Cursor, kind : SfErrorKind) -> SfError {
  SfError::make(
    kind,
    cursor.position(),
    cursor.context_string(cursor.position(), 32),
  )
}

///|
/// Builds an [`SfError`] anchored at `offset` with an explicit context.
fn err_with(
  _cursor : Cursor,
  kind : SfErrorKind,
  offset : Int,
  context : String,
) -> SfError {
  SfError::make(kind, offset, context)
}

///|
/// Builds an end-of-input error at the cursor's position.
fn err_end(cursor : Cursor) -> SfError {
  SfError::make(
    UnexpectedEnd,
    cursor.position(),
    cursor.context_string(cursor.position(), 32),
  )
}

///|
/// Decodes a buffer of ASCII bytes into a String (all SFV wire text is
/// ASCII except decoded Display String content).
fn bytes_to_ascii(b : Bytes) -> String {
  @utf8.decode_lossy(b)
}

///|
/// Runs the top-level field parsing algorithm (RFC 9651 §4.2): discard
/// leading SP, parse by the given function, discard trailing SP, and
/// require that nothing remains. This enforces the field-value boundary
/// and produces [`TrailingInput`] errors for stray characters.
pub fn[T] parse_field_bytes(
  input : Bytes,
  limits : ParseLimits,
  parse_fn : (Cursor, ParseLimits) -> Result[T, SfError],
) -> Result[T, SfError] {
  if input.length() > limits.max_input_bytes {
    return Err(SfError::make(InputTooLarge, 0, "input exceeds max_input_bytes"))
  }
  let cursor = Cursor::new(input)
  cursor.skip_spaces()
  match parse_fn(cursor, limits) {
    Err(e) => Err(e)
    Ok(value) => {
      cursor.skip_spaces()
      if !cursor.is_end() {
        return Err(err_at(cursor, TrailingInput))
      }
      Ok(value)
    }
  }
}

///|
/// Parses an Item or Inner List (RFC 9651 §4.2.1.1).
pub fn parse_item_or_inner_list_cursor(
  cursor : Cursor,
  limits : ParseLimits,
) -> Result[ListMember, SfError] {
  if cursor.peek() == Some(b'(') {
    return parse_inner_list_cursor(cursor, limits).map(il => InnerListMember(il))
  }
  parse_item_cursor(cursor, limits).map(it => ItemMember(it))
}

///|
/// Parses a Structured Fields `key` (RFC 9651 §4.2.3.3).
///
/// Grammar: `key = ( lcalpha / "*" ) *( lcalpha / DIGIT / "_" / "-" / "." / "*" )`.
pub fn parse_key(cursor : Cursor) -> Result[String, SfError] {
  let first = cursor.peek()
  match first {
    None => Err(err_end(cursor))
    Some(b) =>
      if !is_key_start(b) {
        Err(err_at(cursor, InvalidKey))
      } else {
        let _ = cursor.consume()
        let buf = @buffer.Buffer(size_hint=8)
        buf.write_byte(b)
        while true {
          let next = cursor.peek()
          match next {
            None => break
            Some(b2) => {
              if !is_key_char(b2) {
                break
              }
              let _ = cursor.consume()
              buf.write_byte(b2)
            }
          }
        }
        Ok(bytes_to_ascii(buf.to_bytes()))
      }
  }
}
