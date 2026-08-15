// Tests for binary-safe record framing (framing.mbt).

///|
/// Concatenate two byte strings.
fn cat(a : Bytes, b : Bytes) -> Bytes {
  let buf = Buffer(size_hint=a.length() + b.length())
  buf.write_bytes(a)
  buf.write_bytes(b)
  buf.to_bytes()
}

///|
/// Assemble a complete record: version line, one Content-Length field,
/// blank line, block, trailing CRLF CRLF.
fn make_record(block : Bytes) -> Bytes {
  let buf = Buffer(size_hint=block.length() + 64)
  buf.write_utf8(
    "WARC/1.1\r\nWARC-Type: response\r\nContent-Length: \{block.length()}\r\n\r\n",
  )
  buf.write_bytes(block)
  buf.write_utf8("\r\n\r\n")
  buf.to_bytes()
}

///|
test "parse_record frames an empty block" {
  let data = make_record(b"")
  let r = parse_record(data, 0, Limits::default(), 0L)
  match r {
    Ok((rec, next)) => {
      assert_eq(rec.version, "WARC/1.1")
      assert_eq(rec.fields.length(), 2)
      assert_eq(rec.block.length(), 0)
      assert_eq(next, data.length())
    }
    Err(e) => fail("expected a parsed record, got " + e.to_string())
  }
}

///|
test "parse_record frames a text block" {
  let data = make_record(b"hello world")
  let r = parse_record(data, 0, Limits::default(), 0L)
  match r {
    Ok((rec, next)) => {
      assert_eq(rec.block.length(), 11)
      assert_eq(eq_bytes(rec.block, 0, 11, "hello world"), true)
      assert_eq(next, data.length())
    }
    Err(e) => fail("expected a parsed record, got " + e.to_string())
  }
}

///|
test "parse_record is binary-safe: framing bytes inside the block are data" {
  // The block contains NUL, high bytes, CRLF pairs and even the text
  // "WARC/1.1" — none of it may affect framing, which follows
  // Content-Length exclusively.
  let block = b"\x00\x01\xffWARC/1.1\r\nbinary\x80\r\n\r\nend"
  let data = make_record(block)
  let r = parse_record(data, 0, Limits::default(), 0L)
  match r {
    Ok((rec, next)) => {
      assert_eq(rec.block.length(), block.length())
      assert_eq(rec.block[0], b'\x00')
      assert_eq(rec.block[1], b'\x01')
      assert_eq(rec.block[2], b'\xff')
      assert_eq(eq_bytes(rec.block, 3, 11, "WARC/1.1"), true)
      assert_eq(rec.block[rec.block.length() - 1], b'd')
      assert_eq(next, data.length())
    }
    Err(e) => fail("expected a parsed record, got " + e.to_string())
  }
}

///|
test "parse_record keeps the block as a byte-exact slice" {
  let data = make_record(b"abc\r\ndef")
  let r = parse_record(data, 0, Limits::default(), 0L)
  match r {
    Ok((rec, _)) => assert_eq(eq_bytes(rec.block, 0, 8, "abc\r\ndef"), true)
    Err(e) => fail("expected a parsed record, got " + e.to_string())
  }
}

///|
test "parse_record parses the second record at the returned offset" {
  let first = make_record(b"one")
  let second = make_record(b"two")
  let data = cat(first, second)
  let r1 = parse_record(data, 0, Limits::default(), 0L)
  let (rec1, next) = match r1 {
    Ok(x) => x
    Err(e) => fail("expected the first record, got " + e.to_string())
  }
  assert_eq(eq_bytes(rec1.block, 0, 3, "one"), true)
  let r2 = parse_record(data, next, Limits::default(), 1L)
  match r2 {
    Ok((rec2, end)) => {
      assert_eq(eq_bytes(rec2.block, 0, 3, "two"), true)
      assert_eq(end, data.length())
    }
    Err(e) => fail("expected the second record, got " + e.to_string())
  }
}

///|
test "parse_record rejects a truncated record" {
  let data = make_record(b"hello")
  // Drop the final LF so only 3 of the 4 separator bytes remain.
  let cut = data[0:data.length() - 1].to_owned()
  let r = parse_record(cut, 0, Limits::default(), 0L)
  match r {
    Ok(_) => fail("expected an unexpected-eof error")
    Err(e) => {
      assert_eq(e.kind.kind_name(), "unexpected-eof")
      assert_eq(e.stage, stage_of_code("block").unwrap())
    }
  }
}

///|
test "parse_record rejects a bad trailing separator" {
  let data = make_record(b"hello")
  // Replace the trailing CRLF CRLF with XX CRLF.
  let bad = cat(data[0:data.length() - 4].to_owned(), b"XX\r\n")
  let r = parse_record(bad, 0, Limits::default(), 0L)
  match r {
    Ok(_) => fail("expected an invalid-separator error")
    Err(e) => {
      assert_eq(e.kind.kind_name(), "invalid-separator")
      assert_eq(e.stage, stage_of_code("separator").unwrap())
    }
  }
}

///|
test "parse_record rejects a bad version line" {
  let data = @utf8.encode(
    "WARC/1.0\r\nWARC-Type: response\r\nContent-Length: 0\r\n\r\n\r\n\r\n",
  )
  let r = parse_record(data, 0, Limits::default(), 0L)
  match r {
    Ok(_) => fail("expected an invalid-version error")
    Err(e) => assert_eq(e.kind.kind_name(), "invalid-version")
  }
}

///|
test "parse_record rejects a missing Content-Length" {
  let data = @utf8.encode("WARC/1.1\r\nWARC-Type: response\r\n\r\n\r\n\r\n")
  let r = parse_record(data, 0, Limits::default(), 0L)
  match r {
    Ok(_) => fail("expected a missing-required-field error")
    Err(e) => assert_eq(e.kind.kind_name(), "missing-required-field")
  }
}

///|
test "parse_record rejects a repeated Content-Length" {
  let data = @utf8.encode(
    "WARC/1.1\r\nContent-Length: 0\r\ncontent-length: 1\r\n\r\n\r\n\r\n",
  )
  let r = parse_record(data, 0, Limits::default(), 0L)
  match r {
    Ok(_) => fail("expected a duplicate-field error")
    Err(e) => assert_eq(e.kind.kind_name(), "duplicate-field")
  }
}

///|
test "parse_record enforces max_record_bytes" {
  let l = Limits::default().with_max_record_bytes(40L)
  let data = make_record(b"hello")
  let r = parse_record(data, 0, l, 0L)
  match r {
    Ok(_) => fail("expected a limit-exceeded error")
    Err(e) => {
      assert_eq(e.kind.kind_name(), "limit-exceeded")
      assert_eq(e.stage, stage_of_code("record").unwrap())
    }
  }
}

///|
test "parse_record carries the record index into errors" {
  let full = make_record(b"hello")
  let cut = full[0:full.length() - 1].to_owned()
  let r = parse_record(cut, 0, Limits::default(), 8L)
  match r {
    Ok(_) => fail("expected an unexpected-eof error")
    Err(e) => assert_eq(e.record_index, 8L)
  }
}
