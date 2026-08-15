// Tests for Content-Length handling (content_length.mbt).

///|
fn fields_with(cl : String) -> Array[WarcField] {
  [
    WarcField::new("WARC-Type", "response"),
    WarcField::new("Content-Length", cl),
  ]
}

///|
test "parse_content_length accepts decimal values" {
  assert_eq(
    parse_content_length(fields_with("42"), Limits::default(), 0L).unwrap(),
    42L,
  )
  assert_eq(
    parse_content_length(fields_with("0"), Limits::default(), 0L).unwrap(),
    0L,
  )
  assert_eq(
    parse_content_length(fields_with("00042"), Limits::default(), 0L).unwrap(),
    42L,
  )
}

///|
test "parse_content_length matches the field name case-insensitively" {
  let fields = [
    WarcField::new("WARC-Type", "response"),
    WarcField::new("content-length", "7"),
  ]
  assert_eq(parse_content_length(fields, Limits::default(), 0L).unwrap(), 7L)
}

///|
test "parse_content_length requires the field" {
  let fields = [WarcField::new("WARC-Type", "response")]
  let r = parse_content_length(fields, Limits::default(), 0L)
  match r {
    Ok(_) => fail("expected a missing-required-field error")
    Err(e) => {
      assert_eq(e.kind.kind_name(), "missing-required-field")
      assert_eq(e.stage, stage_of_code("content-length").unwrap())
    }
  }
}

///|
test "parse_content_length rejects repeated fields" {
  let fields = [
    WarcField::new("Content-Length", "3"),
    WarcField::new("content-length", "4"),
  ]
  let r = parse_content_length(fields, Limits::default(), 0L)
  match r {
    Ok(_) => fail("expected a duplicate-field error")
    Err(e) => assert_eq(e.kind.kind_name(), "duplicate-field")
  }
}

///|
test "parse_content_length rejects non-decimal values" {
  for bad in ["", "abc", "12x", "-5", " 42 "] {
    let r = parse_content_length(fields_with(bad), Limits::default(), 0L)
    match r {
      Ok(_) => fail("expected an invalid-content-length error for: " + bad)
      Err(e) => assert_eq(e.kind.kind_name(), "invalid-content-length")
    }
  }
}

///|
test "parse_content_length rejects overflow beyond Int64" {
  let r = parse_content_length(
    fields_with("9223372036854775808"),
    Limits::default(),
    0L,
  )
  match r {
    Ok(_) => fail("expected an integer-overflow error")
    Err(e) => assert_eq(e.kind.kind_name(), "integer-overflow")
  }
}

///|
test "parse_content_length enforces max_content_length_digits" {
  let l = Limits::default().with_max_content_length_digits(2)
  let r = parse_content_length(fields_with("123"), l, 0L)
  match r {
    Ok(_) => fail("expected an integer-overflow error")
    Err(e) => assert_eq(e.kind.kind_name(), "integer-overflow")
  }
}

///|
test "parse_content_length enforces max_block_bytes" {
  let l = Limits::default().with_max_block_bytes(10L)
  let r = parse_content_length(fields_with("11"), l, 0L)
  match r {
    Ok(_) => fail("expected a limit-exceeded error")
    Err(e) => {
      assert_eq(e.kind.kind_name(), "limit-exceeded")
      assert_eq(e.stage, stage_of_code("content-length").unwrap())
    }
  }
}

///|
test "parse_content_length carries the record index" {
  let r = parse_content_length(fields_with("abc"), Limits::default(), 5L)
  match r {
    Ok(_) => fail("expected an invalid-content-length error")
    Err(e) => assert_eq(e.record_index, 5L)
  }
}
