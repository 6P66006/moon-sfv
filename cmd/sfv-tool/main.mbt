///|
/// `sfv-tool` — the RFC 9651 Structured Field Values command-line checker.
///
/// Usage:
///   sfv-tool parse --type <item|list|dictionary> INPUT
///   sfv-tool validate --type <item|list|dictionary> INPUT
///   sfv-tool canonicalize --type <item|list|dictionary> INPUT
///   sfv-tool roundtrip --type <item|list|dictionary> INPUT
///   sfv-tool conformance
///
/// INPUT is read from the single positional argument. Errors are printed to
/// stderr with the error kind and the byte offset, and the exit code is
/// non-zero. Byte sequences are rendered as hex; dates keep their raw
/// seconds value.
fn main {
  let args = @env.args()
  let rest = strip_program_name(args)
  if rest.is_empty() {
    print_usage()
    return
  }
  let command = rest[0]
  let tail = rest[1:].to_owned()
  match command {
    "conformance" => run_conformance_cmd(tail)
    "parse" => run_field_cmd(tail, "parse")
    "validate" => run_field_cmd(tail, "validate")
    "canonicalize" => run_field_cmd(tail, "canonicalize")
    "roundtrip" => run_field_cmd(tail, "roundtrip")
    "-h" | "--help" => print_usage()
    "help" => print_usage()
    "-V" | "--version" => print_version()
    _ => {
      println("sfv-tool: unknown command: \{command}")
      print_usage()
      cli_exit(2)
    }
  }
}

///|
/// The CLI version, kept in sync with `moon.mod`'s `version`.
const CLI_VERSION = "0.1.0"

///|
fn print_version() -> Unit {
  println("moon-sfv \{CLI_VERSION}")
  println(
    "RFC 9651 Structured Field Values parser, serializer, and conformance toolkit",
  )
}

///|
fn strip_program_name(args : Array[String]) -> Array[String] {
  if args.is_empty() {
    return []
  }
  let first = args[0]
  let known = [
    "parse", "validate", "canonicalize", "roundtrip", "conformance", "-h", "--help",
    "help", "-V", "--version",
  ]
  for k in known {
    if first == k {
      return args
    }
  }
  // First argument is the executable path; drop it.
  args[1:].to_owned()
}

///|
fn print_usage() -> Unit {
  println("sfv-tool - RFC 9651 Structured Field Values checker")
  println("")
  println("Usage:")
  println("  sfv-tool parse --type <item|list|dictionary> INPUT")
  println("  sfv-tool validate --type <item|list|dictionary> INPUT")
  println("  sfv-tool canonicalize --type <item|list|dictionary> INPUT")
  println("  sfv-tool roundtrip --type <item|list|dictionary> INPUT")
  println("  sfv-tool conformance")
  println("  sfv-tool --version")
  println("")
  println("  --type is required for field commands. INPUT is a single")
  println("  positional argument (reading from stdin is not supported yet).")
}

///|
/// Runs the `conformance` command.
fn run_conformance_cmd(_args : Array[String]) -> Unit {
  let stats = @lib.run_conformance()
  println("=== httpwg conformance report ===")
  println("required_valid_total:    \{stats.required_valid_total}")
  println("required_valid_passed:   \{stats.required_valid_passed}")
  println("required_invalid_total:  \{stats.required_invalid_total}")
  println("required_invalid_passed: \{stats.required_invalid_passed}")
  println("canonical_total:         \{stats.canonical_total}")
  println("canonical_passed:        \{stats.canonical_passed}")
  println("optional_total:          \{stats.optional_total}")
  println("optional_passed:         \{stats.optional_passed}")
  println("optional_failed:         \{stats.optional_failed}")
  println("expected_total:          \{stats.expected_total}")
  println("expected_passed:         \{stats.expected_passed}")
  println("failures:                \{stats.failures.length()}")
  for f in stats.failures {
    println("  - \{f}")
  }
  if stats.required_valid_passed == stats.required_valid_total &&
    stats.required_invalid_passed == stats.required_invalid_total &&
    stats.canonical_passed == stats.canonical_total {
    println("RESULT: PASS")
  } else {
    println("RESULT: FAIL")
    cli_exit(1)
  }
}

///|
/// Runs `parse`, `validate`, `canonicalize`, or `roundtrip`.
fn run_field_cmd(args : Array[String], command : String) -> Unit {
  let mut field_type : @lib.FieldType? = None
  let mut input : String? = None
  let mut i = 0
  while i < args.length() {
    let a = args[i]
    if a == "--type" {
      if i + 1 >= args.length() {
        println("sfv-tool: --type requires a value (item|list|dictionary)")
        cli_exit(2)
        return
      }
      let name = args[i + 1]
      field_type = @lib.FieldType::from_wire_name(name)
      if field_type is None {
        println("sfv-tool: unknown field type: \{name}")
        cli_exit(2)
        return
      }
      i = i + 2
    } else if a == "-h" || a == "--help" {
      print_usage()
      return
    } else {
      input = Some(a)
      i = i + 1
    }
  }
  let ft = match field_type {
    None => {
      println("sfv-tool: missing --type (item|list|dictionary)")
      cli_exit(2)
      return
    }
    Some(v) => v
  }
  let text = match input {
    None => {
      println(
        "sfv-tool: missing INPUT (reading from stdin is not supported yet)",
      )
      cli_exit(2)
      return
    }
    Some(v) => v
  }
  dispatch_field_command(command, ft, text)
}

///|
fn dispatch_field_command(
  command : String,
  ft : @lib.FieldType,
  input : String,
) -> Unit {
  match command {
    "validate" =>
      match parse_field(ft, input) {
        Err(e) => {
          println("INVALID: \{e.to_string()}")
          cli_exit(1)
        }
        Ok(_) => println("VALID")
      }
    "parse" =>
      match parse_field(ft, input) {
        Err(e) => {
          println("ERROR: \{e.to_string()}")
          cli_exit(1)
        }
        Ok(rendered) => println(rendered)
      }
    "canonicalize" =>
      match @lib.canonicalize(input, ft) {
        Err(e) => {
          println("ERROR: \{e.to_string()}")
          cli_exit(1)
        }
        Ok(sf) =>
          if sf.is_omitted() {
            println("(omitted)")
          } else {
            println(sf.to_string())
          }
      }
    "roundtrip" =>
      match @lib.canonicalize(input, ft) {
        Err(e) => {
          println("ERROR: \{e.to_string()}")
          cli_exit(1)
        }
        Ok(sf) => {
          if sf.is_omitted() {
            println("(omitted)")
            return
          }
          let wire = sf.to_string()
          // Re-parse and re-serialize: must be stable.
          match @lib.canonicalize(wire, ft) {
            Err(e) => {
              println("ROUNDTRIP FAILED: \{e.to_string()}")
              cli_exit(1)
            }
            Ok(sf2) => {
              if sf2.is_omitted() || sf2.to_string() != wire {
                println("ROUNDTRIP FAILED: not stable")
                cli_exit(1)
              }
              println(wire)
            }
          }
        }
      }
    _ => {
      println("sfv-tool: unknown command \{command}")
      cli_exit(2)
    }
  }
}

///|
/// Parses a field and renders the parsed structure for the `parse` command.
fn parse_field(
  ft : @lib.FieldType,
  input : String,
) -> Result[String, @lib.SfError] {
  match ft {
    @lib.Item =>
      match @lib.parse_item(input) {
        Err(e) => Err(e)
        Ok(v) => Ok(render_item(v))
      }
    @lib.List =>
      match @lib.parse_list(input) {
        Err(e) => Err(e)
        Ok(v) => Ok(render_list(v))
      }
    @lib.Dictionary =>
      match @lib.parse_dictionary(input) {
        Err(e) => Err(e)
        Ok(v) => Ok(render_dict(v))
      }
  }
}

///|
/// Renders a Byte Sequence as a hex string (no raw binary in output).
fn render_bytes(b : Bytes) -> String {
  let buf = @buffer.Buffer()
  buf.write_string_utf8("0x")
  for i in 0..<b.length() {
    let byte = b[i]
    buf.write_char_utf8(nibble_hex((byte.to_int() >> 4) & 0x0F))
    buf.write_char_utf8(nibble_hex(byte.to_int() & 0x0F))
  }
  @utf8.decode_lossy(buf.to_bytes())
}

///|
/// Maps a nibble (0-15) to its lowercase hex character.
fn nibble_hex(n : Int) -> Char {
  let code = if n < 10 { 0x30 + n } else { 0x61 + n - 10 }
  let ch = code.to_char()
  match ch {
    Some(c) => c
    None => '\u{FFFD}'
  }
}

///|
fn render_bare(b : @lib.BareItem) -> String {
  match b {
    @lib.Integer(v) => v.to_string()
    @lib.Decimal(d) =>
      match d.to_canonical_string() {
        Err(_) => "?"
        Ok(s) => s
      }
    @lib.StringItem(s) => "\"" + escape_json(s) + "\""
    @lib.Token(s) => s
    @lib.ByteSequence(bs) => render_bytes(bs)
    @lib.Boolean(v) => if v { "true" } else { "false" }
    @lib.Date(v) => "@" + v.to_string()
    @lib.DisplayString(s) => "%\"" + escape_json(s) + "\""
  }
}

///|
fn escape_json(s : String) -> String {
  let bytes = @utf8.encode(s, bom=false)
  let buf = @buffer.Buffer()
  for i in 0..<bytes.length() {
    let b = bytes[i]
    if b == b'"' {
      buf.write_string_utf8("\\\"")
    } else if b == b'\\' {
      buf.write_string_utf8("\\\\")
    } else {
      buf.write_byte(b)
    }
  }
  @utf8.decode_lossy(buf.to_bytes())
}

///|
fn render_params(p : @lib.Parameters) -> String {
  if p.len() == 0 {
    return "[]"
  }
  let mut out = "["
  for i in 0..<p.len() {
    let e = p.get_by_index(i)
    match e {
      None => ()
      Some(pe) => {
        if i > 0 {
          out = out + ", "
        }
        out = out + "\"" + escape_json(pe.key) + "\": " + render_bare(pe.value)
      }
    }
  }
  out + "]"
}

///|
fn render_item(it : @lib.Item) -> String {
  "{\"bare\": " +
  render_bare(it.bare) +
  ", \"parameters\": " +
  render_params(it.parameters) +
  "}"
}

///|
fn render_member(m : @lib.ListMember) -> String {
  match m {
    @lib.ItemMember(it) => render_item(it)
    @lib.InnerListMember(il) => {
      let mut out = "{\"inner_list\": ["
      for i in 0..<il.items.length() {
        if i > 0 {
          out = out + ", "
        }
        out = out + render_item(il.items[i])
      }
      out + "], \"parameters\": " + render_params(il.parameters) + "}"
    }
  }
}

///|
fn render_list(l : @lib.SfList) -> String {
  let mut out = "["
  for i in 0..<l.len() {
    if i > 0 {
      out = out + ", "
    }
    match l.get_by_index(i) {
      None => ()
      Some(m) => out = out + render_member(m)
    }
  }
  out + "]"
}

///|
fn render_dict(d : @lib.SfDictionary) -> String {
  let mut out = "{"
  for i in 0..<d.len() {
    if i > 0 {
      out = out + ", "
    }
    match d.get_by_index(i) {
      None => ()
      Some(e) =>
        out = out + "\"" + escape_json(e.key) + "\": " + render_member(e.value)
    }
  }
  out + "}"
}
