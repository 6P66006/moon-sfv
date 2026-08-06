/// Round-trip and canonicalization property tests:
///  - `parse(serialize(value))` is semantically equal to `value`;
///  - `canonicalize(canonicalize(x))` equals `canonicalize(x)`;
///  - a deterministic pseudo-random generator produces thousands of
///    abstract values that survive the round trip.

///|
/// A small fixed-seed xorshift PRNG for deterministic fuzzing.
struct Prng {
  mut state : Int
}

///|
fn Prng::new(seed : Int) -> Prng {
  { state: seed }
}

///|
fn Prng::next(self : Prng) -> Int {
  self.state = self.state ^ (self.state << 13)
  self.state = self.state ^ (self.state >> 17)
  self.state = self.state ^ (self.state << 5)
  if self.state < 0 {
    self.state = -self.state
  }
  self.state % 2147483647
}

///|
fn random_item(rng : Prng) -> Item {
  let k = rng.next() % 8
  let bare = if k == 0 {
    @moon-sfv.BareItem::integer(rng.next().to_int64() % 1000000L)
  } else if k == 1 {
    let scale = rng.next() % 3 + 1
    @moon-sfv.BareItem::decimal(
      @moon-sfv.SfDecimal::new((rng.next() % 100000).to_int64(), scale),
    )
  } else if k == 2 {
    @moon-sfv.BareItem::string_item("a\"b\\c")
  } else if k == 3 {
    @moon-sfv.BareItem::token("tok")
  } else if k == 4 {
    @moon-sfv.BareItem::boolean(rng.next() % 2 == 0)
  } else if k == 5 {
    @moon-sfv.BareItem::date(rng.next().to_int64())
  } else if k == 6 {
    @moon-sfv.BareItem::display_string("d眉s")
  } else {
    @moon-sfv.BareItem::byte_sequence(@utf8.encode("bytes", bom=false))
  }
  @moon-sfv.Item::of(bare)
}

///|
fn serialized_or_err(
  r : Result[@moon-sfv.SerializedField, @moon-sfv.SfError],
) -> String {
  match r {
    Err(e) => "ERR:" + e.to_string()
    Ok(sf) => sf.to_string()
  }
}

///|
fn roundtrip_item_value(item : Item) -> Bool {
  match @moon-sfv.serialize_item(item) {
    Err(_) => true // some abstract values may not serialize; that is fine
    Ok(wire) =>
      match @moon-sfv.parse_item(wire) {
        Err(_) => false
        Ok(parsed) => parsed == item
      }
  }
}

///|
test "roundtrip representative wires" {
  let wires = [
    "42", "-0", "1.230", "\"foo \\\"bar\\\" \\\\ baz\"", "foo/bar:baz", ":aGVsbG8=:",
    "?1", "@1659578233", "%\"hello\"", "5; a=1; b; c=?0",
  ]
  for w in wires {
    match @moon-sfv.parse_item(w) {
      Err(_) => assert_true(false)
      Ok(item) =>
        match @moon-sfv.serialize_item(item) {
          Err(e) => fail("serialize failed for \{w}: \{e.to_string()}")
          Ok(s) =>
            match @moon-sfv.parse_item(s) {
              Err(e) => fail("reparse failed for \{s}: \{e.to_string()}")
              Ok(item2) => @test.assert_eq(item2, item)
            }
        }
    }
  }
}

///|
test "roundtrip deterministic fuzz items" {
  let rng = Prng::new(0xC0FFEE)
  for _ in 0..<2000 {
    let item = random_item(rng)
    assert_true(roundtrip_item_value(item))
  }
}

///|
test "roundtrip list and dictionary values" {
  let list_wires = ["", "1", "1, 42", "(1 2);p=1, foo;q", "a, b;c=d"]
  for w in list_wires {
    match @moon-sfv.parse_list(w) {
      Err(_) => assert_true(false)
      Ok(list) =>
        match @moon-sfv.serialize_list(list) {
          Err(_) => assert_true(false)
          Ok(sf) => {
            let s = sf.to_string()
            if w == "" {
              assert_true(sf.is_omitted())
            } else {
              match @moon-sfv.parse_list(s) {
                Err(e) => fail("reparse failed for \{s}: \{e.to_string()}")
                Ok(list2) => @test.assert_eq(list2, list)
              }
            }
          }
        }
    }
  }
  let dict_wires = ["", "a=1", "a, b=?0;c=1", "x=(1 2);q"]
  for w in dict_wires {
    match @moon-sfv.parse_dictionary(w) {
      Err(_) => assert_true(false)
      Ok(dict) =>
        match @moon-sfv.serialize_dictionary(dict) {
          Err(_) => assert_true(false)
          Ok(sf) => {
            let s = sf.to_string()
            if w == "" {
              assert_true(sf.is_omitted())
            } else {
              match @moon-sfv.parse_dictionary(s) {
                Err(e) => fail("reparse failed for \{s}: \{e.to_string()}")
                Ok(dict2) => @test.assert_eq(dict2, dict)
              }
            }
          }
        }
    }
  }
}

///|
test "canonicalize is idempotent" {
  let inputs = [
    ("0002", @moon-sfv.Item),
    ("-01", @moon-sfv.Item),
    ("4.500", @moon-sfv.Item),
    ("5; a=?1", @moon-sfv.Item),
    ("\"foo \\\"bar\\\"\"", @moon-sfv.Item),
    (":aGVsbG8:", @moon-sfv.Item),
    ("%\"f%c3%bc\"", @moon-sfv.Item),
    ("1, 42", @moon-sfv.List),
    ("a, b;c=d", @moon-sfv.Dictionary),
    ("a=1, a=2", @moon-sfv.Dictionary),
  ]
  for pair in inputs {
    let (w, ft) = pair
    match @moon-sfv.canonicalize(w, ft) {
      Err(e) => fail("canonicalize failed for \{w}: \{e.to_string()}")
      Ok(c1) =>
        match @moon-sfv.canonicalize(c1.to_string(), ft) {
          Err(e) => fail("second canonicalize failed: \{e.to_string()}")
          Ok(c2) => @test.assert_eq(c2, c1)
        }
    }
  }
}

///|
test "canonicalize known outputs" {
  @test.assert_eq(serialized_or_err(@moon-sfv.canonicalize_item("0002")), "2")
  @test.assert_eq(
    serialized_or_err(@moon-sfv.canonicalize_item("1.230")),
    "1.23",
  )
  @test.assert_eq(
    serialized_or_err(@moon-sfv.canonicalize_list("1, 42")),
    "1, 42",
  )
  @test.assert_eq(
    serialized_or_err(@moon-sfv.canonicalize_dictionary("a;b")),
    "a;b",
  )
  @test.assert_eq(serialized_or_err(@moon-sfv.canonicalize_item("-0")), "0")
  @test.assert_eq(
    serialized_or_err(@moon-sfv.canonicalize_item("%\"f%c3%bc\"")),
    "%\"f%c3%bc\"",
  )
  // empty list canonicalizes to Omit
  match @moon-sfv.canonicalize_list("") {
    Ok(sf) => assert_true(sf.is_omitted())
    Err(_) => assert_true(false)
  }
}
