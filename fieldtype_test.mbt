///|
/// Tests for the type-erased `FieldType::parse` / `ParsedValue::serialize`
/// convenience API.
test "fieldtype parse dispatches by type" {
  let ft : @moon-sfv.FieldType = @moon-sfv.List
  match @moon-sfv.FieldType::parse(ft, "1, 42") {
    Err(_) => assert_true(false)
    Ok(v) =>
      match v {
        @moon-sfv.ListValue(l) => @test.assert_eq(l.len(), 2)
        _ => assert_true(false)
      }
  }
  let ft2 : @moon-sfv.FieldType = @moon-sfv.Item
  match @moon-sfv.FieldType::parse(ft2, "5; a=1") {
    Err(_) => assert_true(false)
    Ok(v) =>
      match v {
        @moon-sfv.ItemValue(it) =>
          @test.assert_eq(
            it.parameters.get_by_key("a"),
            Some(@moon-sfv.BareItem::integer(1L)),
          )
        _ => assert_true(false)
      }
  }
  let ft3 : @moon-sfv.FieldType = @moon-sfv.Dictionary
  match @moon-sfv.FieldType::parse(ft3, "a=1, b=2") {
    Err(_) => assert_true(false)
    Ok(v) =>
      match v {
        @moon-sfv.DictionaryValue(d) => @test.assert_eq(d.len(), 2)
        _ => assert_true(false)
      }
  }
}

///|
test "fieldtype parse propagates errors" {
  let ft : @moon-sfv.FieldType = @moon-sfv.Item
  assert_true(@moon-sfv.FieldType::parse(ft, "abc, def") is Err(_))
  let ft2 : @moon-sfv.FieldType = @moon-sfv.List
  assert_true(@moon-sfv.FieldType::parse(ft2, "1,") is Err(_))
}

///|
test "parsedvalue serialize round-trips" {
  let ft : @moon-sfv.FieldType = @moon-sfv.List
  match @moon-sfv.FieldType::parse(ft, "1, 42") {
    Err(_) => assert_true(false)
    Ok(v) => {
      let sf = match v.serialize() {
        Err(_) => fail("serialize should succeed")
        Ok(x) => x
      }
      @test.assert_eq(sf.to_string(), "1, 42")
      // Re-parse the serialized form through the type-erased API.
      match @moon-sfv.FieldType::parse(ft, sf.to_string()) {
        Err(_) => assert_true(false)
        Ok(v2) =>
          match v2 {
            @moon-sfv.ListValue(l) => @test.assert_eq(l.len(), 2)
            _ => assert_true(false)
          }
      }
    }
  }
}

///|
test "parsedvalue serialize reports omit for empty containers" {
  let ft : @moon-sfv.FieldType = @moon-sfv.Dictionary
  match @moon-sfv.FieldType::parse(ft, "") {
    Err(_) => assert_true(false)
    Ok(v) => {
      let sf = match v.serialize() {
        Err(_) => fail("serialize should succeed")
        Ok(x) => x
      }
      assert_true(sf.is_omitted())
    }
  }
}
