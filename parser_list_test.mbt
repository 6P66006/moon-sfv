///|
/// Tests for List parsing: members, inner lists, whitespace, and member
/// separators.
fn ok_list(input : String) -> SfList raise Failure {
  match @moon-sfv.parse_list(input) {
    Err(e) => fail("expected Ok, got \{e.to_string()}")
    Ok(v) => v
  }
}

///|
fn is_list_err(input : String) -> Bool {
  @moon-sfv.parse_list(input) is Err(_)
}

///|
test "basic list" {
  let l = ok_list("1, 42")
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
test "empty list is valid" {
  let l = ok_list("")
  @test.assert_eq(l.len(), 0)
  assert_true(l.is_empty())
  let l2 = ok_list(" ")
  @test.assert_eq(l2.len(), 0)
}

///|
test "single item list" {
  let l = ok_list("42")
  @test.assert_eq(l.len(), 1)
  @test.assert_eq(
    l.get_by_index(0),
    Some(
      @moon-sfv.ListMember::item(
        @moon-sfv.Item::of(@moon-sfv.BareItem::integer(42L)),
      ),
    ),
  )
}

///|
test "list whitespace normalization" {
  // no whitespace around commas is fine
  let l = ok_list("1,42")
  @test.assert_eq(l.len(), 2)
  // extra whitespace is fine
  let l2 = ok_list("1 , 42")
  @test.assert_eq(l2.len(), 2)
  // tabs are allowed as OWS in lists
  let l3 = ok_list("1\t,\t42")
  @test.assert_eq(l3.len(), 2)
  // leading and trailing whitespace
  let l4 = ok_list("  1, 42  ")
  @test.assert_eq(l4.len(), 2)
}

///|
test "list trailing comma fails" {
  assert_true(is_list_err("1,"))
  assert_true(is_list_err("1, "))
  assert_true(is_list_err("1, 2,"))
}

///|
test "list empty member fails" {
  assert_true(is_list_err(","))
  assert_true(is_list_err("1,,2"))
  assert_true(is_list_err("1, ,2"))
  assert_true(is_list_err(",1"))
}

///|
test "list with inner lists" {
  let l = ok_list("(\"foo\" \"bar\"), (\"baz\"), (\"bat\" \"one\"), ()")
  @test.assert_eq(l.len(), 4)
  // first member is an inner list
  match l.get_by_index(0) {
    Some(@moon-sfv.InnerListMember(il)) => @test.assert_eq(il.len(), 2)
    _ => assert_true(false)
  }
  // empty inner list
  match l.get_by_index(3) {
    Some(@moon-sfv.InnerListMember(il)) => @test.assert_eq(il.len(), 0)
    _ => assert_true(false)
  }
}

///|
test "inner list with parameters" {
  let l = ok_list("(\"foo\"; a=1;b=2);lvl=5")
  match l.get_by_index(0) {
    Some(@moon-sfv.InnerListMember(il)) => {
      @test.assert_eq(il.len(), 1)
      @test.assert_eq(
        il.parameters.get_by_key("lvl"),
        Some(@moon-sfv.BareItem::integer(5L)),
      )
      match il.items[0] {
        { bare: _, parameters: p } => {
          @test.assert_eq(
            p.get_by_key("a"),
            Some(@moon-sfv.BareItem::integer(1L)),
          )
          @test.assert_eq(
            p.get_by_key("b"),
            Some(@moon-sfv.BareItem::integer(2L)),
          )
        }
      }
    }
    _ => assert_true(false)
  }
}

///|
test "inner list item separation" {
  // items separated by a single space
  let l = ok_list("(1 2)")
  match l.get_by_index(0) {
    Some(@moon-sfv.InnerListMember(il)) => @test.assert_eq(il.len(), 2)
    _ => assert_true(false)
  }
  // items separated by multiple spaces
  let l2 = ok_list("(1  2)")
  match l2.get_by_index(0) {
    Some(@moon-sfv.InnerListMember(il)) => @test.assert_eq(il.len(), 2)
    _ => assert_true(false)
  }
  // items separated by a tab is NOT allowed
  assert_true(is_list_err("(1\t2)"))
}

///|
test "inner list invalid forms" {
  assert_true(is_list_err("(1 2"))
  assert_true(is_list_err(")"))
  // comma inside an inner list is not a valid member separator
  assert_true(is_list_err("(1, 2)"))
}

///|
test "list mixed types" {
  let l = ok_list("1, foo, \"bar\", ?1, @123, :aGVsbG8=:")
  @test.assert_eq(l.len(), 6)
  @test.assert_eq(
    l.get_by_index(1),
    Some(
      @moon-sfv.ListMember::item(
        @moon-sfv.Item::of(@moon-sfv.BareItem::token("foo")),
      ),
    ),
  )
}

///|
test "list member with parameters" {
  let l = ok_list("abc;a=1;b=2; cde_456, (ghi;jk=4 l);q=\"9\";r=w")
  @test.assert_eq(l.len(), 2)
  match l.get_by_index(0) {
    Some(@moon-sfv.ItemMember(it)) => {
      @test.assert_eq(it.bare, @moon-sfv.BareItem::token("abc"))
      @test.assert_eq(it.parameters.len(), 3)
      @test.assert_eq(
        it.parameters.get_by_key("cde_456"),
        Some(@moon-sfv.BareItem::boolean(true)),
      )
    }
    _ => assert_true(false)
  }
}

///|
test "list invalid separators" {
  // missing comma
  assert_true(is_list_err("1 42"))
  // semicolon not allowed as a top-level separator
  assert_true(is_list_err("1;2"))
}

///|
test "list with no OWS before comma" {
  // "1,42" is fine but "1 ,42" also fine; a member must not be empty
  assert_true(is_list_err("1, ,42"))
}
