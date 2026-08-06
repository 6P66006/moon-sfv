///|
/// Parses an Item field value (RFC 9651 §3.3).
///
/// Run: `moon run examples/parse_item`
fn main {
  let input = "5; foo=bar; a=?0; b"
  match @lib.parse_item(input) {
    Err(e) => println("parse failed: \{e.to_string()}")
    Ok(item) => {
      println("parsed item from: \{input}")
      match item.bare {
        @lib.Integer(v) => println("  bare item: Integer(\{v.to_string()})")
        @lib.Token(t) => println("  bare item: Token(\{t})")
        _ => println("  bare item: (see debug)")
      }
      println("  parameter count: \{item.parameters.len()}")
      for key in item.parameters.keys() {
        match item.parameters.get_by_key(key) {
          None => ()
          Some(value) =>
            match value {
              @lib.Boolean(v) => println("    \{key} = Boolean(\{v})")
              @lib.Token(t) => println("    \{key} = Token(\{t})")
              _ => println("    \{key} = (value)")
            }
        }
      }
      // Round-trip back to the canonical wire form.
      match @lib.serialize_item(item) {
        Err(e) => println("serialize failed: \{e.to_string()}")
        Ok(wire) => println("canonical wire: \{wire}")
      }
    }
  }
}
