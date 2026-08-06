///|
/// Tests for combining Structured Fields across multiple HTTP field lines
/// (RFC 9651 §4.2, RFC 9110 §5.2).
test "field lines single line" {
  let l = match @moon-sfv.parse_list_lines(["1, 42"]) {
    Err(e) => fail(e.to_string())
    Ok(v) => v
  }
  @test.assert_eq(l.len(), 2)
}

///|
test "field lines two-line list" {
  let l = match @moon-sfv.parse_list_lines(["1", "42"]) {
    Err(e) => fail(e.to_string())
    Ok(v) => v
  }
  @test.assert_eq(l.len(), 2)
  @test.assert_eq(
    l.get_by_index(0),
    Some(
      @moon-sfv.ListMember::item(
        @moon-sfv.Item::of(@moon-sfv.BareItem::integer(1L)),
      ),
    ),
  )
  @test.assert_eq(
    l.get_by_index(1),
    Some(
      @moon-sfv.ListMember::item(
        @moon-sfv.Item::of(@moon-sfv.BareItem::integer(42L)),
      ),
    ),
  )
}

///|
test "field lines two-line dictionary" {
  let d = match @moon-sfv.parse_dictionary_lines(["a=1", "b=2"]) {
    Err(e) => fail(e.to_string())
    Ok(v) => v
  }
  @test.assert_eq(d.len(), 2)
  @test.assert_eq(d.keys(), ["a", "b"])
}

///|
test "field lines boundary between members" {
  // the comma falls on the boundary between the two lines
  let l = match @moon-sfv.parse_list_lines(["foo", "bar"]) {
    Err(e) => fail(e.to_string())
    Ok(v) => v
  }
  @test.assert_eq(l.len(), 2)
  let d = match @moon-sfv.parse_dictionary_lines(["foo=1", "bar=2"]) {
    Err(e) => fail(e.to_string())
    Ok(v) => v
  }
  @test.assert_eq(d.len(), 2)
}

///|
test "field lines empty member fails" {
  // an empty line between two lines creates an empty member
  assert_true(@moon-sfv.parse_list_lines(["1", "", "42"]) is Err(_))
  assert_true(@moon-sfv.parse_dictionary_lines(["a=1", "", "b=2"]) is Err(_))
}

///|
test "field lines one invalid line fails the whole field" {
  assert_true(@moon-sfv.parse_list_lines(["1", "abc,", "42"]) is Err(_))
  assert_true(@moon-sfv.parse_dictionary_lines(["a=1", "!!", "b=2"]) is Err(_))
}

///|
test "field lines item cannot be split safely" {
  // a string split across lines becomes a single string with the comma
  let it = match @moon-sfv.parse_item_lines(["\"foo", "bar\""]) {
    Err(e) => fail(e.to_string())
    Ok(v) => v
  }
  @test.assert_eq(it.bare, @moon-sfv.BareItem::string_item("foo, bar"))
  // an integer split across lines fails (the comma makes it invalid)
  assert_true(@moon-sfv.parse_item_lines(["12", "34"]) is Err(_))
  // a token split across lines fails
  assert_true(@moon-sfv.parse_item_lines(["ab", "cd"]) is Err(_))
}

///|
test "field lines empty lines only" {
  // a single empty line for a list is an empty list
  let l = match @moon-sfv.parse_list_lines([""]) {
    Err(e) => fail(e.to_string())
    Ok(v) => v
  }
  @test.assert_eq(l.len(), 0)
  // two empty lines combine to a bare comma which fails
  assert_true(@moon-sfv.parse_list_lines(["", ""]) is Err(_))
}

///|
test "field lines combine joins with comma space" {
  @test.assert_eq(@moon-sfv.combine_field_lines(["a", "b"]), "a, b")
  @test.assert_eq(@moon-sfv.combine_field_lines(["a"]), "a")
  @test.assert_eq(@moon-sfv.combine_field_lines([]), "")
  @test.assert_eq(@moon-sfv.combine_field_lines(["1", "", "2"]), "1, , 2")
}

///|
test "field lines dictionary split across lines with parameters" {
  let d = match @moon-sfv.parse_dictionary_lines(["a=b;c=1", "d=e;f=2"]) {
    Err(e) => fail(e.to_string())
    Ok(v) => v
  }
  @test.assert_eq(d.len(), 2)
  match d.get_by_key("a") {
    Some(@moon-sfv.ItemMember(it)) =>
      @test.assert_eq(
        it.parameters.get_by_key("c"),
        Some(@moon-sfv.BareItem::integer(1L)),
      )
    _ => assert_true(false)
  }
}
