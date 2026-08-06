///|
/// Exact decimal arithmetic for Structured Field Decimals (RFC 9651 §3.3.2).
///
/// A decimal is stored as an exact rational `coefficient × 10^-scale`
/// using an `Int64` coefficient. No floating-point type is used anywhere
/// in the value's representation, so parsing, comparison, and rounding are
/// exact.
///
/// Wire-format restrictions (at most 3 fractional digits, at most 12
/// integer digits) are enforced by the parser and by serialization.
pub(all) struct SfDecimal {
  coefficient : Int64
  scale : Int
} derive(Debug)

///|
/// Two decimals are equal when they denote the same rational value.
/// `1.2` (12, 1) and `1.20` (120, 2) compare equal even though their
/// stored coefficients differ.
pub impl Eq for SfDecimal with fn equal(self, other) {
  self.compare(other) == 0
}

///|
const MAX_INTEGER_PART : Int64 = 999_999_999_999L

///|
const MAX_SCALE : Int = 15

///|
/// Constructs a decimal `coefficient × 10^-scale`, normalizing `-0`.
pub fn SfDecimal::new(coefficient : Int64, scale : Int) -> SfDecimal {
  if coefficient == 0L {
    return { coefficient: 0L, scale: scale.max(0) }
  }
  { coefficient, scale: scale.max(0) }
}

///|
/// Constructs a decimal from raw parts; alias of [`SfDecimal::new`].
pub fn SfDecimal::from_parts(coefficient : Int64, scale : Int) -> SfDecimal {
  SfDecimal::new(coefficient, scale)
}

///|
/// The signed coefficient.
pub fn SfDecimal::coefficient(self : SfDecimal) -> Int64 {
  self.coefficient
}

///|
/// The exponent (`value = coefficient × 10^-scale`).
pub fn SfDecimal::scale(self : SfDecimal) -> Int {
  self.scale
}

///|
/// Strips trailing zeros from the fractional part and normalizes `-0`.
/// Example: `1.200` (1200, 3) becomes `1.2` (12, 1).
pub fn SfDecimal::normalize(self : SfDecimal) -> SfDecimal {
  if self.coefficient == 0L {
    return { coefficient: 0L, scale: 0 }
  }
  let mut c = self.coefficient
  let mut s = self.scale
  while s > 0 && c % 10L == 0L {
    c = c / 10L
    s = s - 1
  }
  { coefficient: c, scale: s }
}

///|
/// Whether the value is negative (nonzero).
pub fn SfDecimal::is_negative(self : SfDecimal) -> Bool {
  self.coefficient < 0L
}

///|
/// Exact comparison. Returns a negative value if `self < other`, zero if
/// equal, positive if `self > other`.
pub fn SfDecimal::compare(self : SfDecimal, other : SfDecimal) -> Int {
  let a = self.normalize()
  let b = other.normalize()
  if a.coefficient == 0L && b.coefficient == 0L {
    return 0
  }
  if a.coefficient == 0L {
    return if b.coefficient > 0L { -1 } else { 1 }
  }
  if b.coefficient == 0L {
    return if a.coefficient > 0L { 1 } else { -1 }
  }
  let sga = if a.coefficient < 0L { -1 } else { 1 }
  let sgb = if b.coefficient < 0L { -1 } else { 1 }
  if sga != sgb {
    return if sga < sgb { -1 } else { 1 }
  }
  let mag = compare_magnitude(a, b)
  if sga > 0 {
    mag
  } else {
    -mag
  }
}

///|
fn compare_magnitude(a : SfDecimal, b : SfDecimal) -> Int {
  // Both normalized and nonzero. Compare |a| against |b| exactly.
  let da = decimal_digits(a.coefficient.abs()) + (b.scale - a.scale).max(0)
  let db = decimal_digits(b.coefficient.abs()) + (a.scale - b.scale).max(0)
  if da != db {
    return if da < db { -1 } else { 1 }
  }
  // Same digit count: scale both up to a common scale; the products are
  // then guaranteed to fit because both have the same digit count.
  let ca = if b.scale >= a.scale {
    match pow10_checked(b.scale - a.scale) {
      Some(f) => a.coefficient * f
      None => a.coefficient
    }
  } else {
    a.coefficient
  }
  let cb = if a.scale >= b.scale {
    match pow10_checked(a.scale - b.scale) {
      Some(f) => b.coefficient * f
      None => b.coefficient
    }
  } else {
    b.coefficient
  }
  // Both values have the same sign here; compare magnitudes.
  compare_i64(ca.abs(), cb.abs())
}

///|
/// Serializes the decimal per RFC 9651 §4.1.5: rounds to three decimal
/// places using ties-to-even, rejects more than twelve integer digits, and
/// always keeps at least one fractional digit.
pub fn SfDecimal::to_canonical_string(
  self : SfDecimal,
) -> Result[String, SfError] {
  if self.scale < 0 {
    return Err(SfError::make(DecimalOutOfRange, 0, "negative scale"))
  }
  if self.scale > MAX_SCALE {
    return Err(
      SfError::make(DecimalOutOfRange, 0, "scale exceeds supported precision"),
    )
  }
  let rounded = self.round_to_three()
  let mag = rounded.coefficient.abs()
  let int_part = mag / 1000L
  if int_part > MAX_INTEGER_PART {
    return Err(
      SfError::make(DecimalOutOfRange, 0, "more than 12 integer digits"),
    )
  }
  let frac = (mag % 1000L).to_int()
  let mut frac_str = frac.to_string()
  while frac_str.length() < 3 {
    frac_str = "0" + frac_str
  }
  // Strip trailing zeros but keep at least one fractional digit.
  let mut trimmed = frac_str
  while trimmed.length() > 1 && trimmed.has_suffix("0") {
    trimmed = trimmed[:trimmed.length() - 1].to_owned()
  }
  let sign = if rounded.coefficient < 0L && mag > 0L { "-" } else { "" }
  Ok(sign + int_part.to_string() + "." + trimmed)
}

///|
fn SfDecimal::round_to_three(self : SfDecimal) -> SfDecimal {
  let c = self.coefficient
  let s = self.scale
  if s <= 3 {
    match pow10_checked(3 - s) {
      Some(f) => return { coefficient: c * f, scale: 3 }
      None => return { coefficient: c, scale: s }
    }
  }
  match pow10_checked(s - 3) {
    None => { coefficient: c, scale: s }
    Some(div) => {
      let sign : Int64 = if c < 0L { -1L } else { 1L }
      let mag = c.abs()
      let q = mag / div
      let r = mag % div
      let twice = r * 2L
      if twice > div {
        return { coefficient: sign * (q + 1L), scale: 3 }
      }
      if twice == div && q % 2L != 0L {
        return { coefficient: sign * (q + 1L), scale: 3 }
      }
      return { coefficient: sign * q, scale: 3 }
    }
  }
}

///|
fn pow10_checked(n : Int) -> Int64? {
  if n < 0 || n > 18 {
    return None
  }
  let mut v : Int64 = 1L
  let mut k = n
  while k > 0 {
    v = v * 10L
    k = k - 1
  }
  Some(v)
}

///|
fn compare_i64(a : Int64, b : Int64) -> Int {
  if a < b {
    -1
  } else if a > b {
    1
  } else {
    0
  }
}

///|
fn decimal_digits(x : Int64) -> Int {
  let mut v = x.abs()
  if v == 0L {
    return 1
  }
  let mut n = 0
  while v > 0L {
    v = v / 10L
    n = n + 1
  }
  n
}
