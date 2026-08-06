///|
/// Demonstrates the structured error system: kind, byte offset, and a
/// bounded context snippet.
///
/// Run: `moon run examples/errors`
fn show(input : String) -> Unit {
  match @lib.parse_item(input) {
    Err(e) => {
      println("input : \"\{input}\"")
      println("kind  : \{e.kind().label()}")
      println("offset: \{e.offset()}")
      println("detail: \{e.to_string()}")
    }
    Ok(_) => println("input : \"\{input}\"  ->  valid")
  }
  println("")
}

///|
fn main {
  show("abc, def") // trailing input after a Token
  show("1.1234") // decimal with four fractional digits
  show("\"unterminated") // unclosed String
  show("%\"bad%zz\"") // invalid percent-encoding in Display String
  show(":not base64!:") // invalid Byte Sequence
  show("5; a=?1") // valid, for contrast
}
