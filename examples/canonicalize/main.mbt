///|
/// Demonstrates canonicalization: parse-then-serialize normalizes leading
/// zeros, trailing zeros, negative zero, explicit `=?1`, and whitespace.
///
/// Run: `moon run examples/canonicalize`
fn main {
  let inputs = [
    ("0002", @lib.Item),
    ("-01", @lib.Item),
    ("4.500", @lib.Item),
    ("5; a=?1", @lib.Item),
    ("1, 42", @lib.List),
    ("a, b;c=d", @lib.Dictionary),
    ("a=1, a=2", @lib.Dictionary),
  ]
  for pair in inputs {
    let (input, ft) = pair
    match @lib.canonicalize(input, ft) {
      Err(e) => println("\{input}  ->  ERROR: \{e.to_string()}")
      Ok(sf) => {
        let out = if sf.is_omitted() { "(omitted)" } else { sf.to_string() }
        println("\{input}  ->  \{out}")
      }
    }
  }
}
