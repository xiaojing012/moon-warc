// Tests for whole-archive parsing (archive.mbt).
// Shared helpers cat() and make_record() come from framing_test.mbt.

///|
test "parse_archive accepts an empty file as zero records" {
  let a = parse_archive(b"", Limits::default()).unwrap()
  assert_eq(a.record_count(), 0)
  assert_eq(a.record(0) is None, true)
  assert_eq(a.total_block_bytes(), 0L)
}

///|
test "parse_archive parses a single record" {
  let data = make_record(b"hello")
  let a = parse_archive(data, Limits::default()).unwrap()
  assert_eq(a.record_count(), 1)
  let r = a.record(0).unwrap()
  assert_eq(r.version, "WARC/1.1")
  assert_eq(eq_bytes(r.block, 0, 5, "hello"), true)
  assert_eq(a.total_block_bytes(), 5L)
}

///|
test "parse_archive parses multiple records in file order" {
  let data = cat(
    cat(make_record(b"one"), make_record(b"two")),
    make_record(b"three"),
  )
  let a = parse_archive(data, Limits::default()).unwrap()
  assert_eq(a.record_count(), 3)
  assert_eq(eq_bytes(a.record(0).unwrap().block, 0, 3, "one"), true)
  assert_eq(eq_bytes(a.record(1).unwrap().block, 0, 3, "two"), true)
  assert_eq(eq_bytes(a.record(2).unwrap().block, 0, 5, "three"), true)
  assert_eq(a.total_block_bytes(), 11L)
}

///|
test "parse_archive keeps binary blocks intact across record boundaries" {
  // The first block contains framing-looking bytes; the second record
  // must still start exactly after the first record's CRLF CRLF.
  let bin = b"\x00\x01\xffWARC/1.1\r\n\r\nContent-Length: 999\r\n\r\n"
  let data = cat(make_record(bin), make_record(b"tail"))
  let a = parse_archive(data, Limits::default()).unwrap()
  assert_eq(a.record_count(), 2)
  assert_eq(a.record(0).unwrap().block.length(), bin.length())
  assert_eq(eq_bytes(a.record(1).unwrap().block, 0, 4, "tail"), true)
}

///|
test "parse_archive reports trailing garbage after a complete record" {
  let full = make_record(b"hello")
  let data = cat(full, b"junk")
  let r = parse_archive(data, Limits::default())
  match r {
    Ok(_) => fail("expected a trailing-garbage error")
    Err(e) => {
      assert_eq(e.kind.kind_name(), "trailing-garbage")
      assert_eq(e.stage, stage_of_code("archive").unwrap())
      assert_eq(e.byte_offset, full.length().to_int64())
      assert_eq(e.record_index, 1L)
    }
  }
}

///|
test "parse_archive reports a truncated trailing record as garbage" {
  // A version line and header, then a Content-Length promising 10
  // octets with only 3 present.
  let cut = @utf8.encode(
    "WARC/1.1\r\nWARC-Type: response\r\nContent-Length: 10\r\n\r\nabc",
  )
  let data = cat(make_record(b"hello"), cut)
  let r = parse_archive(data, Limits::default())
  match r {
    Ok(_) => fail("expected a trailing-garbage error")
    Err(e) => {
      assert_eq(e.kind.kind_name(), "trailing-garbage")
      assert_eq(e.record_index, 1L)
    }
  }
}

///|
test "parse_archive reports a trailing bad version line as garbage" {
  let data = cat(
    make_record(b"hello"),
    @utf8.encode(
      "WARC/1.0\r\nWARC-Type: response\r\nContent-Length: 0\r\n\r\n\r\n\r\n",
    ),
  )
  let r = parse_archive(data, Limits::default())
  match r {
    Ok(_) => fail("expected a trailing-garbage error")
    Err(e) => {
      assert_eq(e.kind.kind_name(), "trailing-garbage")
      assert_eq(e.stage, stage_of_code("archive").unwrap())
    }
  }
}

///|
test "parse_archive keeps the real error for a bad first record" {
  // The very first record has a bad version: the specific diagnosis
  // must survive, not be relabelled as trailing garbage.
  let data = @utf8.encode(
    "WARC/1.0\r\nWARC-Type: response\r\nContent-Length: 0\r\n\r\n\r\n\r\n",
  )
  let r = parse_archive(data, Limits::default())
  match r {
    Ok(_) => fail("expected an invalid-version error")
    Err(e) => {
      assert_eq(e.kind.kind_name(), "invalid-version")
      assert_eq(e.record_index, 0L)
    }
  }
}

///|
test "parse_archive keeps the real error for a malformed second record" {
  // A field line without a colon is a structural failure, not trailing
  // garbage, even after a complete record.
  let data = cat(
    make_record(b"hello"),
    @utf8.encode("WARC/1.1\r\nNoColonHere\r\nContent-Length: 0\r\n\r\n\r\n\r\n"),
  )
  let r = parse_archive(data, Limits::default())
  match r {
    Ok(_) => fail("expected a missing-colon error")
    Err(e) => {
      assert_eq(e.kind.kind_name(), "missing-colon")
      assert_eq(e.record_index, 1L)
    }
  }
}

///|
test "parse_archive enforces max_archive_bytes" {
  let l = Limits::default().with_max_archive_bytes(10L)
  let r = parse_archive(make_record(b"hello"), l)
  match r {
    Ok(_) => fail("expected a limit-exceeded error")
    Err(e) => {
      assert_eq(e.kind.kind_name(), "limit-exceeded")
      assert_eq(e.stage, stage_of_code("archive").unwrap())
    }
  }
}

///|
test "parse_archive enforces max_records" {
  let l = Limits::default().with_max_records(1)
  let data = cat(make_record(b"one"), make_record(b"two"))
  let r = parse_archive(data, l)
  match r {
    Ok(_) => fail("expected a limit-exceeded error")
    Err(e) => {
      assert_eq(e.kind.kind_name(), "limit-exceeded")
      assert_eq(e.stage, stage_of_code("archive").unwrap())
      assert_eq(e.record_index, 1L)
    }
  }
}

///|
test "parse_archive record access is bounds-checked" {
  let data = cat(make_record(b"a"), make_record(b"b"))
  let a = parse_archive(data, Limits::default()).unwrap()
  assert_eq(a.record(1) is Some(_), true)
  assert_eq(a.record(2) is None, true)
  assert_eq(a.record(-1) is None, true)
}

///|
test "parse_archive accepts records with empty blocks" {
  let data = cat(make_record(b""), make_record(b""))
  let a = parse_archive(data, Limits::default()).unwrap()
  assert_eq(a.record_count(), 2)
  assert_eq(a.total_block_bytes(), 0L)
}
