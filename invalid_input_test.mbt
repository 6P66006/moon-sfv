///|
/// Safety-oriented tests: truncation at every byte offset must never crash,
/// hang, or read out of bounds, and configured size limits must be
/// enforced.
test "truncation at every byte is safe for items" {
  let inputs = [
    "42; a=1; b=\"xyz\"; c=?0", "\"foo \\\"bar\\\" \\\\ baz\"", "%\"f%c3%bc hello\"",
    ":aGVsbG8=:", "@1659578233", "foo/bar:baz;p=q",
  ]
  for input in inputs {
    let bytes = @utf8.encode(input, bom=false)
    for cut in 0..<(bytes.length().min(64) + 1) {
      let truncated = bytes[:cut].to_owned()
      let result = @moon-sfv.parse_item_bytes(truncated)
      match result {
        Err(_) => () // failing is fine; the requirement is no crash
        Ok(_) => () // a strict prefix may still parse
      }
    }
  }
}

///|
test "truncation at every byte is safe for lists" {
  let inputs = ["1, 2, 3, 42", "(1 2 3);p=q, foo;bar", "a=1, b=2, c=3"]
  for input in inputs {
    let bytes = @utf8.encode(input, bom=false)
    for cut in 0..<(bytes.length().min(64) + 1) {
      let truncated = bytes[:cut].to_owned()
      match @moon-sfv.parse_list_bytes(truncated) {
        Err(_) => ()
        Ok(_) => ()
      }
    }
  }
}

///|
test "truncation at every byte is safe for dictionaries" {
  let inputs = ["a=1, b=2, c=3;foo=bar", "x=(1 2), y"]
  for input in inputs {
    let bytes = @utf8.encode(input, bom=false)
    for cut in 0..<(bytes.length().min(64) + 1) {
      let truncated = bytes[:cut].to_owned()
      match @moon-sfv.parse_dictionary_bytes(truncated) {
        Err(_) => ()
        Ok(_) => ()
      }
    }
  }
}

///|
test "oversized input is rejected" {
  let limits = @moon-sfv.ParseLimits::default()
  let tight : @moon-sfv.ParseLimits = {
    max_input_bytes: 16,
    max_members: 10,
    max_parameters: 10,
    max_string_bytes: 16,
    max_inner_list_items: 10,
    max_nesting_depth: 8,
  }
  let long = "1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20"
  match @moon-sfv.parse_list_with_limits(long, tight) {
    Err(e) => @test.assert_eq(e.kind(), @moon-sfv.InputTooLarge)
    Ok(_) => assert_true(false)
  }
  let _ = limits
}

///|
test "max members limit is enforced" {
  let tight : @moon-sfv.ParseLimits = {
    max_input_bytes: 1 << 20,
    max_members: 5,
    max_parameters: 10,
    max_string_bytes: 100,
    max_inner_list_items: 10,
    max_nesting_depth: 8,
  }
  let list = "1, 2, 3, 4, 5, 6"
  match @moon-sfv.parse_list_with_limits(list, tight) {
    Err(e) => @test.assert_eq(e.kind(), @moon-sfv.TooManyMembers)
    Ok(_) => assert_true(false)
  }
}

///|
test "max parameters limit is enforced" {
  let tight : @moon-sfv.ParseLimits = {
    max_input_bytes: 1 << 20,
    max_members: 10,
    max_parameters: 2,
    max_string_bytes: 100,
    max_inner_list_items: 10,
    max_nesting_depth: 8,
  }
  let item = "1; a=1; b=2; c=3"
  match @moon-sfv.parse_item_with_limits(item, tight) {
    Err(e) => @test.assert_eq(e.kind(), @moon-sfv.TooManyParameters)
    Ok(_) => assert_true(false)
  }
}

///|
test "max string bytes limit is enforced" {
  let tight : @moon-sfv.ParseLimits = {
    max_input_bytes: 1 << 20,
    max_members: 10,
    max_parameters: 10,
    max_string_bytes: 4,
    max_inner_list_items: 10,
    max_nesting_depth: 8,
  }
  match @moon-sfv.parse_item_with_limits("\"abcdef\"", tight) {
    Err(e) => @test.assert_eq(e.kind(), @moon-sfv.InputTooLarge)
    Ok(_) => assert_true(false)
  }
}

///|
test "truncated percent escape in display string fails" {
  assert_true(@moon-sfv.parse_item("%\"ab%c") is Err(_))
  assert_true(@moon-sfv.parse_item("%\"ab%") is Err(_))
}

///|
test "stray bytes after a valid value fail" {
  assert_true(@moon-sfv.parse_item("1 x") is Err(_))
  assert_true(@moon-sfv.parse_item("1,") is Err(_))
  assert_true(@moon-sfv.parse_list("1, 2 3") is Err(_))
  assert_true(@moon-sfv.parse_dictionary("a=1 b=2") is Err(_))
}

///|
test "unterminated constructs fail" {
  assert_true(@moon-sfv.parse_item("(1 2") is Err(_))
  assert_true(@moon-sfv.parse_item("\"abc") is Err(_))
  assert_true(@moon-sfv.parse_item("%\"abc") is Err(_))
  assert_true(@moon-sfv.parse_list("(1 2, 3") is Err(_))
}

///|
test "error offsets are within bounds" {
  // the reported byte offset must never exceed the input length
  let bad_inputs = ["1.1234", "\"abc", "%\"a%", ":a b", "@", "5; 1a"]
  for input in bad_inputs {
    let r = @moon-sfv.parse_item(input)
    match r {
      Err(e) => assert_true(e.offset() >= 0 && e.offset() <= input.length())
      Ok(_) => ()
    }
  }
}

///|
test "error to_string is bounded and readable" {
  let e = @moon-sfv.SfError::make(
    @moon-sfv.InvalidToken,
    3,
    "a long context that should be truncated for display purposes",
  )
  let s = e.to_string()
  // must not blow up and should contain the kind and offset
  assert_true(s.contains("invalid token"))
  assert_true(s.contains("3"))
}

///|
test "error kind and accessors" {
  let e = @moon-sfv.SfError::make(@moon-sfv.InvalidString, 7, "near \"abc\"")
  @test.assert_eq(e.kind(), @moon-sfv.InvalidString)
  @test.assert_eq(e.offset(), 7)
  @test.assert_eq(e.context(), "near \"abc\"")
}
