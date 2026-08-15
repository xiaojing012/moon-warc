// Tests for record serialization and the record builder
// (writer.mbt, builder.mbt). Helpers cat() and make_record() come
// from framing_test.mbt, rec_eq() from decoder_test.mbt.

///|
test "to_bytes writes the canonical record form" {
  let data = make_record(b"hello")
  let rec = parse_record(data, 0, Limits::default(), 0L).unwrap().0
  let bytes = rec.to_bytes()
  assert_eq(
    eq_bytes(
      bytes,
      0,
      bytes.length(),
      "WARC/1.1\r\nWARC-Type: response\r\nContent-Length: 5\r\n\r\nhello\r\n\r\n",
    ),
    true,
  )
  assert_eq(bytes.length(), data.length())
}

///|
test "to_bytes round-trips through the parser" {
  let archives : Array[Bytes] = [
    make_record(b"hello"),
    make_record(b""),
    make_record(b"\x00\x01\xffWARC/1.1\r\n\r\n"),
  ]
  for i = 0; i < archives.length(); i = i + 1 {
    let data = archives[i]
    let a = parse_archive(data, Limits::default()).unwrap()
    let rec = a.record(0).unwrap()
    let bytes = rec.to_bytes()
    let back = parse_record(bytes, 0, Limits::default(), 0L).unwrap().0
    assert_eq(rec_eq(rec, back), true)
    // The canonical form feeds the streaming decoder identically.
    let got = run_decoder(bytes, [bytes.length()])
    match got {
      Ok(recs) => {
        assert_eq(recs.length(), 1)
        assert_eq(rec_eq(rec, recs[0]), true)
      }
      Err(e) => fail("decoder rejected the written record: " + e.to_string())
    }
  }
}

///|
test "builder generates Content-Length from the block" {
  let rec = WarcBuilder::new()
    .with_type("response")
    .record_id("<urn:uuid:1234>")
    .warc_date("2010-11-13T01:36:57Z")
    .target_uri("<http://example.org/>")
    .build(b"payload")
    .unwrap()
  assert_eq(rec.declared_content_length(), Some("7"))
  assert_eq(rec.record_id(0L).unwrap(), "urn:uuid:1234")
  assert_eq(rec.warc_date(0L).unwrap().year, 2010)
  assert_eq(rec.target_uri(0L).unwrap(), "http://example.org/")
  let bytes = rec.to_bytes()
  let back = parse_record(bytes, 0, Limits::default(), 0L).unwrap().0
  assert_eq(rec_eq(rec, back), true)
}

///|
test "builder serializes byte-for-byte deterministically" {
  let b1 = WarcBuilder::new()
    .with_type("response")
    .build(b"x")
    .unwrap()
    .to_bytes()
  let b2 = WarcBuilder::new()
    .with_type("response")
    .build(b"x")
    .unwrap()
    .to_bytes()
  assert_eq(b1.length(), b2.length())
  assert_eq(
    eq_bytes(
      b1,
      0,
      b1.length(),
      "WARC/1.1\r\nWARC-Type: response\r\nContent-Length: 1\r\n\r\nx\r\n\r\n",
    ),
    true,
  )
  for i = 0; i < b1.length(); i = i + 1 {
    assert_eq(b1[i], b2[i])
  }
}

///|
test "builder accepts a matching declared Content-Length" {
  let rec = WarcBuilder::new()
    .field("Content-Length", "3")
    .field("WARC-Type", "resource")
    .build(b"abc")
    .unwrap()
  assert_eq(rec.declared_content_length(), Some("3"))
  assert_eq(rec.block_length(), 3)
}

///|
test "builder rejects a Content-Length that does not match the block" {
  let r = WarcBuilder::new().field("Content-Length", "99").build(b"abc")
  match r {
    Ok(_) => fail("expected a content-length-mismatch error")
    Err(e) => {
      assert_eq(e.kind.kind_name(), "content-length-mismatch")
      assert_eq(e.stage, stage_of_code("builder").unwrap())
    }
  }
}

///|
test "builder rejects a repeated Content-Length" {
  let r = WarcBuilder::new()
    .field("Content-Length", "0")
    .field("content-length", "0")
    .build(b"")
  match r {
    Ok(_) => fail("expected a duplicate-field error")
    Err(e) => assert_eq(e.kind.kind_name(), "duplicate-field")
  }
}

///|
test "builder rejects a non-decimal Content-Length" {
  let r = WarcBuilder::new().field("Content-Length", "5x").build(b"abcde")
  match r {
    Ok(_) => fail("expected an invalid-content-length error")
    Err(e) => assert_eq(e.kind.kind_name(), "invalid-content-length")
  }
}

///|
test "builder rejects illegal field names" {
  for bad in ["", "Bad Name", "Bad:Name", "Name"] {
    let r = WarcBuilder::new().field(bad, "x").build(b"")
    match r {
      Ok(_) => fail("expected an invalid-field-name error for: " + bad)
      Err(e) => {
        assert_eq(e.kind.kind_name(), "invalid-field-name")
        assert_eq(e.stage, stage_of_code("builder").unwrap())
      }
    }
  }
}

///|
test "builder rejects field values that would break the line structure" {
  for bad in ["a\rb", "a\nb", "a\r\nb", "trailing\r"] {
    let r = WarcBuilder::new().field("X-Note", bad).build(b"")
    match r {
      Ok(_) => fail("expected an invalid-field-value error")
      Err(e) => assert_eq(e.kind.kind_name(), "invalid-field-value")
    }
  }
}

///|
test "builder rejects a version other than WARC/1.1" {
  let r = WarcBuilder::new().version("WARC/1.0").build(b"")
  match r {
    Ok(_) => fail("expected an invalid-version error")
    Err(e) => assert_eq(e.kind.kind_name(), "invalid-version")
  }
}

///|
test "builder output round-trips through the whole archive parser" {
  let r1 = WarcBuilder::new()
    .with_type("response")
    .record_id("<urn:uuid:1>")
    .build(b"one")
    .unwrap()
  let r2 = WarcBuilder::new()
    .with_type("resource")
    .record_id("<urn:uuid:2>")
    .build(b"\x00two")
    .unwrap()
  let archive = cat(r1.to_bytes(), r2.to_bytes())
  let a = parse_archive(archive, Limits::default()).unwrap()
  assert_eq(a.record_count(), 2)
  assert_eq(rec_eq(a.record(0).unwrap(), r1), true)
  assert_eq(rec_eq(a.record(1).unwrap(), r2), true)
}

///|
test "builder field order and spelling are preserved on write" {
  let rec = WarcBuilder::new()
    .field("X-First", "1")
    .field("warc-type", "metadata")
    .field("X-First", "2")
    .build(b"")
    .unwrap()
  let bytes = rec.to_bytes()
  let back = parse_record(bytes, 0, Limits::default(), 0L).unwrap().0
  assert_eq(back.fields.length(), 4)
  assert_eq(back.fields[0].name, "X-First")
  assert_eq(back.fields[0].value, "1")
  assert_eq(back.fields[1].name, "warc-type")
  assert_eq(back.fields[2].name, "X-First")
  assert_eq(back.fields[2].value, "2")
  assert_eq(back.fields[3].name, "Content-Length")
}
