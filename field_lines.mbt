/// Handling of Structured Fields spread across multiple HTTP field lines.
///
/// RFC 9651 §4.2 requires that all field lines for a field name be combined
/// into one comma-separated field value before parsing. This module exposes
/// that combination plus type-specific entry points that operate on the
/// combined value.

///|
/// Combines field lines with `", "`, matching the combining convention the
/// httpwg `structured-field-tests` suite assumes. Empty lines contribute
/// empty members (which fail to parse, per the RFC's strict behavior).
pub fn combine_field_lines(lines : Array[String]) -> String {
  let buf = @buffer.Buffer(size_hint=64)
  for i in 0..<lines.length() {
    if i > 0 {
      buf.write_string_utf8(", ")
    }
    buf.write_string_utf8(lines[i])
  }
  bytes_to_ascii(buf.to_bytes())
}

///|
/// Parses an Item field that may be spread across multiple lines.
pub fn parse_item_lines(lines : Array[String]) -> Result[Item, SfError] {
  parse_item(combine_field_lines(lines))
}

///|
/// Parses a List field that may be spread across multiple lines.
pub fn parse_list_lines(lines : Array[String]) -> Result[SfList, SfError] {
  parse_list(combine_field_lines(lines))
}

///|
/// Parses a Dictionary field that may be spread across multiple lines.
pub fn parse_dictionary_lines(
  lines : Array[String],
) -> Result[SfDictionary, SfError] {
  parse_dictionary(combine_field_lines(lines))
}
