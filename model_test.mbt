///|
/// Tests for the abstract data model: bare items, parameters, items, inner
/// lists, lists, dictionaries, and their ordered-map behavior.
test "bare item constructors and equality" {
  let a = @moon-sfv.BareItem::integer(1L)
  let b = @moon-sfv.BareItem::integer(1L)
  @test.assert_eq(a, b)
  let c = @moon-sfv.BareItem::string_item("x")
  let d = @moon-sfv.BareItem::string_item("y")
  @test.assert_not_eq(c, d)
  @test.assert_eq(
    @moon-sfv.BareItem::boolean(true),
    @moon-sfv.BareItem::boolean(true),
  )
  @test.assert_eq(
    @moon-sfv.BareItem::token("a:b/c"),
    @moon-sfv.BareItem::token("a:b/c"),
  )
  @test.assert_eq(
    @moon-sfv.BareItem::byte_sequence(@utf8.encode("hi", bom=false)),
    @moon-sfv.BareItem::byte_sequence(@utf8.encode("hi", bom=false)),
  )
  @test.assert_eq(
    @moon-sfv.BareItem::date(1659578233L),
    @moon-sfv.BareItem::date(1659578233L),
  )
  @test.assert_eq(
    @moon-sfv.BareItem::display_string("f眉眉"),
    @moon-sfv.BareItem::display_string("f眉眉"),
  )
  @test.assert_eq(
    @moon-sfv.BareItem::decimal(@moon-sfv.SfDecimal::new(45L, 1)),
    @moon-sfv.BareItem::decimal(@moon-sfv.SfDecimal::new(45L, 1)),
  )
}

///|
test "decimal and integer are distinct bare items" {
  @test.assert_not_eq(
    @moon-sfv.BareItem::integer(45L),
    @moon-sfv.BareItem::decimal(@moon-sfv.SfDecimal::new(45L, 0)),
  )
}

///|
test "parameters empty and set/get" {
  let p = @moon-sfv.Parameters::new()
  assert_true(p.is_empty())
  @test.assert_eq(p.len(), 0)
  @test.assert_eq(p.get_by_key("a"), None)
  p.set("a", @moon-sfv.BareItem::integer(1L))
  assert_true(!p.is_empty())
  @test.assert_eq(p.len(), 1)
  @test.assert_eq(p.get_by_key("a"), Some(@moon-sfv.BareItem::integer(1L)))
  @test.assert_eq(
    p.get_by_index(0),
    Some({ key: "a", value: @moon-sfv.BareItem::integer(1L) }),
  )
  @test.assert_eq(p.get_by_index(5), None)
}

///|
test "parameters duplicate key replacement keeps position" {
  let p = @moon-sfv.Parameters::new()
  p.set("a", @moon-sfv.BareItem::integer(1L))
  p.set("b", @moon-sfv.BareItem::integer(2L))
  p.set("a", @moon-sfv.BareItem::integer(9L))
  @test.assert_eq(p.len(), 2)
  @test.assert_eq(p.keys(), ["a", "b"])
  @test.assert_eq(p.get_by_key("a"), Some(@moon-sfv.BareItem::integer(9L)))
  // The first occurrence keeps its position.
  @test.assert_eq(
    p.get_by_index(0),
    Some({ key: "a", value: @moon-sfv.BareItem::integer(9L) }),
  )
}

///|
test "parameters entries order" {
  let p = @moon-sfv.Parameters::new()
  p.set("c", @moon-sfv.BareItem::integer(3L))
  p.set("a", @moon-sfv.BareItem::integer(1L))
  p.set("b", @moon-sfv.BareItem::integer(2L))
  @test.assert_eq(p.keys(), ["c", "a", "b"])
  let entries = p.entries()
  @test.assert_eq(entries.length(), 3)
  @test.assert_eq(entries[0].key, "c")
  @test.assert_eq(entries[2].key, "b")
}

///|
test "item constructors" {
  let it = @moon-sfv.Item::of(@moon-sfv.BareItem::integer(5L))
  @test.assert_eq(it.bare, @moon-sfv.BareItem::integer(5L))
  assert_true(it.parameters.is_empty())
  let p = @moon-sfv.Parameters::new()
  p.set("k", @moon-sfv.BareItem::boolean(true))
  let it2 = @moon-sfv.Item::with_parameters(@moon-sfv.BareItem::token("t"), p)
  @test.assert_eq(
    it2.parameters.get_by_key("k"),
    Some(@moon-sfv.BareItem::boolean(true)),
  )
}

///|
test "list constructors and access" {
  let l = @moon-sfv.SfList::new()
  assert_true(l.is_empty())
  @test.assert_eq(l.len(), 0)
  @test.assert_eq(l.get_by_index(0), None)
  let parsed = match @moon-sfv.parse_list("1, (2 3);p=1") {
    Err(_) => fail("expected parse to succeed")
    Ok(v) => v
  }
  @test.assert_eq(parsed.len(), 2)
  @test.assert_eq(
    parsed.get_by_index(0),
    Some(
      @moon-sfv.ListMember::item(
        @moon-sfv.Item::of(@moon-sfv.BareItem::integer(1L)),
      ),
    ),
  )
}

///|
test "dictionary ordered access and duplicate keys" {
  let d = @moon-sfv.SfDictionary::new()
  assert_true(d.is_empty())
  d.set(
    "a",
    @moon-sfv.ListMember::item(
      @moon-sfv.Item::of(@moon-sfv.BareItem::integer(1L)),
    ),
  )
  d.set(
    "b",
    @moon-sfv.ListMember::item(
      @moon-sfv.Item::of(@moon-sfv.BareItem::integer(2L)),
    ),
  )
  d.set(
    "a",
    @moon-sfv.ListMember::item(
      @moon-sfv.Item::of(@moon-sfv.BareItem::integer(9L)),
    ),
  )
  @test.assert_eq(d.len(), 2)
  @test.assert_eq(d.keys(), ["a", "b"])
  @test.assert_eq(
    d.get_by_key("a"),
    Some(
      @moon-sfv.ListMember::item(
        @moon-sfv.Item::of(@moon-sfv.BareItem::integer(9L)),
      ),
    ),
  )
  @test.assert_eq(
    d.get_by_index(0),
    Some({
      key: "a",
      value: @moon-sfv.ListMember::item(
        @moon-sfv.Item::of(@moon-sfv.BareItem::integer(9L)),
      ),
    }),
  )
  @test.assert_eq(d.get_by_key("zzz"), None)
}

///|
test "serialized field" {
  let o = @moon-sfv.Omit
  assert_true(o.is_omitted())
  @test.assert_eq(o.to_string(), "")
  let v = @moon-sfv.Value("x")
  assert_true(!v.is_omitted())
  @test.assert_eq(v.to_string(), "x")
}

///|
test "field type names" {
  let ft : @moon-sfv.FieldType = @moon-sfv.Item
  @test.assert_eq(ft.wire_name(), "item")
  let fl : @moon-sfv.FieldType = @moon-sfv.List
  @test.assert_eq(fl.wire_name(), "list")
  let fd : @moon-sfv.FieldType = @moon-sfv.Dictionary
  @test.assert_eq(fd.wire_name(), "dictionary")
  @test.assert_eq(
    @moon-sfv.FieldType::from_wire_name("item"),
    Some(@moon-sfv.Item),
  )
  @test.assert_eq(@moon-sfv.FieldType::from_wire_name("bogus"), None)
}

///|
test "parse limits default" {
  let l = @moon-sfv.ParseLimits::default()
  @test.assert_eq(l.max_members, 100_000)
  @test.assert_eq(l.max_input_bytes, 4 * 1024 * 1024)
  @test.assert_eq(l.max_nesting_depth, 8)
}
