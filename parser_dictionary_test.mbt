///|
/// Tests for Dictionary parsing: keys, members, implicit Boolean true
/// values, inner-list members, duplicate keys, and separators.
fn ok_dict(input : String) -> SfDictionary raise Failure {
  match @moon-sfv.parse_dictionary(input) {
    Err(e) => fail("expected Ok, got \{e.to_string()}")
    Ok(v) => v
  }
}

///|
fn is_dict_err(input : String) -> Bool {
  @moon-sfv.parse_dictionary(input) is Err(_)
}

///|
test "basic dictionary" {
  let d = ok_dict("en=\"Applepie\", da=:w4ZibGV0w6ZydGU=:")
  @test.assert_eq(d.len(), 2)
  @test.assert_eq(d.keys(), ["en", "da"])
  match d.get_by_key("en") {
    Some(@moon-sfv.ItemMember(it)) =>
      @test.assert_eq(it.bare, @moon-sfv.BareItem::string_item("Applepie"))
    _ => assert_true(false)
  }
}

///|
test "empty dictionary is valid" {
  let d = ok_dict("")
  @test.assert_eq(d.len(), 0)
  assert_true(d.is_empty())
  let d2 = ok_dict(" ")
  @test.assert_eq(d2.len(), 0)
}

///|
test "dictionary implicit boolean true" {
  let d = ok_dict("a, b, c; foo=bar")
  @test.assert_eq(d.len(), 3)
  match d.get_by_key("a") {
    Some(@moon-sfv.ItemMember(it)) =>
      @test.assert_eq(it.bare, @moon-sfv.BareItem::boolean(true))
    _ => assert_true(false)
  }
  // parameters belong to the implicit item
  match d.get_by_key("c") {
    Some(@moon-sfv.ItemMember(it)) => {
      @test.assert_eq(it.bare, @moon-sfv.BareItem::boolean(true))
      @test.assert_eq(
        it.parameters.get_by_key("foo"),
        Some(@moon-sfv.BareItem::token("bar")),
      )
    }
    _ => assert_true(false)
  }
}

///|
test "dictionary with inner list members" {
  let d = ok_dict("a=(1 2), b=3, c=4;aa=bb, d=(5 6);valid")
  @test.assert_eq(d.len(), 4)
  match d.get_by_key("a") {
    Some(@moon-sfv.InnerListMember(il)) => @test.assert_eq(il.len(), 2)
    _ => assert_true(false)
  }
  match d.get_by_key("d") {
    Some(@moon-sfv.InnerListMember(il)) => {
      @test.assert_eq(il.len(), 2)
      @test.assert_eq(
        il.parameters.get_by_key("valid"),
        Some(@moon-sfv.BareItem::boolean(true)),
      )
    }
    _ => assert_true(false)
  }
  match d.get_by_key("c") {
    Some(@moon-sfv.ItemMember(it)) => {
      @test.assert_eq(it.bare, @moon-sfv.BareItem::integer(4L))
      @test.assert_eq(
        it.parameters.get_by_key("aa"),
        Some(@moon-sfv.BareItem::token("bb")),
      )
    }
    _ => assert_true(false)
  }
}

///|
test "dictionary explicit boolean true" {
  let d = ok_dict("a=?1, b=?0")
  match d.get_by_key("a") {
    Some(@moon-sfv.ItemMember(it)) =>
      @test.assert_eq(it.bare, @moon-sfv.BareItem::boolean(true))
    _ => assert_true(false)
  }
  match d.get_by_key("b") {
    Some(@moon-sfv.ItemMember(it)) =>
      @test.assert_eq(it.bare, @moon-sfv.BareItem::boolean(false))
    _ => assert_true(false)
  }
}

///|
test "dictionary duplicate keys keep last value" {
  let d = ok_dict("a=1, b=2, a=9")
  @test.assert_eq(d.len(), 2)
  @test.assert_eq(d.keys(), ["a", "b"])
  match d.get_by_key("a") {
    Some(@moon-sfv.ItemMember(it)) =>
      @test.assert_eq(it.bare, @moon-sfv.BareItem::integer(9L))
    _ => assert_true(false)
  }
}

///|
test "dictionary whitespace and tabs" {
  let d = ok_dict("foo=1\t,\tbar=2")
  @test.assert_eq(d.len(), 2)
  @test.assert_eq(d.keys(), ["foo", "bar"])
  let d2 = ok_dict("   foo=1 ,  bar=2  ")
  @test.assert_eq(d2.len(), 2)
}

///|
test "dictionary keys with star" {
  let d = ok_dict("*key=1, a*=2, a.b-c_d=3")
  @test.assert_eq(d.len(), 3)
  @test.assert_eq(d.keys(), ["*key", "a*", "a.b-c_d"])
}

///|
test "dictionary invalid forms" {
  // uppercase keys fail
  assert_true(is_dict_err("A=1"))
  assert_true(is_dict_err("Foo=1"))
  // missing '=' between key and value without parameters
  assert_true(is_dict_err("foo bar"))
  // trailing comma
  assert_true(is_dict_err("foo=1,"))
  // empty member
  assert_true(is_dict_err(",foo=1"))
  assert_true(is_dict_err("foo=1,,bar=2"))
  // missing key
  assert_true(is_dict_err("=1"))
  // digit-leading key
  assert_true(is_dict_err("1foo=2"))
  // a bare key is a valid implicit-boolean-true member
  let d = ok_dict("foo")
  @test.assert_eq(d.len(), 1)
}

///|
test "dictionary parameterised members" {
  let d = ok_dict("abc=123;a=1;b=2, def=456, ghi=789;q=9;r=\"+w\"")
  @test.assert_eq(d.len(), 3)
  match d.get_by_key("ghi") {
    Some(@moon-sfv.ItemMember(it)) => {
      @test.assert_eq(
        it.parameters.get_by_key("q"),
        Some(@moon-sfv.BareItem::integer(9L)),
      )
      @test.assert_eq(
        it.parameters.get_by_key("r"),
        Some(@moon-sfv.BareItem::string_item("+w")),
      )
    }
    _ => assert_true(false)
  }
}

///|
test "dictionary value with a leading key-like token" {
  // a token member value is fine after '='
  let d = ok_dict("a=b")
  match d.get_by_key("a") {
    Some(@moon-sfv.ItemMember(it)) =>
      @test.assert_eq(it.bare, @moon-sfv.BareItem::token("b"))
    _ => assert_true(false)
  }
}
