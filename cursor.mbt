///|
/// A bounds-checked cursor over the UTF-8 byte encoding of a structured
/// field value.
///
/// All reads are checked against the end of the input; index arithmetic
/// never reaches the underlying array without a length check first. The
/// cursor's position is reported in UTF-8 byte offsets, which is exactly
/// the unit used for error offsets in [`SfError`].
pub struct Cursor {
  input : Bytes
  mut position : Int
}

///|
/// Creates a cursor over `input`.
pub fn Cursor::new(input : Bytes) -> Cursor {
  { input, position: 0 }
}

///|
/// The current UTF-8 byte offset.
pub fn Cursor::position(self : Cursor) -> Int {
  self.position
}

///|
/// Number of bytes remaining after the current position.
pub fn Cursor::remaining(self : Cursor) -> Int {
  self.input.length() - self.position
}

///|
/// Whether the cursor has reached the end of the input.
pub fn Cursor::is_end(self : Cursor) -> Bool {
  self.position >= self.input.length()
}

///|
/// The byte at the current position, or `None` at end of input.
pub fn Cursor::peek(self : Cursor) -> Byte? {
  if self.is_end() {
    return None
  }
  Some(self.input[self.position])
}

///|
/// The byte `n` bytes ahead of the current position, or `None` if that
/// offset is past the end of the input.
pub fn Cursor::peek_n(self : Cursor, n : Int) -> Byte? {
  let idx = self.position + n
  if n < 0 || idx >= self.input.length() {
    return None
  }
  Some(self.input[idx])
}

///|
/// Reads and consumes the byte at the current position, or `None` at end
/// of input.
pub fn Cursor::consume(self : Cursor) -> Byte? {
  if self.is_end() {
    return None
  }
  let b = self.input[self.position]
  self.position = self.position + 1
  Some(b)
}

///|
/// Consumes `b` if it is the next byte, returning whether it matched.
pub fn Cursor::consume_if(self : Cursor, b : Byte) -> Bool {
  if !self.is_end() && self.input[self.position] == b {
    self.position = self.position + 1
    return true
  }
  false
}

///|
/// Alias of [`Cursor::consume_if`] for call sites that read more naturally
/// with "expect".
pub fn Cursor::expect(self : Cursor, b : Byte) -> Bool {
  self.consume_if(b)
}

///|
/// Skips SP (0x20) characters. The Item grammar only permits SP, not HTAB.
pub fn Cursor::skip_spaces(self : Cursor) -> Unit {
  while !self.is_end() && self.input[self.position] == b' ' {
    self.position = self.position + 1
  }
}

///|
/// Skips OWS (SP / HTAB). Used between List and Dictionary members, where
/// the RFC allows tab characters.
pub fn Cursor::skip_ows(self : Cursor) -> Unit {
  while !self.is_end() && is_ows(self.input[self.position]) {
    self.position = self.position + 1
  }
}

///|
/// Returns a copy of the input bytes in the half-open range `[start, end)`.
/// Clamps out-of-range bounds.
pub fn Cursor::slice(self : Cursor, start : Int, end : Int) -> Bytes {
  let lo = start.max(0)
  let hi = end.min(self.input.length())
  if hi <= lo {
    return Bytes::new(0)
  }
  self.input.view(start=lo, end=hi).to_owned()
}

///|
/// The full input behind the cursor, copied.
pub fn Cursor::input(self : Cursor) -> Bytes {
  self.input
}

///|
/// The total length of the input, without copying.
pub fn Cursor::input_length(self : Cursor) -> Int {
  self.input.length()
}

///|
/// Saves the current position for later restoration.
pub fn Cursor::checkpoint(self : Cursor) -> Int {
  self.position
}

///|
/// Restores a previously saved position.
pub fn Cursor::restore(self : Cursor, pos : Int) -> Unit {
  if pos >= 0 && pos <= self.input.length() {
    self.position = pos
  }
}

///|
/// Reads the byte at absolute offset `offset`, or `None` out of bounds.
pub fn Cursor::at(self : Cursor, offset : Int) -> Byte? {
  if offset < 0 || offset >= self.input.length() {
    return None
  }
  Some(self.input[offset])
}

///|
/// Builds a short, lossy-decoded display context starting at byte `offset`
/// (see [`SfError::context`]). The slice is capped so errors never echo an
/// unbounded amount of input.
pub fn Cursor::context_string(
  self : Cursor,
  offset : Int,
  limit : Int,
) -> String {
  if self.input.length() == 0 {
    return ""
  }
  let lo = offset.min(self.input.length()).max(0)
  let hi = (lo + limit).min(self.input.length())
  let slice = self.input.view(start=lo, end=hi).to_owned()
  @utf8.decode_lossy(slice)
}
