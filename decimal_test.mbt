// Tests for overflow-safe decimal parsing (decimal.mbt).

///|
test "parse_decimal accepts zero and small values" {
  let b = @utf8.encode("0")
  assert_eq(parse_decimal(b, 0, 1, 19, "Content-Length").unwrap(), 0L)
  let b1 = @utf8.encode("1")
  assert_eq(parse_decimal(b1, 0, 1, 19, "Content-Length").unwrap(), 1L)
  let b9 = @utf8.encode("9")
  assert_eq(parse_decimal(b9, 0, 1, 19, "Content-Length").unwrap(), 9L)
  let b10 = @utf8.encode("10")
  assert_eq(parse_decimal(b10, 0, 2, 19, "Content-Length").unwrap(), 10L)
  let b42 = @utf8.encode("42")
  assert_eq(parse_decimal(b42, 0, 2, 19, "Content-Length").unwrap(), 42L)
}

///|
test "parse_decimal accepts Int64 max value" {
  let b = @utf8.encode("9223372036854775807")
  assert_eq(
    parse_decimal(b, 0, 19, 19, "Content-Length").unwrap(),
    9_223_372_036_854_775_807L,
  )
}

///|
test "parse_decimal rejects values beyond Int64" {
  let b = @utf8.encode("9223372036854775808")
  let r = parse_decimal(b, 0, 19, 19, "Content-Length")
  match r {
    Ok(_) => fail("expected overflow error")
    Err(e) => {
      assert_eq(e.kind.kind_name(), "integer-overflow")
      assert_eq(e.stage, stage_of_code("number").unwrap())
    }
  }
}

///|
test "parse_decimal rejects huge digit runs without wrapping" {
  let b = @utf8.encode("99999999999999999999999999999999")
  let r = parse_decimal(b, 0, b.length(), 19, "Content-Length")
  match r {
    Ok(_) => fail("expected overflow error")
    Err(e) => assert_eq(e.kind.kind_name(), "integer-overflow")
  }
}

///|
test "parse_decimal rejects empty spans" {
  let b = @utf8.encode("")
  let r = parse_decimal(b, 0, 0, 19, "Content-Length")
  match r {
    Ok(_) => fail("expected error for empty value")
    Err(e) => assert_eq(e.kind.kind_name(), "invalid-content-length")
  }
}

///|
test "parse_decimal rejects non-digit bytes" {
  let b = @utf8.encode("12x4")
  let r = parse_decimal(b, 0, 4, 19, "Content-Length")
  match r {
    Ok(_) => fail("expected error for non-digit byte")
    Err(e) => assert_eq(e.kind.kind_name(), "invalid-content-length")
  }
}

///|
test "parse_decimal enforces max_digits" {
  let b = @utf8.encode("12345678901") // 11 digits
  let r = parse_decimal(b, 0, b.length(), 10, "Content-Length")
  match r {
    Ok(_) => fail("expected digit limit error")
    Err(e) => assert_eq(e.kind.kind_name(), "integer-overflow")
  }
}

///|
test "parse_decimal accepts leading zeros" {
  let b = @utf8.encode("00042")
  assert_eq(parse_decimal(b, 0, 5, 19, "Content-Length").unwrap(), 42L)
}

///|
test "parse_decimal parses a span inside a larger buffer" {
  let b = @utf8.encode("xx42yy")
  assert_eq(parse_decimal(b, 2, 4, 19, "Content-Length").unwrap(), 42L)
}

///|
test "append_decimal_digit accumulates without overflow" {
  assert_eq(append_decimal_digit(4L, 2), Some(42L))
  assert_eq(append_decimal_digit(0L, 0), Some(0L))
  assert_eq(
    append_decimal_digit(922_337_203_685_477_580L, 7),
    Some(9_223_372_036_854_775_807L),
  )
}

///|
test "append_decimal_digit reports overflow" {
  assert_eq(append_decimal_digit(9_223_372_036_854_775_807L, 1), None)
  assert_eq(append_decimal_digit(9_223_372_036_854_775_807L, 9), None)
  assert_eq(append_decimal_digit(9_223_372_036_854_775_806L, 9), None)
}

///|
test "append_decimal_digit rejects non-digits" {
  assert_eq(append_decimal_digit(1L, 10), None)
  assert_eq(append_decimal_digit(1L, -1), None)
}

///|
test "digit_count counts leading digits" {
  let b = @utf8.encode("123abc")
  assert_eq(digit_count(b, 0, b.length()), 3)
  let b2 = @utf8.encode("abc")
  assert_eq(digit_count(b2, 0, b2.length()), 0)
  let b3 = @utf8.encode("123456")
  assert_eq(digit_count(b3, 0, b3.length()), 6)
  let b4 = @utf8.encode("123456")
  assert_eq(digit_count(b4, 2, 4), 2)
}
