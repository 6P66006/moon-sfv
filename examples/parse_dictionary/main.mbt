///|
/// Parses a Dictionary field value (RFC 9651 §3.2), including implicit
/// Boolean true members and inner-list members.
///
/// Run: `moon run examples/parse_dictionary`
fn main {
  let input = "en=\"Applepie\", da=:w4ZibGV0w6ZydGU=:, b, c; foo=bar"
  match @lib.parse_dictionary(input) {
    Err(e) => println("parse failed: \{e.to_string()}")
    Ok(dict) => {
      println("parsed dictionary from: \{input}")
      println("  member count: \{dict.len()}")
      for key in dict.keys() {
        match dict.get_by_key(key) {
          None => ()
          Some(m) =>
            match m {
              @lib.ItemMember(item) => {
                let bare = match item.bare {
                  @lib.StringItem(s) => "String(\{s})"
                  @lib.Boolean(v) => "Boolean(\{v})"
                  other => @debug.to_string(other)
                }
                println(
                  "  \{key} = \{bare} (\{item.parameters.len()} param(s))",
                )
              }
              @lib.InnerListMember(il) =>
                println("  \{key} = inner list (\{il.len()} item(s))")
            }
        }
      }
      match @lib.serialize_dictionary(dict) {
        Err(e) => println("serialize failed: \{e.to_string()}")
        Ok(sf) => println("canonical wire: \{sf.to_string()}")
      }
    }
  }
}
