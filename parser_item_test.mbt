///|
/// Tests for Item parsing: integers, decimals, strings, tokens, byte
/// sequences, booleans, dates, display strings, and item parameters.
fn ok_item(input : String) -> Item raise Failure {
  match @moon-sfv.parse_item(input) {
    Err(e) => fail("expected Ok, got \{e.to_string()}")
    Ok(v) => v
  }
}

///|
fn is_err(input : String) -> Bool {
  @moon-sfv.parse_item(input) is Err(_)
}

///|
test "integer parse normal" {
  @test.assert_eq(ok_item("42").bare, @moon-sfv.BareItem::integer(42L))
  @test.assert_eq(ok_item("0").bare, @moon-sfv.BareItem::integer(0L))
  @test.assert_eq(ok_item("-42").bare, @moon-sfv.BareItem::integer(-42L))
  // negative zero normalizes to zero
  @test.assert_eq(ok_item("-0").bare, @moon-sfv.BareItem::integer(0L))
}

///|
test "integer parse leading zeros" {
  @test.assert_eq(ok_item("042").bare, @moon-sfv.BareItem::integer(42L))
  @test.assert_eq(ok_item("-042").bare, @moon-sfv.BareItem::integer(-42L))
  @test.assert_eq(ok_item("00").bare, @moon-sfv.BareItem::integer(0L))
}

///|
test "integer boundaries" {
  // 15 digits is the maximum
  @test.assert_eq(
    ok_item("123456789012345").bare,
    @moon-sfv.BareItem::integer(123456789012345L),
  )
  @test.assert_eq(
    ok_item("-123456789012345").bare,
    @moon-sfv.BareItem::integer(-123456789012345L),
  )
  @test.assert_eq(
    ok_item("999999999999999").bare,
    @moon-sfv.BareItem::integer(999999999999999L),
  )
  @test.assert_eq(
    ok_item("-999999999999999").bare,
    @moon-sfv.BareItem::integer(-999999999999999L),
  )
  // 16 digits must fail
  assert_true(is_err("1234567890123456"))
  assert_true(is_err("-1234567890123456"))
  assert_true(is_err("1000000000000000"))
}

///|
test "integer invalid forms" {
  assert_true(is_err("--0"))
  assert_true(is_err("-"))
  assert_true(is_err("-a23"))
  assert_true(is_err("4-2"))
  assert_true(is_err("- 42"))
  assert_true(is_err(""))
}

///|
test "decimal parse normal" {
  @test.assert_eq(
    ok_item("1.23").bare,
    @moon-sfv.BareItem::decimal(@moon-sfv.SfDecimal::new(123L, 2)),
  )
  @test.assert_eq(
    ok_item("-1.23").bare,
    @moon-sfv.BareItem::decimal(@moon-sfv.SfDecimal::new(-123L, 2)),
  )
  @test.assert_eq(
    ok_item("4.5").bare,
    @moon-sfv.BareItem::decimal(@moon-sfv.SfDecimal::new(45L, 1)),
  )
  // negative zero decimal normalizes to zero
  @test.assert_eq(
    ok_item("-0.0").bare,
    @moon-sfv.BareItem::decimal(@moon-sfv.SfDecimal::new(0L, 1)),
  )
  // trailing zeros are preserved in the abstract value
  @test.assert_eq(
    ok_item("1.230").bare,
    @moon-sfv.BareItem::decimal(@moon-sfv.SfDecimal::new(1230L, 3)),
  )
  @test.assert_eq(
    ok_item("123456789012.1").bare,
    @moon-sfv.BareItem::decimal(@moon-sfv.SfDecimal::new(1234567890121L, 1)),
  )
}

///|
test "decimal digit limits" {
  // three fractional digits ok
  @test.assert_eq(
    ok_item("1.123").bare,
    @moon-sfv.BareItem::decimal(@moon-sfv.SfDecimal::new(1123L, 3)),
  )
  // four fractional digits fail
  assert_true(is_err("1.1234"))
  assert_true(is_err("-1.1234"))
  // trailing dot fails
  assert_true(is_err("1."))
  // thirteen integer digits fail
  assert_true(is_err("1234567890123.0"))
  assert_true(is_err("-1234567890123.0"))
  // twelve integer digits are the maximum
  @test.assert_eq(
    ok_item("999999999999.9").bare,
    @moon-sfv.BareItem::decimal(@moon-sfv.SfDecimal::new(9999999999999L, 1)),
  )
}

///|
test "decimal invalid forms" {
  assert_true(is_err("1. 23"))
  assert_true(is_err("1 .23"))
  assert_true(is_err("- 1.23"))
  assert_true(is_err("1.5.4"))
  assert_true(is_err("1..4"))
}

///|
test "string parse" {
  @test.assert_eq(
    ok_item("\"foo bar\"").bare,
    @moon-sfv.BareItem::string_item("foo bar"),
  )
  @test.assert_eq(ok_item("\"\"").bare, @moon-sfv.BareItem::string_item(""))
  @test.assert_eq(
    ok_item("\"   \"").bare,
    @moon-sfv.BareItem::string_item("   "),
  )
  // escaping
  @test.assert_eq(
    ok_item("\"foo \\\"bar\\\" \\\\ baz\"").bare,
    @moon-sfv.BareItem::string_item("foo \"bar\" \\ baz"),
  )
}

///|
test "string invalid forms" {
  assert_true(is_err("\"foo"))
  assert_true(is_err("\"foo \\\""))
  assert_true(is_err("\"foo \\"))
  assert_true(is_err("\"foo \\,\""))
  assert_true(is_err("\"tab\t\""))
  assert_true(is_err("\"nl\n\""))
  assert_true(is_err("'foo'"))
  // non-ASCII characters are not allowed in Strings
  assert_true(is_err("\"f\u7711\u7711\""))
  assert_true(is_err("\"\u{7f}\""))
}

///|
test "token parse" {
  @test.assert_eq(ok_item("foo").bare, @moon-sfv.BareItem::token("foo"))
  @test.assert_eq(ok_item("fooBar").bare, @moon-sfv.BareItem::token("fooBar"))
  @test.assert_eq(ok_item("FooBar").bare, @moon-sfv.BareItem::token("FooBar"))
  @test.assert_eq(
    ok_item("a_b-c.d3:f%00/*").bare,
    @moon-sfv.BareItem::token("a_b-c.d3:f%00/*"),
  )
  @test.assert_eq(ok_item("*foo").bare, @moon-sfv.BareItem::token("*foo"))
}

///|
test "token invalid forms" {
  // token cannot start with a digit
  assert_true(is_err("1foo"))
  assert_true(is_err("_foo"))
  assert_true(is_err(".foo"))
  assert_true(is_err(""))
  // a single non-tchar character terminates the token; the remainder must
  // be valid item syntax or the whole parse fails
  assert_true(is_err("foo bar"))
}

///|
test "byte sequence parse" {
  let parsed = ok_item(":aGVsbG8=:").bare
  match parsed {
    @moon-sfv.ByteSequence(b) =>
      @test.assert_eq(b, @utf8.encode("hello", bom=false))
    _ => assert_true(false)
  }
  // empty byte sequence
  match ok_item("::").bare {
    @moon-sfv.ByteSequence(b) => @test.assert_eq(b.length(), 0)
    _ => assert_true(false)
  }
  // missing padding is tolerated (can_fail in the official suite)
  match ok_item(":aGVsbG8:").bare {
    @moon-sfv.ByteSequence(b) =>
      @test.assert_eq(b, @utf8.encode("hello", bom=false))
    _ => assert_true(false)
  }
}

///|
test "byte sequence invalid forms" {
  assert_true(is_err(":=aGVsbG8=:"))
  assert_true(is_err(":a=GVsbG8=:"))
  assert_true(is_err(":aGVsbG8.:"))
  assert_true(is_err(":aGVsbG8="))
  assert_true(is_err(":aGVsb G8=:"))
  assert_true(is_err(":    :"))
  assert_true(is_err(":aGVsbG!8=:"))
  assert_true(is_err(":aGVsbG8=!:"))
  assert_true(is_err(":aGVsbG8=:junk"))
  assert_true(is_err(":"))
  assert_true(is_err(":_-Ah:")) // base64url chars are not valid
}

///|
test "boolean parse" {
  @test.assert_eq(ok_item("?1").bare, @moon-sfv.BareItem::boolean(true))
  @test.assert_eq(ok_item("?0").bare, @moon-sfv.BareItem::boolean(false))
}

///|
test "boolean invalid forms" {
  assert_true(is_err("?Q"))
  assert_true(is_err("? 1"))
  assert_true(is_err("?-0"))
  assert_true(is_err("?T"))
  assert_true(is_err("?F"))
  assert_true(is_err("?t"))
  assert_true(is_err("?f"))
  assert_true(is_err("?True"))
  assert_true(is_err("?"))
}

///|
test "date parse" {
  @test.assert_eq(ok_item("@0").bare, @moon-sfv.BareItem::date(0L))
  @test.assert_eq(
    ok_item("@1659578233").bare,
    @moon-sfv.BareItem::date(1659578233L),
  )
  @test.assert_eq(
    ok_item("@-1659578233").bare,
    @moon-sfv.BareItem::date(-1659578233L),
  )
  @test.assert_eq(
    ok_item("@253402214400").bare,
    @moon-sfv.BareItem::date(253402214400L),
  )
  // negative zero date normalizes
  @test.assert_eq(ok_item("@-0").bare, @moon-sfv.BareItem::date(0L))
  // dates support the full 15-digit integer range syntactically
  @test.assert_eq(
    ok_item("@999999999999999").bare,
    @moon-sfv.BareItem::date(999999999999999L),
  )
}

///|
test "date invalid forms" {
  assert_true(is_err("@"))
  assert_true(is_err("@-"))
  assert_true(is_err("@ 12345678"))
  assert_true(is_err("@abc"))
  assert_true(is_err("@1.5"))
  assert_true(is_err("@1659578233.12"))
  assert_true(is_err("@1000000000000000"))
}

///|
test "display string parse" {
  @test.assert_eq(
    ok_item("%\"foo bar\"").bare,
    @moon-sfv.BareItem::display_string("foo bar"),
  )
  @test.assert_eq(ok_item("%\"\"").bare, @moon-sfv.BareItem::display_string(""))
  // percent-encoded UTF-8
  @test.assert_eq(
    ok_item("%\"f%c3%bc%c3%bc\"").bare,
    @moon-sfv.BareItem::display_string("f\u00fc\u00fc"),
  )
  // quoted and backslash are percent-encoded on the wire but decode back
  @test.assert_eq(
    ok_item("%\"foo %22bar%22 %5c baz\"").bare,
    @moon-sfv.BareItem::display_string("foo \"bar\" \\ baz"),
  )
  // over-encoded ASCII is normalized on serialization but parses fine
  @test.assert_eq(
    ok_item("%\"%61\"").bare,
    @moon-sfv.BareItem::display_string("a"),
  )
  // BOM is preserved as a character
  @test.assert_eq(
    ok_item("%\"BOM: %ef%bb%bf\"").bare,
    @moon-sfv.BareItem::display_string("BOM: \ufeff"),
  )
}

///|
test "display string invalid forms" {
  assert_true(is_err("%\"f%C3%BC%c3%bc\"")) // uppercase hex is rejected
  assert_true(is_err("%\"f\u7709\u7709\"")) // unescaped non-ASCII
  assert_true(is_err("%\"\t\""))
  assert_true(is_err("%\"\n\""))
  assert_true(is_err("%'foo'"))
  assert_true(is_err("%foo"))
  assert_true(is_err("%foo\""))
  assert_true(is_err("%\"foo"))
  assert_true(is_err("%\"foo %a"))
  assert_true(is_err("%\"%c3%28\"")) // invalid UTF-8
  assert_true(is_err("%\"%a0%a1\"")) // invalid UTF-8
  assert_true(is_err("%\"%g0%1w\"")) // invalid hex
  assert_true(is_err("%\"%\"")) // truncated escape
}

///|
test "item parameters" {
  let it = ok_item("5; foo=bar")
  @test.assert_eq(it.bare, @moon-sfv.BareItem::integer(5L))
  @test.assert_eq(
    it.parameters.get_by_key("foo"),
    Some(@moon-sfv.BareItem::token("bar")),
  )
  // implicit true parameter
  let it2 = ok_item("5; a")
  @test.assert_eq(
    it2.parameters.get_by_key("a"),
    Some(@moon-sfv.BareItem::boolean(true)),
  )
  // explicit true parameter parses to the same value
  let it3 = ok_item("5; a=?1")
  @test.assert_eq(
    it3.parameters.get_by_key("a"),
    Some(@moon-sfv.BareItem::boolean(true)),
  )
  // explicit false
  let it4 = ok_item("5; a=?0")
  @test.assert_eq(
    it4.parameters.get_by_key("a"),
    Some(@moon-sfv.BareItem::boolean(false)),
  )
  // multiple parameters preserve order
  let it5 = ok_item("5; a=1; b=2; cde_456")
  @test.assert_eq(it5.parameters.keys(), ["a", "b", "cde_456"])
}

///|
test "duplicate parameter keys keep last value" {
  let it = ok_item("5; a=1; b=2; a=9")
  @test.assert_eq(it.parameters.len(), 2)
  @test.assert_eq(it.parameters.keys(), ["a", "b"])
  @test.assert_eq(
    it.parameters.get_by_key("a"),
    Some(@moon-sfv.BareItem::integer(9L)),
  )
}

///|
test "item parameters invalid" {
  // parameters must start with a valid key character
  assert_true(is_err("5; 1a"))
  // uppercase parameter keys are rejected
  assert_true(is_err("5; A=1"))
}

///|
test "item trailing input" {
  assert_true(is_err("5 6"))
  assert_true(is_err("5,"))
  assert_true(is_err("5 x"))
}

///|
test "item top-level whitespace" {
  // leading and trailing SP is allowed
  @test.assert_eq(ok_item("  1  ").bare, @moon-sfv.BareItem::integer(1L))
  @test.assert_eq(ok_item("     1  ").bare, @moon-sfv.BareItem::integer(1L))
  // leading/trailing HTAB is not allowed at the item level
  assert_true(is_err(" \t 1"))
  assert_true(is_err("1 \t "))
}

///|
test "item empty fails" {
  assert_true(is_err(""))
}
