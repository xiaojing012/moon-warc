// Tests for WARC header parsing (header.mbt).

///|
test "parse_header parses fields up to the blank line" {
  let b = @utf8.encode("WARC-Type: response\r\nContent-Length: 5\r\n\r\nhello")
  let r = parse_header(b, 0, Limits::default(), 0L)
  match r {
    Ok((fields, next)) => {
      assert_eq(fields.length(), 2)
      assert_eq(fields[0].name, "WARC-Type")
      assert_eq(fields[0].value, "response")
      assert_eq(fields[1].name, "Content-Length")
      assert_eq(fields[1].value, "5")
      assert_eq(next, 42)
    }
    Err(e) => fail("expected a parsed header, got " + e.to_string())
  }
}

///|
test "parse_header accepts an empty header" {
  let b = @utf8.encode("\r\nblock")
  let r = parse_header(b, 0, Limits::default(), 0L)
  match r {
    Ok((fields, next)) => {
      assert_eq(fields.length(), 0)
      assert_eq(next, 2)
    }
    Err(e) => fail("expected an empty header, got " + e.to_string())
  }
}

///|
test "parse_header strips leading LWS from field values" {
  let b = @utf8.encode("A:   x \r\nB:\ty\t\r\n\r\n")
  let r = parse_header(b, 0, Limits::default(), 0L)
  match r {
    Ok((fields, _)) => {
      assert_eq(fields[0].value, "x ")
      assert_eq(fields[1].value, "y\t")
    }
    Err(e) => fail("expected parsed fields, got " + e.to_string())
  }
}

///|
test "parse_header splits at the first colon only" {
  let b = @utf8.encode("X: a:b:c\r\n\r\n")
  let r = parse_header(b, 0, Limits::default(), 0L)
  match r {
    Ok((fields, _)) => assert_eq(fields[0].value, "a:b:c")
    Err(e) => fail("expected parsed fields, got " + e.to_string())
  }
}

///|
test "parse_header folds continuation lines into the previous value" {
  let b = @utf8.encode("X: one\r\n two\r\n\tthree\r\n\r\n")
  let r = parse_header(b, 0, Limits::default(), 0L)
  match r {
    Ok((fields, _)) => {
      assert_eq(fields.length(), 1)
      assert_eq(fields[0].value, "one two three")
    }
    Err(e) => fail("expected folded value, got " + e.to_string())
  }
}

///|
test "parse_header rejects a leading continuation line" {
  let b = @utf8.encode(" orphan\r\n\r\n")
  let r = parse_header(b, 0, Limits::default(), 0L)
  match r {
    Ok(_) => fail("expected an invalid-field-name error")
    Err(e) => {
      assert_eq(e.kind.kind_name(), "invalid-field-name")
      assert_eq(e.stage, stage_of_code("field").unwrap())
    }
  }
}

///|
test "parse_header rejects a field line without a colon" {
  let b = @utf8.encode("NoColon\r\n\r\n")
  let r = parse_header(b, 0, Limits::default(), 0L)
  match r {
    Ok(_) => fail("expected a missing-colon error")
    Err(e) => assert_eq(e.kind.kind_name(), "missing-colon")
  }
}

///|
test "parse_header rejects invalid field names" {
  let bad = ["Bad Name: x\r\n\r\n", "Bad(Name): x\r\n\r\n", ": x\r\n\r\n"]
  for i = 0; i < bad.length(); i = i + 1 {
    let b = @utf8.encode(bad[i])
    let r = parse_header(b, 0, Limits::default(), 0L)
    match r {
      Ok(_) => fail("expected an invalid-field-name error for: " + bad[i])
      Err(e) => assert_eq(e.kind.kind_name(), "invalid-field-name")
    }
  }
}

///|
test "parse_header rejects invalid UTF-8 in field values" {
  let b = b"X: \xff\xfe\r\n\r\n"
  let r = parse_header(b, 0, Limits::default(), 0L)
  match r {
    Ok(_) => fail("expected an invalid-utf8 error")
    Err(e) => assert_eq(e.kind.kind_name(), "invalid-utf8")
  }
}

///|
test "parse_header rejects invalid UTF-8 in field names" {
  let b = b"X\xff: v\r\n\r\n"
  let r = parse_header(b, 0, Limits::default(), 0L)
  match r {
    Ok(_) => fail("expected an invalid-field-name error")
    Err(e) => assert_eq(e.kind.kind_name(), "invalid-field-name")
  }
}

///|
test "parse_header propagates unterminated input" {
  let b = @utf8.encode("A: 1")
  let r = parse_header(b, 0, Limits::default(), 0L)
  match r {
    Ok(_) => fail("expected an EOF error")
    Err(e) => assert_eq(e.kind.kind_name(), "unexpected-eof")
  }
}

///|
test "parse_header enforces max_header_count" {
  let l = Limits::default().with_max_header_count(1)
  let b = @utf8.encode("A: 1\r\nB: 2\r\n\r\n")
  let r = parse_header(b, 0, l, 0L)
  match r {
    Ok(_) => fail("expected a limit-exceeded error")
    Err(e) => {
      assert_eq(e.kind.kind_name(), "limit-exceeded")
      assert_eq(e.stage, stage_of_code("header").unwrap())
    }
  }
}

///|
test "parse_header enforces max_header_bytes" {
  let l = Limits::default().with_max_header_bytes(10L)
  let b = @utf8.encode("A: 1\r\nB: 2\r\n\r\n")
  let r = parse_header(b, 0, l, 0L)
  match r {
    Ok(_) => fail("expected a limit-exceeded error")
    Err(e) => assert_eq(e.kind.kind_name(), "limit-exceeded")
  }
}

///|
test "parse_header enforces max_field_name_bytes" {
  let l = Limits::default().with_max_field_name_bytes(4)
  let b = @utf8.encode("LongName: x\r\n\r\n")
  let r = parse_header(b, 0, l, 0L)
  match r {
    Ok(_) => fail("expected a limit-exceeded error")
    Err(e) => assert_eq(e.kind.kind_name(), "limit-exceeded")
  }
}

///|
test "parse_header enforces max_field_value_bytes" {
  let l = Limits::default().with_max_field_value_bytes(4)
  let b = @utf8.encode("A: longvalue\r\n\r\n")
  let r = parse_header(b, 0, l, 0L)
  match r {
    Ok(_) => fail("expected a limit-exceeded error")
    Err(e) => assert_eq(e.kind.kind_name(), "limit-exceeded")
  }
}

///|
test "parse_header enforces max_field_value_bytes on folded values" {
  let l = Limits::default().with_max_field_value_bytes(6)
  let b = @utf8.encode("X: one\r\n two\r\n\r\n")
  let r = parse_header(b, 0, l, 0L)
  match r {
    Ok(_) => fail("expected a limit-exceeded error")
    Err(e) => assert_eq(e.kind.kind_name(), "limit-exceeded")
  }
}

///|
test "parse_header carries the record index into errors" {
  let b = @utf8.encode("NoColon\r\n\r\n")
  let r = parse_header(b, 0, Limits::default(), 9L)
  match r {
    Ok(_) => fail("expected a missing-colon error")
    Err(e) => assert_eq(e.record_index, 9L)
  }
}
