// Tests for raw byte helpers (bytes.mbt).

///|
test "ASCII classification covers control and whitespace bytes" {
  assert_true(is_cr(b'\r'))
  assert_false(is_cr(b'\n'))
  assert_true(is_lf(b'\n'))
  assert_false(is_lf(b'\r'))
  assert_true(is_sp(b' '))
  assert_false(is_sp(b'\t'))
  assert_true(is_ht(b'\t'))
  assert_true(is_digit(b'0'))
  assert_true(is_digit(b'9'))
  assert_false(is_digit(b'a'))
  assert_true(is_upper_ascii(b'A'))
  assert_true(is_upper_ascii(b'Z'))
  assert_false(is_upper_ascii(b'z'))
  assert_true(is_lower_ascii(b'a'))
  assert_true(is_ctl(b'\x00'))
  assert_true(is_ctl(b'\x1f'))
  assert_true(is_ctl(b'\x7f'))
  assert_false(is_ctl(b' '))
}

///|
test "lower_ascii lower-cases letters only" {
  assert_eq(lower_ascii(b'A'), b'a')
  assert_eq(lower_ascii(b'Z'), b'z')
  assert_eq(lower_ascii(b'a'), b'a')
  assert_eq(lower_ascii(b'0'), b'0')
  assert_eq(lower_ascii(b'-'), b'-')
  assert_eq(lower_ascii(b'\x80'), b'\x80')
}

///|
test "digit_value maps digits to 0..9" {
  assert_eq(digit_value(b'0'), 0)
  assert_eq(digit_value(b'5'), 5)
  assert_eq(digit_value(b'9'), 9)
  assert_eq(digit_value(b'a'), -1)
  assert_eq(digit_value(b' '), -1)
}

///|
test "eq_ignore_ascii_case compares case-insensitively" {
  let d = @utf8.encode("WARC-Type: response")
  assert_true(eq_ignore_ascii_case(d, 0, 9, "warc-type"))
  assert_true(eq_ignore_ascii_case(d, 0, 9, "WARC-TYPE"))
  assert_false(eq_ignore_ascii_case(d, 0, 9, "warc-typex"))
  assert_false(eq_ignore_ascii_case(d, 0, 10, "warc-type"))
  assert_true(eq_ignore_ascii_case(d, 0, 0, ""))
}

///|
test "starts_with matches byte prefixes" {
  let d = @utf8.encode("WARC/1.1\r\n")
  assert_true(starts_with(d, @utf8.encode("WARC/")))
  assert_true(starts_with(d, d))
  assert_false(starts_with(d, @utf8.encode("WARC/1.1\r\nx")))
  assert_false(starts_with(d, @utf8.encode("warc/")))
}

///|
test "index_of_byte finds first occurrence from a start offset" {
  let d = @utf8.encode("a:b:c")
  assert_eq(index_of_byte(d, 0, b':'), 1)
  assert_eq(index_of_byte(d, 2, b':'), 3)
  assert_eq(index_of_byte(d, 4, b':'), -1)
  assert_eq(index_of_byte(d, 0, b'z'), -1)
}

///|
test "find_crlf locates CRLF pairs" {
  let d = @utf8.encode("a\r\nb\r\n")
  assert_eq(find_crlf(d, 0), 1)
  assert_eq(find_crlf(d, 2), 4)
  assert_eq(find_crlf(d, 5), -1)
}

///|
test "find_crlf ignores a trailing lone CR" {
  let d = @utf8.encode("abc\r")
  assert_eq(find_crlf(d, 0), -1)
}

///|
test "find_crlf ignores CR at the end of the buffer" {
  let d = @utf8.encode("a\r\nb\r")
  assert_eq(find_crlf(d, 0), 1)
  assert_eq(find_crlf(d, 2), -1)
}

///|
test "find_crlf handles empty buffers" {
  assert_eq(find_crlf(@utf8.encode(""), 0), -1)
  assert_eq(find_crlf(@utf8.encode("\r\n"), 0), 0)
}

///|
test "all_digits detects digit-only spans" {
  assert_true(all_digits(@utf8.encode("123"), 0, 3))
  assert_false(all_digits(@utf8.encode("12a"), 0, 3))
  assert_true(all_digits(@utf8.encode("12a"), 0, 2))
  assert_true(all_digits(@utf8.encode(""), 0, 0))
}
