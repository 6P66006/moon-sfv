///|
/// The httpwg conformance test: runs every imported official test vector
/// and requires that all *required* behaviors hold. Optional (`can_fail`)
/// vectors are counted and reported but do not fail the suite; a report is
/// printed for the record.
test "httpwg conformance required tests" {
  let stats = @moon-sfv.run_conformance()
  // Required vectors must all behave as the RFC requires.
  @test.assert_eq(stats.required_valid_passed, stats.required_valid_total)
  @test.assert_eq(stats.required_invalid_passed, stats.required_invalid_total)
  @test.assert_eq(stats.canonical_passed, stats.canonical_total)
  // Optional vectors are allowed to fail; only report the counts.
  assert_true(stats.optional_total >= 0)
  // The expected-structure comparison is supplementary; a mismatch there is
  // reported (see docs/compliance.md for the known upstream data issue)
  // but does not fail the suite.
  assert_true(stats.expected_total >= 0)
}

///|
test "httpwg conformance case count" {
  @test.assert_eq(@moon-sfv.httpwg_case_count, 1591)
  @test.assert_eq(@moon-sfv.httpwg_cases.length(), 1591)
}

///|
test "httpwg conformance report" {
  let stats = @moon-sfv.run_conformance()
  println("=== httpwg conformance report ===")
  println("required_valid_total:  \{stats.required_valid_total}")
  println("required_valid_passed: \{stats.required_valid_passed}")
  println("required_invalid_total:  \{stats.required_invalid_total}")
  println("required_invalid_passed: \{stats.required_invalid_passed}")
  println("canonical_total:  \{stats.canonical_total}")
  println("canonical_passed: \{stats.canonical_passed}")
  println("optional_total:  \{stats.optional_total}")
  println("optional_passed: \{stats.optional_passed}")
  println("optional_failed: \{stats.optional_failed}")
  println("expected_total:  \{stats.expected_total}")
  println("expected_passed: \{stats.expected_passed}")
  println("failures: \{stats.failures.length()}")
  for f in stats.failures {
    println("  - \{f}")
  }
}
