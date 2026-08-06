///|
/// The conformance harness that runs the imported httpwg
/// `structured-field-tests` vectors against this implementation and
/// reports categorized pass/fail statistics.
///
/// Required tests (per RFC 9651 MUST/SHOULD behavior) must all pass; a
/// single required failure is a conformance bug. Optional (`can_fail`)
/// tests are counted and reported but do not fail the run. The report is
/// also used by the `sfv-tool conformance` CLI command.
pub(all) struct ConformanceStats {
  required_valid_total : Int
  required_valid_passed : Int
  required_invalid_total : Int
  required_invalid_passed : Int
  canonical_total : Int
  canonical_passed : Int
  optional_total : Int
  optional_passed : Int
  optional_failed : Int
  expected_total : Int
  expected_passed : Int
  failures : Array[String]
} derive(Debug, Eq)

///|
/// Runs every imported httpwg vector and returns the statistics.
pub fn run_conformance() -> ConformanceStats {
  let mut rv_total = 0
  let mut rv_passed = 0
  let mut ri_total = 0
  let mut ri_passed = 0
  let mut canon_total = 0
  let mut canon_passed = 0
  let mut opt_total = 0
  let mut opt_passed = 0
  let mut opt_failed = 0
  let mut exp_total = 0
  let mut exp_passed = 0
  let failures : Array[String] = []
  for i in 0..<httpwg_cases.length() {
    let case = httpwg_cases[i]
    let wire = combine_field_lines(case.raw)
    let parsed = parse_by_type(wire, case.header_type)
    if case.must_fail {
      if case.can_fail {
        opt_total = opt_total + 1
        if parsed is Ok(_) {
          opt_failed = opt_failed + 1
          failures.push("must_fail case parsed: \{case.name}")
        } else {
          opt_passed = opt_passed + 1
        }
      } else {
        ri_total = ri_total + 1
        if parsed is Err(_) {
          ri_passed = ri_passed + 1
        } else {
          failures.push("required-invalid case parsed: \{case.name}")
        }
      }
    } else if case.can_fail {
      opt_total = opt_total + 1
      match parsed {
        Err(_) => opt_failed = opt_failed + 1
        Ok(_) => opt_passed = opt_passed + 1
      }
    } else {
      rv_total = rv_total + 1
      match parsed {
        Err(e) =>
          failures.push(
            "required-valid case failed to parse: \{case.name} (\{e.to_string()})",
          )
        Ok(value) => {
          rv_passed = rv_passed + 1
          // Canonical round-trip.
          let serialized = serialize_field(value)
          let canon_lines = match case.canonical {
            None => case.raw
            Some(c) => c
          }
          let canon_wire = combine_field_lines(canon_lines)
          canon_total = canon_total + 1
          match serialized {
            Err(e) =>
              failures.push(
                "required-valid case failed to serialize: \{case.name} (\{e.to_string()})",
              )
            Ok(sf) =>
              if sf.to_string() == canon_wire {
                canon_passed = canon_passed + 1
              } else {
                failures.push(
                  "canonical mismatch for \{case.name}: got \"\{sf.to_string()}\" want \"\{canon_wire}\"",
                )
              }
          }
          // Expected-structure comparison (supplementary).
          match case.expected {
            None => ()
            Some(exp) => {
              exp_total = exp_total + 1
              if expected_matches(value, exp, case.header_type) {
                exp_passed = exp_passed + 1
              } else {
                failures.push("expected-structure mismatch for \{case.name}")
              }
            }
          }
        }
      }
    }
  }
  {
    required_valid_total: rv_total,
    required_valid_passed: rv_passed,
    required_invalid_total: ri_total,
    required_invalid_passed: ri_passed,
    canonical_total: canon_total,
    canonical_passed: canon_passed,
    optional_total: opt_total,
    optional_passed: opt_passed,
    optional_failed: opt_failed,
    expected_total: exp_total,
    expected_passed: exp_passed,
    failures,
  }
}

///|
/// Parses a combined wire value by field type.
fn parse_by_type(
  wire : String,
  header_type : String,
) -> Result[ParsedValue, SfError] {
  if header_type == "item" {
    return match parse_item(wire) {
      Err(e) => Err(e)
      Ok(v) => Ok(ItemValue(v))
    }
  }
  if header_type == "list" {
    return match parse_list(wire) {
      Err(e) => Err(e)
      Ok(v) => Ok(ListValue(v))
    }
  }
  match parse_dictionary(wire) {
    Err(e) => Err(e)
    Ok(v) => Ok(DictionaryValue(v))
  }
}

///|
/// Serializes a parsed field back to its wire form.
fn serialize_field(value : ParsedValue) -> Result[SerializedField, SfError] {
  match value {
    ItemValue(v) =>
      match serialize_item(v) {
        Err(e) => Err(e)
        Ok(s) => Ok(Value(s))
      }
    ListValue(v) => serialize_list(v)
    DictionaryValue(v) => serialize_dictionary(v)
  }
}

///|
/// The parsed field value, erased across the three top-level types.
pub(all) enum ParsedValue {
  ItemValue(Item)
  ListValue(SfList)
  DictionaryValue(SfDictionary)
}

///|
/// Parses `input` as a field of the given type, returning a type-erased
/// [`ParsedValue`]. Useful when the field type is only known at runtime.
pub fn FieldType::parse(
  self : FieldType,
  input : String,
) -> Result[ParsedValue, SfError] {
  parse_by_type(input, self.wire_name())
}

///|
/// Serializes a type-erased parsed value back to its canonical wire form.
pub fn ParsedValue::serialize(
  self : ParsedValue,
) -> Result[SerializedField, SfError] {
  serialize_field(self)
}

///|
/// Compares a parsed field against its expected abstract structure.
pub fn expected_matches(
  actual : ParsedValue,
  expected : ExpectedField,
  header_type : String,
) -> Bool {
  if header_type == "item" {
    return match (actual, expected) {
      (ItemValue(a), ExpItemField(e)) => item_matches(a, e)
      _ => false
    }
  }
  if header_type == "list" {
    return match (actual, expected) {
      (ListValue(a), ExpListField(e)) => list_matches(a, e)
      _ => false
    }
  }
  match (actual, expected) {
    (DictionaryValue(a), ExpDictField(e)) => dict_matches(a, e)
    _ => false
  }
}

///|
fn list_matches(actual : SfList, expected : Array[ExpectedMember]) -> Bool {
  if actual.len() != expected.length() {
    return false
  }
  for i in 0..<expected.length() {
    let m = actual.get_by_index(i)
    match m {
      None => return false
      Some(am) => if !member_matches(am, expected[i]) { return false }
    }
  }
  true
}

///|
fn dict_matches(
  actual : SfDictionary,
  expected : Array[(String, ExpectedMember)],
) -> Bool {
  if actual.len() != expected.length() {
    return false
  }
  for i in 0..<expected.length() {
    let (key, em) = expected[i]
    let actual_member = actual.get_by_key(key)
    match actual_member {
      None => return false
      Some(am) => if !member_matches(am, em) { return false }
    }
  }
  true
}

///|
fn member_matches(actual : ListMember, expected : ExpectedMember) -> Bool {
  match (actual, expected) {
    (ItemMember(a), ExpItemMember(e)) => item_matches(a, e)
    (InnerListMember(a), ExpInnerList(items, params)) => {
      if a.items.length() != items.length() {
        return false
      }
      for i in 0..<items.length() {
        if !item_matches(a.items[i], items[i]) {
          return false
        }
      }
      params_match(a.parameters, params)
    }
    _ => false
  }
}

///|
fn item_matches(actual : Item, expected : ExpectedItem) -> Bool {
  if !bare_item_matches(actual.bare, expected.bare) {
    return false
  }
  params_match(actual.parameters, expected.params)
}

///|
fn params_match(actual : Parameters, expected : Array[ExpectedParam]) -> Bool {
  if actual.len() != expected.length() {
    return false
  }
  for i in 0..<expected.length() {
    let ep = expected[i]
    let av = actual.get_by_key(ep.key)
    match av {
      None => return false
      Some(v) => if !bare_item_matches(v, ep.value) { return false }
    }
  }
  true
}

///|
fn bare_item_matches(actual : BareItem, expected : ExpectedBare) -> Bool {
  match (actual, expected) {
    (Integer(a), ExpInteger(e)) => a == e
    (Decimal(a), ExpDecimal(coeff, scale)) =>
      a.compare(SfDecimal::new(coeff, scale)) == 0
    (StringItem(a), ExpString(e)) => a == e
    (Token(a), ExpToken(e)) => a == e
    (ByteSequence(a), ExpBinary(hex)) => a == hex_to_bytes(hex)
    (Boolean(a), ExpBoolean(e)) => a == e
    (Date(a), ExpDate(e)) => a == e
    (DisplayString(a), ExpDisplayString(e)) => a == e
    _ => false
  }
}

///|
/// Decodes the hex string used to store expected binary content.
fn hex_to_bytes(hex : String) -> Bytes {
  let out : Array[Byte] = []
  let mut i = 0
  while i + 1 < hex.length() {
    let hi = hex_value(hex[i].to_byte())
    let lo = hex_value(hex[i + 1].to_byte())
    if hi >= 0 && lo >= 0 {
      out.push(((hi << 4) | lo).to_byte())
    }
    i = i + 2
  }
  Bytes::from_array(out)
}

///|
/// A one-line summary line for the CLI / test report.
pub fn ConformanceStats::summary_line(self : ConformanceStats) -> String {
  "required_valid=\{self.required_valid_passed}/\{self.required_valid_total} " +
  "required_invalid=\{self.required_invalid_passed}/\{self.required_invalid_total} " +
  "canonical=\{self.canonical_passed}/\{self.canonical_total} " +
  "optional=\{self.optional_passed}/\{self.optional_total} " +
  "expected=\{self.expected_passed}/\{self.expected_total}"
}
