// Tests for WARC version line parsing (version.mbt).

///|
test "parse_version_line accepts the exact WARC/1.1 spelling" {
  let b = @utf8.encode("WARC/1.1")
  let r = parse_version_line(b, 0, b.length(), 0L)
  match r {
    Ok(v) => assert_eq(v, "WARC/1.1")
    Err(e) => fail("expected WARC/1.1 to be accepted, got " + e.to_string())
  }
}

///|
test "parse_version_line rejects WARC/1.0" {
  let b = @utf8.encode("WARC/1.0")
  let r = parse_version_line(b, 0, b.length(), 0L)
  match r {
    Ok(_) => fail("expected WARC/1.0 to be rejected")
    Err(e) => {
      assert_eq(e.kind.kind_name(), "invalid-version")
      assert_eq(e.stage, stage_of_code("version").unwrap())
    }
  }
}

///|
test "parse_version_line rejects other spellings" {
  let cases = [
    "WARC/2.0", "WARC/1.0.1", "WARC 1.1", "WARC/1.1 ", "warc/1.1", "WARC/1.1\r",
    "WARC/1.1\n", "http/1.1", "",
  ]
  for i = 0; i < cases.length(); i = i + 1 {
    let b = @utf8.encode(cases[i])
    let r = parse_version_line(b, 0, b.length(), 0L)
    match r {
      Ok(_) => fail("expected rejection of: " + cases[i])
      Err(e) => assert_eq(e.kind.kind_name(), "invalid-version")
    }
  }
}

///|
test "parse_version_line honors the given span" {
  let b = @utf8.encode("xxWARC/1.1yy")
  let r = parse_version_line(b, 2, 10, 0L)
  match r {
    Ok(v) => assert_eq(v, "WARC/1.1")
    Err(e) => fail("expected the span to match, got " + e.to_string())
  }
}

///|
test "parse_version_line reports the span start as byte offset" {
  let b = @utf8.encode("---WARC/1.0")
  let r = parse_version_line(b, 3, b.length(), 7L)
  match r {
    Ok(_) => fail("expected WARC/1.0 to be rejected")
    Err(e) => {
      assert_eq(e.byte_offset, 3L)
      assert_eq(e.record_index, 7L)
    }
  }
}
