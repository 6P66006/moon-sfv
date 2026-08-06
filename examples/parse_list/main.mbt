///|
/// Parses a List field value (RFC 9651 §3.1), including inner lists.
///
/// Run: `moon run examples/parse_list`
fn main {
  let input = "(\"foo\" \"bar\");lvl=5, sugar, tea"
  match @lib.parse_list(input) {
    Err(e) => println("parse failed: \{e.to_string()}")
    Ok(list) => {
      println("parsed list from: \{input}")
      println("  member count: \{list.len()}")
      for i in 0..<list.len() {
        match list.get_by_index(i) {
          None => ()
          Some(m) =>
            match m {
              @lib.ItemMember(item) => {
                let s = match item.bare {
                  @lib.Token(t) => "Token(\{t})"
                  @lib.StringItem(s) => "String(\{s})"
                  other => @debug.to_string(other)
                }
                println("  [\{i}] item: \{s}")
              }
              @lib.InnerListMember(il) =>
                println(
                  "  [\{i}] inner list with \{il.len()} item(s), \{il.parameters.len()} parameter(s)",
                )
            }
        }
      }
      match @lib.serialize_list(list) {
        Err(e) => println("serialize failed: \{e.to_string()}")
        Ok(sf) => println("canonical wire: \{sf.to_string()}")
      }
    }
  }
}
