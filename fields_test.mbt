// Tests for field token syntax and ordered field lookup (field.mbt).

///|
test "is_separator covers the RFC 2616 separator set" {
  let seps = @utf8.encode("()<>@,;:\\\"/[]?={} \t")
  for i = 0; i < seps.length(); i = i + 1 {
    assert_eq(is_separator(seps[i]), true)
  }
}

///|
test "is_token_byte accepts token characters" {
  let tok = @utf8.encode("WARC-Type_1.2*3")
  for i = 0; i < tok.length(); i = i + 1 {
    assert_eq(is_token_byte(tok[i]), true)
  }
}

///|
test "is_token_byte rejects separators and control bytes" {
  assert_eq(is_token_byte(b' '), false)
  assert_eq(is_token_byte(b'\t'), false)
  assert_eq(is_token_byte(b':'), false)
  assert_eq(is_token_byte(b'('), false)
  assert_eq(is_token_byte(b'\x01'), false)
  assert_eq(is_token_byte(b'\x7f'), false)
}

///|
test "valid_field_name accepts RFC 2616 tokens" {
  for name in ["WARC-Type", "Content-Length", "A", "a-b.c_d*e"] {
    let b = @utf8.encode(name)
    assert_eq(valid_field_name(b, 0, b.length()), true)
  }
}

///|
test "valid_field_name rejects empty and malformed names" {
  let empty = @utf8.encode("")
  assert_eq(valid_field_name(empty, 0, 0), false)
  let sp = @utf8.encode("Bad Name")
  assert_eq(valid_field_name(sp, 0, sp.length()), false)
  let colon = @utf8.encode("Bad:Name")
  assert_eq(valid_field_name(colon, 0, colon.length()), false)
  let ctl = b"\x01Name"
  assert_eq(valid_field_name(ctl, 0, ctl.length()), false)
  let high = @utf8.encode("Näme")
  assert_eq(valid_field_name(high, 0, high.length()), false)
}

///|
fn sample_record() -> WarcRecord {
  WarcRecord::new(
    "WARC/1.1",
    [
      WarcField::new("WARC-Type", "response"),
      WarcField::new("Content-Length", "5"),
      WarcField::new("content-length", "7"),
      WarcField::new("WARC-Concurrent-To", "<urn:uuid:a>"),
      WarcField::new("WARC-Concurrent-To", "<urn:uuid:b>"),
    ],
    b"hello",
  )
}

///|
test "field_first matches case-insensitively and keeps the first value" {
  let rec = sample_record()
  assert_eq(rec.field_first("CONTENT-LENGTH"), Some("5"))
  assert_eq(rec.field_first("warc-type"), Some("response"))
  assert_eq(rec.field_first("WARC-Date"), None)
}

///|
test "field_all returns every matching value in input order" {
  let rec = sample_record()
  assert_eq(rec.field_all("content-length"), ["5", "7"])
  assert_eq(rec.field_all("WARC-Concurrent-To"), [
    "<urn:uuid:a>", "<urn:uuid:b>",
  ])
  assert_eq(rec.field_all("WARC-Date"), [])
}

///|
test "field_count and field_has count case-insensitively" {
  let rec = sample_record()
  assert_eq(rec.field_count("Content-Length"), 2)
  assert_eq(rec.field_count("warc-concurrent-to"), 2)
  assert_eq(rec.field_count("WARC-Date"), 0)
  assert_eq(rec.field_has("WARC-Type"), true)
  assert_eq(rec.field_has("warc-type"), true)
  assert_eq(rec.field_has("WARC-Date"), false)
}

///|
test "field lookup does not mutate the record" {
  let rec = sample_record()
  let _ = rec.field_first("Content-Length")
  let _ = rec.field_all("content-length")
  assert_eq(rec.fields.length(), 5)
  assert_eq(rec.fields[1].name, "Content-Length")
  assert_eq(rec.fields[2].value, "7")
}
