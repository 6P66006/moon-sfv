///|
/// Tests for canonical serialization of every type and the public
/// `serialize_*` entry points.
fn ser_item_str(item : Item) -> String {
  match @moon-sfv.serialize_item(item) {
    Err(e) => "ERR:\{e.to_string()}"
    Ok(s) => s
  }
}

///|
test "serialize integer" {
  let it = @moon-sfv.Item::of(@moon-sfv.BareItem::integer(42L))
  @test.assert_eq(ser_item_str(it), "42")
  @test.assert_eq(
    ser_item_str(@moon-sfv.Item::of(@moon-sfv.BareItem::integer(-42L))),
    "-42",
  )
  @test.assert_eq(
    ser_item_str(@moon-sfv.Item::of(@moon-sfv.BareItem::integer(0L))),
    "0",
  )
  // out of range fails
  let too_big = @moon-sfv.Item::of(
    @moon-sfv.BareItem::integer(1_000_000_000_000_000L),
  )
  match @moon-sfv.serialize_item(too_big) {
    Err(e) => @test.assert_eq(e.kind(), @moon-sfv.SerializationError)
    Ok(_) => assert_true(false)
  }
}

///|
test "serialize decimal" {
  @test.assert_eq(
    ser_item_str(
      @moon-sfv.Item::of(
        @moon-sfv.BareItem::decimal(@moon-sfv.SfDecimal::new(45L, 1)),
      ),
    ),
    "4.5",
  )
  // rounding ties-to-even
  @test.assert_eq(
    ser_item_str(
      @moon-sfv.Item::of(
        @moon-sfv.BareItem::decimal(@moon-sfv.SfDecimal::new(15L, 4)),
      ),
    ),
    "0.002",
  )
  @test.assert_eq(
    ser_item_str(
      @moon-sfv.Item::of(
        @moon-sfv.BareItem::decimal(@moon-sfv.SfDecimal::new(-15L, 4)),
      ),
    ),
    "-0.002",
  )
}

///|
test "serialize string escaping" {
  @test.assert_eq(
    ser_item_str(
      @moon-sfv.Item::of(@moon-sfv.BareItem::string_item("foo \"bar\" \\ baz")),
    ),
    "\"foo \\\"bar\\\" \\\\ baz\"",
  )
  @test.assert_eq(
    ser_item_str(@moon-sfv.Item::of(@moon-sfv.BareItem::string_item(""))),
    "\"\"",
  )
  // non-visible characters fail serialization
  let bad = @moon-sfv.Item::of(@moon-sfv.BareItem::string_item("a\nb"))
  match @moon-sfv.serialize_item(bad) {
    Err(e) => @test.assert_eq(e.kind(), @moon-sfv.SerializationError)
    Ok(_) => assert_true(false)
  }
}

///|
test "serialize token" {
  @test.assert_eq(
    ser_item_str(@moon-sfv.Item::of(@moon-sfv.BareItem::token("foo/bar:baz"))),
    "foo/bar:baz",
  )
  // a token with an invalid character fails
  let bad = @moon-sfv.Item::of(@moon-sfv.BareItem::token("foo bar"))
  match @moon-sfv.serialize_item(bad) {
    Err(e) => @test.assert_eq(e.kind(), @moon-sfv.SerializationError)
    Ok(_) => assert_true(false)
  }
  let bad2 = @moon-sfv.Item::of(@moon-sfv.BareItem::token("1abc"))
  match @moon-sfv.serialize_item(bad2) {
    Err(e) => @test.assert_eq(e.kind(), @moon-sfv.SerializationError)
    Ok(_) => assert_true(false)
  }
}

///|
test "serialize byte sequence" {
  let bs = @utf8.encode("pretend this is binary content.", bom=false)
  @test.assert_eq(
    ser_item_str(@moon-sfv.Item::of(@moon-sfv.BareItem::byte_sequence(bs))),
    ":cHJldGVuZCB0aGlzIGlzIGJpbmFyeSBjb250ZW50Lg==:",
  )
}

///|
test "serialize boolean" {
  @test.assert_eq(
    ser_item_str(@moon-sfv.Item::of(@moon-sfv.BareItem::boolean(true))),
    "?1",
  )
  @test.assert_eq(
    ser_item_str(@moon-sfv.Item::of(@moon-sfv.BareItem::boolean(false))),
    "?0",
  )
}

///|
test "serialize date" {
  @test.assert_eq(
    ser_item_str(@moon-sfv.Item::of(@moon-sfv.BareItem::date(1659578233L))),
    "@1659578233",
  )
  @test.assert_eq(
    ser_item_str(@moon-sfv.Item::of(@moon-sfv.BareItem::date(-1659578233L))),
    "@-1659578233",
  )
}

///|
test "serialize display string" {
  @test.assert_eq(
    ser_item_str(
      @moon-sfv.Item::of(
        @moon-sfv.BareItem::display_string(
          "This is intended for display to 眉sers.",
        ),
      ),
    ),
    "%\"This is intended for display to %e7%9c%89sers.\"",
  )
  // percent and quote are percent-encoded; backslash is not (RFC 9651
  // §4.1.11 step 4.1 lists only %x25, %x22, and the control/high ranges)
  @test.assert_eq(
    ser_item_str(
      @moon-sfv.Item::of(@moon-sfv.BareItem::display_string("a\"b%c\\d")),
    ),
    "%\"a%22b%25c\\d\"",
  )
}

///|
test "serialize item with parameters" {
  let p = @moon-sfv.Parameters::new()
  p.set("a", @moon-sfv.BareItem::integer(1L))
  p.set("b", @moon-sfv.BareItem::boolean(true)) // omitted
  p.set("c", @moon-sfv.BareItem::boolean(false)) // kept
  let it = @moon-sfv.Item::with_parameters(@moon-sfv.BareItem::integer(5L), p)
  @test.assert_eq(ser_item_str(it), "5;a=1;b;c=?0")
}

///|
test "serialize list" {
  let l = @moon-sfv.SfList::new()
  l.members.push(
    @moon-sfv.ListMember::item(
      @moon-sfv.Item::of(@moon-sfv.BareItem::integer(1L)),
    ),
  )
  l.members.push(
    @moon-sfv.ListMember::item(
      @moon-sfv.Item::of(@moon-sfv.BareItem::token("foo")),
    ),
  )
  match @moon-sfv.serialize_list(l) {
    Err(_) => assert_true(false)
    Ok(sf) => @test.assert_eq(sf.to_string(), "1, foo")
  }
}

///|
test "serialize empty list omits the field" {
  let l = @moon-sfv.SfList::new()
  match @moon-sfv.serialize_list(l) {
    Err(_) => assert_true(false)
    Ok(sf) => assert_true(sf.is_omitted())
  }
}

///|
test "serialize dictionary" {
  let d = @moon-sfv.SfDictionary::new()
  d.set(
    "a",
    @moon-sfv.ListMember::item(
      @moon-sfv.Item::of(@moon-sfv.BareItem::boolean(true)),
    ),
  )
  d.set(
    "b",
    @moon-sfv.ListMember::item(
      @moon-sfv.Item::of(@moon-sfv.BareItem::boolean(false)),
    ),
  )
  let p = @moon-sfv.Parameters::new()
  p.set("foo", @moon-sfv.BareItem::token("bar"))
  d.set(
    "c",
    @moon-sfv.ListMember::item(
      @moon-sfv.Item::with_parameters(@moon-sfv.BareItem::boolean(true), p),
    ),
  )
  match @moon-sfv.serialize_dictionary(d) {
    Err(_) => assert_true(false)
    Ok(sf) => @test.assert_eq(sf.to_string(), "a, b=?0, c;foo=bar")
  }
}

///|
test "serialize empty dictionary omits the field" {
  let d = @moon-sfv.SfDictionary::new()
  match @moon-sfv.serialize_dictionary(d) {
    Err(_) => assert_true(false)
    Ok(sf) => assert_true(sf.is_omitted())
  }
}

///|
test "serialize dictionary with inner list" {
  let d = @moon-sfv.SfDictionary::new()
  let il = @moon-sfv.InnerList::new()
  il.items.push(@moon-sfv.Item::of(@moon-sfv.BareItem::integer(1L)))
  il.items.push(@moon-sfv.Item::of(@moon-sfv.BareItem::integer(2L)))
  d.set("a", @moon-sfv.ListMember::inner_list(il))
  match @moon-sfv.serialize_dictionary(d) {
    Err(_) => assert_true(false)
    Ok(sf) => @test.assert_eq(sf.to_string(), "a=(1 2)")
  }
}

///|
test "serialize parameter value must be a bare item" {
  let p = @moon-sfv.Parameters::new()
  p.set("k", @moon-sfv.BareItem::boolean(true))
  let it = @moon-sfv.Item::with_parameters(@moon-sfv.BareItem::integer(1L), p)
  @test.assert_eq(ser_item_str(it), "1;k")
}
