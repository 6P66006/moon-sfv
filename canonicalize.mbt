/// Canonicalization: `parse` followed by a strict serialization, producing
/// the canonical wire form of a field value (RFC 9651 §4.1). This is a
/// lossless normalization in the sense that
/// `parse(serialize(value))` is semantically equal to `value`, and
/// `canonicalize(canonicalize(x))` equals `canonicalize(x)`.

///|
/// Canonicalizes a field value of the given type.
pub fn canonicalize(
  input : String,
  field_type : FieldType,
) -> Result[SerializedField, SfError] {
  match field_type {
    Item =>
      match parse_item(input) {
        Err(e) => Err(e)
        Ok(v) =>
          match serialize_item(v) {
            Err(e) => Err(e)
            Ok(s) => Ok(Value(s))
          }
      }
    List =>
      match parse_list(input) {
        Err(e) => Err(e)
        Ok(v) => serialize_list(v)
      }
    Dictionary =>
      match parse_dictionary(input) {
        Err(e) => Err(e)
        Ok(v) => serialize_dictionary(v)
      }
  }
}

///|
/// Canonicalizes an Item field value.
pub fn canonicalize_item(input : String) -> Result[SerializedField, SfError] {
  canonicalize(input, Item)
}

///|
/// Canonicalizes a List field value.
pub fn canonicalize_list(input : String) -> Result[SerializedField, SfError] {
  canonicalize(input, List)
}

///|
/// Canonicalizes a Dictionary field value.
pub fn canonicalize_dictionary(
  input : String,
) -> Result[SerializedField, SfError] {
  canonicalize(input, Dictionary)
}

///|
/// Convenience accessors for [`SerializedField`].
pub fn SerializedField::to_string(self : SerializedField) -> String {
  match self {
    Omit => ""
    Value(s) => s
  }
}

///|
/// Whether the field is omitted entirely.
pub fn SerializedField::is_omitted(self : SerializedField) -> Bool {
  match self {
    Omit => true
    Value(_) => false
  }
}
