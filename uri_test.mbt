// Tests for URI reference values (uri.mbt).

///|
test "parse_uri_ref accepts URI references" {
  assert_eq(parse_uri_ref("<urn:uuid:1234>", 0L).unwrap(), "urn:uuid:1234")
  assert_eq(
    parse_uri_ref("<http://example.org/a?b=c#d>", 0L).unwrap(),
    "http://example.org/a?b=c#d",
  )
  assert_eq(
    parse_uri_ref("<https://example.org/>", 0L).unwrap(),
    "https://example.org/",
  )
}

///|
test "parse_uri_ref accepts non-empty relative forms" {
  assert_eq(parse_uri_ref("<path/to/file>", 0L).unwrap(), "path/to/file")
}

///|
test "parse_uri_ref rejects values without angle brackets" {
  for
    bad in [
      "urn:uuid:1234", "<urn:uuid:1234", "urn:uuid:1234>", "<>", "", "< >",
    ] {
    let r = parse_uri_ref(bad, 0L)
    match r {
      Ok(_) => fail("expected an invalid-uri error for: " + bad)
      Err(e) => assert_eq(e.kind.kind_name(), "invalid-uri")
    }
  }
}

///|
test "parse_uri_ref rejects whitespace and control characters" {
  for bad in ["<a b>", "<a\tb>", "<a\rb>", "<a\nb>", "<a\u0001b>"] {
    let r = parse_uri_ref(bad, 0L)
    match r {
      Ok(_) => fail("expected an invalid-uri error for: " + bad)
      Err(e) => assert_eq(e.kind.kind_name(), "invalid-uri")
    }
  }
}

///|
test "parse_uri_ref errors carry stage and record index" {
  let r = parse_uri_ref("plain", 4L)
  match r {
    Ok(_) => fail("expected an invalid-uri error")
    Err(e) => {
      assert_eq(e.stage, stage_of_code("uri").unwrap())
      assert_eq(e.record_index, 4L)
    }
  }
}
