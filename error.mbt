///|
/// Structured error type for all parsing, serialization, and
/// canonicalization failures in this crate.
///
/// The error carries a structured `kind`, a UTF-8 byte `offset` into the
/// original input, and a short human-readable `context`. Offsets are byte
/// offsets into the UTF-8 encoding of the input, not Unicode scalar counts.
pub(all) enum SfErrorKind {
  UnexpectedEnd
  UnexpectedByte(Byte)
  InvalidTopLevelType
  InvalidKey
  InvalidInteger
  IntegerOutOfRange
  InvalidDecimal
  DecimalOutOfRange
  InvalidString
  InvalidEscape
  InvalidToken
  InvalidByteSequence
  InvalidBase64
  InvalidBoolean
  InvalidDate
  InvalidDisplayString
  InvalidPercentEncoding
  InvalidUtf8
  InvalidParameter
  InvalidInnerList
  InvalidDictionary
  TrailingInput
  TooManyMembers
  TooManyParameters
  InputTooLarge
  SerializationError
} derive(Debug, Eq)

///|
pub(all) struct SfError {
  kind : SfErrorKind
  offset : Int
  context : String
} derive(Debug, Eq)

///|
/// Builds a structured error.
pub fn SfError::make(
  kind : SfErrorKind,
  offset : Int,
  context : String,
) -> SfError {
  { kind, offset, context }
}

///|
/// The category of the failure.
pub fn SfError::kind(self : SfError) -> SfErrorKind {
  self.kind
}

///|
/// The UTF-8 byte offset into the input at which the failure occurred.
pub fn SfError::offset(self : SfError) -> Int {
  self.offset
}

///|
/// A short description of the surrounding input.
pub fn SfError::context(self : SfError) -> String {
  self.context
}

///|
/// Renders a human-readable, single-line description of the error.
///
/// The context is truncated so that very large inputs are never echoed
/// back in full.
pub fn SfError::to_string(self : SfError) -> String {
  let kind_label = match self.kind {
    UnexpectedEnd => "unexpected end of input"
    UnexpectedByte(_) => "unexpected byte"
    InvalidTopLevelType => "invalid top-level structured type"
    InvalidKey => "invalid key"
    InvalidInteger => "invalid integer"
    IntegerOutOfRange => "integer out of range"
    InvalidDecimal => "invalid decimal"
    DecimalOutOfRange => "decimal out of range"
    InvalidString => "invalid string"
    InvalidEscape => "invalid escape sequence"
    InvalidToken => "invalid token"
    InvalidByteSequence => "invalid byte sequence"
    InvalidBase64 => "invalid base64"
    InvalidBoolean => "invalid boolean"
    InvalidDate => "invalid date"
    InvalidDisplayString => "invalid display string"
    InvalidPercentEncoding => "invalid percent encoding"
    InvalidUtf8 => "invalid UTF-8"
    InvalidParameter => "invalid parameter"
    InvalidInnerList => "invalid inner list"
    InvalidDictionary => "invalid dictionary"
    TrailingInput => "trailing input after value"
    TooManyMembers => "too many members"
    TooManyParameters => "too many parameters"
    InputTooLarge => "input exceeds configured size limit"
    SerializationError => "serialization error"
  }
  let ctx = truncate_for_display(self.context, 40)
  let suffix = if ctx.is_empty() { "" } else { ": near \"" + ctx + "\"" }
  kind_label + " at byte " + self.offset.to_string() + suffix
}

///|
/// Returns the label of an error kind without offset/context details.
pub fn SfErrorKind::label(self : SfErrorKind) -> String {
  let e = SfError::make(self, 0, "")
  e.to_string()
}

///|
fn truncate_for_display(s : String, limit : Int) -> String {
  if s.length() <= limit {
    return s
  }
  let cut = s[:limit].to_owned()
  cut + "..."
}

///|
/// Resource limits applied while parsing. RFC 9651 requires parsers to
/// support at least 1024 List/Dictionary members, 256 parameters, 1024
/// String characters, 512 Token characters, and 16384 decoded Byte
/// Sequence octets; the defaults below satisfy all of those while still
/// bounding hostile inputs.
pub(all) struct ParseLimits {
  max_input_bytes : Int
  max_members : Int
  max_parameters : Int
  max_string_bytes : Int
  max_inner_list_items : Int
  max_nesting_depth : Int
} derive(Debug, Eq)

///|
/// The default [`ParseLimits`], comfortably above every RFC requirement.
pub fn ParseLimits::default() -> ParseLimits {
  {
    max_input_bytes: 4 * 1024 * 1024,
    max_members: 100_000,
    max_parameters: 100_000,
    max_string_bytes: 1 * 1024 * 1024,
    max_inner_list_items: 100_000,
    max_nesting_depth: 8,
  }
}

///|
/// The three top-level Structured Fields types.
pub(all) enum FieldType {
  Item
  List
  Dictionary
} derive(Debug, Eq)

///|
/// The wire name of a field type, used by the CLI and the conformance
/// harness.
pub fn FieldType::wire_name(self : FieldType) -> String {
  match self {
    Item => "item"
    List => "list"
    Dictionary => "dictionary"
  }
}

///|
/// Parses a wire field-type name ("item", "list", "dictionary").
pub fn FieldType::from_wire_name(s : String) -> FieldType? {
  if s == "item" {
    return Some(Item)
  }
  if s == "list" {
    return Some(List)
  }
  if s == "dictionary" {
    return Some(Dictionary)
  }
  None
}
