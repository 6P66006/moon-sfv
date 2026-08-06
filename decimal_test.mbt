///|
/// Tests for the exact decimal representation and its serialization rules.
fn str_of(item : Result[String, @moon-sfv.SfError]) -> String {
  match item {
    Err(e) => "ERR:\{e.to_string()}"
    Ok(s) => s
  }
}

///|
test "decimal construction and negative zero" {
  @test.assert_eq(
    @moon-sfv.SfDecimal::new(45L, 1),
    @moon-sfv.SfDecimal::from_parts(45L, 1),
  )
  // negative zero normalizes to zero
  @test.assert_eq(@moon-sfv.SfDecimal::new(0L, 3).coefficient(), 0L)
  @test.assert_eq(@moon-sfv.SfDecimal::new(-0L, 2).coefficient(), 0L)
  // scale is clamped to >= 0
  @test.assert_eq(@moon-sfv.SfDecimal::new(5L, -3).scale(), 0)
}

///|
test "normalize strips trailing zeros" {
  @test.assert_eq(
    @moon-sfv.SfDecimal::new(1200L, 3).normalize(),
    @moon-sfv.SfDecimal::new(12L, 1),
  )
  @test.assert_eq(
    @moon-sfv.SfDecimal::new(1000L, 3).normalize(),
    @moon-sfv.SfDecimal::new(1L, 0),
  )
  @test.assert_eq(
    @moon-sfv.SfDecimal::new(0L, 5).normalize(),
    @moon-sfv.SfDecimal::new(0L, 0),
  )
  @test.assert_eq(
    @moon-sfv.SfDecimal::new(123L, 3).normalize(),
    @moon-sfv.SfDecimal::new(123L, 3),
  )
}

///|
test "decimal serialization basics" {
  @test.assert_eq(
    str_of(@moon-sfv.SfDecimal::new(45L, 1).to_canonical_string()),
    "4.5",
  )
  @test.assert_eq(
    str_of(@moon-sfv.SfDecimal::new(123L, 2).to_canonical_string()),
    "1.23",
  )
  @test.assert_eq(
    str_of(@moon-sfv.SfDecimal::new(125L, 3).to_canonical_string()),
    "0.125",
  )
  @test.assert_eq(
    str_of(@moon-sfv.SfDecimal::new(-125L, 3).to_canonical_string()),
    "-0.125",
  )
  @test.assert_eq(
    str_of(@moon-sfv.SfDecimal::new(0L, 0).to_canonical_string()),
    "0.0",
  )
  @test.assert_eq(
    str_of(@moon-sfv.SfDecimal::new(0L, 3).to_canonical_string()),
    "0.0",
  )
  // trailing zeros are stripped but at least one fractional digit remains
  @test.assert_eq(
    str_of(@moon-sfv.SfDecimal::new(1230L, 3).to_canonical_string()),
    "1.23",
  )
  @test.assert_eq(
    str_of(@moon-sfv.SfDecimal::new(1200L, 3).to_canonical_string()),
    "1.2",
  )
  @test.assert_eq(
    str_of(@moon-sfv.SfDecimal::new(5L, 1).to_canonical_string()),
    "0.5",
  )
  @test.assert_eq(
    str_of(@moon-sfv.SfDecimal::new(100L, 3).to_canonical_string()),
    "0.1",
  )
}

///|
test "decimal rounding is ties-to-even" {
  // 0.0015 -> 0.002 (1.5 rounds to even 2)
  @test.assert_eq(
    str_of(@moon-sfv.SfDecimal::new(15L, 4).to_canonical_string()),
    "0.002",
  )
  // 0.0025 -> 0.002 (2.5 rounds to even 2)
  @test.assert_eq(
    str_of(@moon-sfv.SfDecimal::new(25L, 4).to_canonical_string()),
    "0.002",
  )
  // -0.0015 -> -0.002
  @test.assert_eq(
    str_of(@moon-sfv.SfDecimal::new(-15L, 4).to_canonical_string()),
    "-0.002",
  )
  // -0.0025 -> -0.002
  @test.assert_eq(
    str_of(@moon-sfv.SfDecimal::new(-25L, 4).to_canonical_string()),
    "-0.002",
  )
  // 9.9995 -> 10.0
  @test.assert_eq(
    str_of(@moon-sfv.SfDecimal::new(99995L, 4).to_canonical_string()),
    "10.0",
  )
  // 0.0014 -> 0.001
  @test.assert_eq(
    str_of(@moon-sfv.SfDecimal::new(14L, 4).to_canonical_string()),
    "0.001",
  )
  // 0.0016 -> 0.002
  @test.assert_eq(
    str_of(@moon-sfv.SfDecimal::new(16L, 4).to_canonical_string()),
    "0.002",
  )
}

///|
test "decimal integer part overflow is rejected" {
  // 13 integer digits
  let too_big = @moon-sfv.SfDecimal::new(1_000_000_000_000_123L, 3)
  match too_big.to_canonical_string() {
    Err(e) => @test.assert_eq(e.kind(), @moon-sfv.DecimalOutOfRange)
    Ok(_) => assert_true(false)
  }
  // exactly 12 integer digits is fine
  @test.assert_eq(
    str_of(
      @moon-sfv.SfDecimal::new(999_999_999_999_999L, 3).to_canonical_string(),
    ),
    "999999999999.999",
  )
}

///|
test "decimal exact comparison" {
  @test.assert_eq(
    @moon-sfv.SfDecimal::new(12L, 1).compare(@moon-sfv.SfDecimal::new(120L, 2)),
    0,
  )
  @test.assert_eq(
    @moon-sfv.SfDecimal::new(45L, 1).compare(@moon-sfv.SfDecimal::new(46L, 1)),
    -1,
  )
  @test.assert_eq(
    @moon-sfv.SfDecimal::new(46L, 1).compare(@moon-sfv.SfDecimal::new(45L, 1)),
    1,
  )
  @test.assert_eq(
    @moon-sfv.SfDecimal::new(-125L, 3).compare(
      @moon-sfv.SfDecimal::new(-124L, 3),
    ),
    -1,
  )
  @test.assert_eq(
    @moon-sfv.SfDecimal::new(0L, 2).compare(@moon-sfv.SfDecimal::new(0L, 0)),
    0,
  )
  @test.assert_eq(
    @moon-sfv.SfDecimal::new(-1L, 1).compare(@moon-sfv.SfDecimal::new(0L, 1)),
    -1,
  )
  @test.assert_eq(
    @moon-sfv.SfDecimal::new(1L, 1).compare(@moon-sfv.SfDecimal::new(-1L, 1)),
    1,
  )
  @test.assert_eq(
    @moon-sfv.SfDecimal::new(1L, 3).compare(@moon-sfv.SfDecimal::new(999L, 3)),
    -1,
  )
  @test.assert_eq(
    @moon-sfv.SfDecimal::new(-999L, 3).compare(@moon-sfv.SfDecimal::new(-1L, 3)),
    -1,
  )
}
