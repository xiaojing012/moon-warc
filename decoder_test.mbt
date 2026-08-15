// Tests for the streaming decoder (decoder.mbt).
// Shared helpers cat() and make_record() come from framing_test.mbt.

///|
/// Assemble a record from raw field lines (colon included) plus an
/// automatic Content-Length field.
fn make_record_full(field_lines : Array[String], block : Bytes) -> Bytes {
  let buf = Buffer(size_hint=block.length() + 128)
  buf.write_utf8("WARC/1.1\r\n")
  for i = 0; i < field_lines.length(); i = i + 1 {
    buf.write_utf8(field_lines[i])
    buf.write_utf8("\r\n")
  }
  buf.write_utf8("Content-Length: \{block.length()}\r\n\r\n")
  buf.write_bytes(block)
  buf.write_utf8("\r\n\r\n")
  buf.to_bytes()
}

///|
/// Assemble a record from raw field lines with no automatic
/// Content-Length; the caller provides every line.
fn make_record_raw(field_lines : Array[String], block : Bytes) -> Bytes {
  let buf = Buffer(size_hint=block.length() + 128)
  buf.write_utf8("WARC/1.1\r\n")
  for i = 0; i < field_lines.length(); i = i + 1 {
    buf.write_utf8(field_lines[i])
    buf.write_utf8("\r\n")
  }
  buf.write_utf8("\r\n")
  buf.write_bytes(block)
  buf.write_utf8("\r\n\r\n")
  buf.to_bytes()
}

///|
/// Deep equality of two records.
fn rec_eq(a : WarcRecord, b : WarcRecord) -> Bool {
  if a.version != b.version {
    return false
  }
  if a.block_length() != b.block_length() {
    return false
  }
  for i = 0; i < a.block_length(); i = i + 1 {
    if a.block[i] != b.block[i] {
      return false
    }
  }
  if a.fields.length() != b.fields.length() {
    return false
  }
  for i = 0; i < a.fields.length(); i = i + 1 {
    if a.fields[i].name != b.fields[i].name ||
      a.fields[i].value != b.fields[i].value {
      return false
    }
  }
  true
}

///|
/// Equality of two errors on stage, kind, byte offset and record index.
fn err_eq(a : WarcError, b : WarcError) -> Bool {
  a.stage == b.stage &&
  a.kind == b.kind &&
  a.byte_offset == b.byte_offset &&
  a.record_index == b.record_index
}

///|
/// Deep equality of two record lists.
fn records_eq(a : Array[WarcRecord], b : Array[WarcRecord]) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for i = 0; i < a.length(); i = i + 1 {
    if !rec_eq(a[i], b[i]) {
      return false
    }
  }
  true
}

///|
/// Run a decoder over `data` split into the given chunk sizes.
fn run_decoder_limits(
  data : Bytes,
  sizes : Array[Int],
  limits : Limits,
) -> Result[Array[WarcRecord], WarcError] {
  let dec = WarcDecoder::new(limits)
  let recs : Array[WarcRecord] = []
  let mut off = 0
  for i = 0; i < sizes.length(); i = i + 1 {
    let n = if off + sizes[i] > data.length() {
      data.length() - off
    } else {
      sizes[i]
    }
    let r = dec.feed(data[off:off + n].to_owned())
    match r {
      Ok(new) =>
        for j = 0; j < new.length(); j = j + 1 {
          recs.push(new[j])
        }
      Err(e) => return Err(e)
    }
    off = off + n
    if off == data.length() {
      break
    }
  }
  match dec.finish() {
    Ok(_) => Ok(recs)
    Err(e) => Err(e)
  }
}

///|
/// Run a decoder over `data` split into the given chunk sizes with the
/// default limits.
fn run_decoder(
  data : Bytes,
  sizes : Array[Int],
) -> Result[Array[WarcRecord], WarcError] {
  run_decoder_limits(data, sizes, Limits::default())
}

///|
/// Chunk-size patterns for a stream of `len` bytes: one chunk,
/// byte-by-byte, every possible two-way split, and a cycling 1-2-3
/// pattern.
fn chunk_patterns(len : Int) -> Array[Array[Int]] {
  let pats : Array[Array[Int]] = []
  pats.push([len])
  let ones : Array[Int] = []
  for i = 0; i < len; i = i + 1 {
    ones.push(1)
  }
  pats.push(ones)
  for p = 0; p <= len; p = p + 1 {
    pats.push([p, len - p])
  }
  let cyc : Array[Int] = []
  let mut rest = len
  while rest > 0 {
    for s in [1, 2, 3] {
      if rest == 0 {
        break
      }
      let n = if s > rest { rest } else { s }
      cyc.push(n)
      rest = rest - n
    }
  }
  pats.push(cyc)
  pats
}

///|
/// Assert that feeding `data` through the decoder with the given chunk
/// sizes matches a whole-archive parse exactly.
fn check_chunking(data : Bytes, sizes : Array[Int]) -> Bool {
  let whole = parse_archive(data, Limits::default())
  let got = run_decoder(data, sizes)
  match (whole, got) {
    (Ok(a), Ok(b)) => records_eq(a.records, b)
    (Err(x), Err(y)) => err_eq(x, y)
    (_, _) => false
  }
}

///|
test "decoder matches parse_archive for valid archives under many chunkings" {
  let archives : Array[Bytes] = [
    make_record(b"hello"),
    cat(cat(make_record(b"one"), make_record(b"two")), make_record(b"three")),
    make_record(b""),
    cat(make_record(b""), make_record(b"")),
    cat(make_record(b"\x00\x01\xffWARC/1.1\r\n\r\n"), make_record(b"tail")),
    make_record_full(
      [
        "WARC-Type: response", "WARC-Date: 2010-11-13T01:36:57Z", "WARC-Record-ID: <urn:uuid:1234>",
        "WARC-Target-URI: <http://example.org/>",
      ],
      b"body",
    ),
    make_record_full(
      ["WARC-Type: metadata", "Multi: one", "  two", " \tthree"],
      b"",
    ),
  ]
  for i = 0; i < archives.length(); i = i + 1 {
    let data = archives[i]
    let pats = chunk_patterns(data.length())
    for p = 0; p < pats.length(); p = p + 1 {
      if !check_chunking(data, pats[p]) {
        fail("valid archive \{i} differs under chunk pattern \{p}")
      }
    }
  }
}

///|
test "decoder matches parse_archive for malformed archives under many chunkings" {
  let full = make_record(b"hello")
  let short_record = make_record(b"hi")
  let cut_block = short_record[0:short_record.length() - 4].to_owned()
  let bad_sep = cat(cut_block, b"XX\r\n")
  let truncated = full[0:full.length() - 1].to_owned()
  let archives : Array[Bytes] = [
    cat(full, b"junk"),
    cat(full, b"junk\r\n"),
    cat(
      full,
      @utf8.encode(
        "WARC/1.0\r\nWARC-Type: response\r\nContent-Length: 0\r\n\r\n\r\n\r\n",
      ),
    ),
    cat(
      full,
      @utf8.encode(
        "WARC/1.1\r\nNoColonHere\r\nContent-Length: 0\r\n\r\n\r\n\r\n",
      ),
    ),
    cat(
      full,
      @utf8.encode(
        "WARC/1.1\r\nWARC-Type: response\r\nContent-Length: 10\r\n\r\nabc",
      ),
    ),
    cat(
      full,
      @utf8.encode(
        "WARC/1.1\r\nBad Name: x\r\nContent-Length: 0\r\n\r\n\r\n\r\n",
      ),
    ),
    @utf8.encode(
      "WARC/1.0\r\nWARC-Type: response\r\nContent-Length: 0\r\n\r\n\r\n\r\n",
    ),
    cat(full, truncated),
    cat(full, bad_sep),
    cat(full, @utf8.encode("WARC/1.1\r\nA\rB: x\r\n\r\n\r\n\r\n")),
    truncated,
    cat(
      full,
      @utf8.encode(
        "WARC/1.1\r\nWARC-Type: response\r\nContent-Length: 0\r\n\r\n\r\n\r",
      ),
    ),
  ]
  for i = 0; i < archives.length(); i = i + 1 {
    let data = archives[i]
    let pats = chunk_patterns(data.length())
    for p = 0; p < pats.length(); p = p + 1 {
      if !check_chunking(data, pats[p]) {
        fail("malformed archive \{i} differs under chunk pattern \{p}")
      }
    }
  }
}

///|
test "decoder emits records as their chunks complete" {
  let first = make_record(b"one")
  let second = make_record(b"two")
  let dec = WarcDecoder::new(Limits::default())
  let r0 = dec.feed(first)
  match r0 {
    Ok(recs) => {
      assert_eq(recs.length(), 1)
      assert_eq(eq_bytes(recs[0].block, 0, 3, "one"), true)
    }
    Err(e) => fail("expected one record, got " + e.to_string())
  }
  let r1 = dec.feed(b"")
  match r1 {
    Ok(recs) => assert_eq(recs.length(), 0)
    Err(e) => fail("expected no records, got " + e.to_string())
  }
  let r2 = dec.feed(second)
  match r2 {
    Ok(recs) => {
      assert_eq(recs.length(), 1)
      assert_eq(eq_bytes(recs[0].block, 0, 3, "two"), true)
    }
    Err(e) => fail("expected one record, got " + e.to_string())
  }
  match dec.finish() {
    Ok(_) => ()
    Err(e) => fail("expected a clean finish, got " + e.to_string())
  }
}

///|
test "decoder accepts an empty stream" {
  let dec = WarcDecoder::new(Limits::default())
  match dec.finish() {
    Ok(_) => ()
    Err(e) => fail("expected a clean finish, got " + e.to_string())
  }
  let dec2 = WarcDecoder::new(Limits::default())
  let r = dec2.feed(b"")
  assert_eq(r is Ok(_), true)
  match dec2.finish() {
    Ok(_) => ()
    Err(e) => fail("expected a clean finish, got " + e.to_string())
  }
}

///|
test "decoder errors are sticky" {
  let data = @utf8.encode(
    "WARC/1.0\r\nWARC-Type: response\r\nContent-Length: 0\r\n\r\n\r\n\r\n",
  )
  let dec = WarcDecoder::new(Limits::default())
  let e1 = match dec.feed(data) {
    Ok(_) => fail("expected an invalid-version error")
    Err(e) => e
  }
  let e2 = match dec.feed(b"more") {
    Ok(_) => fail("expected the sticky error")
    Err(e) => e
  }
  assert_eq(err_eq(e1, e2), true)
  let e3 = match dec.finish() {
    Ok(_) => fail("expected the sticky error")
    Err(e) => e
  }
  assert_eq(err_eq(e1, e3), true)
}

///|
test "decoder enforces max_archive_bytes like parse_archive" {
  let l = Limits::default().with_max_archive_bytes(40L)
  let data = cat(make_record(b"one"), make_record(b"two"))
  let whole = parse_archive(data, l)
  let got = run_decoder_limits(data, [data.length()], l)
  match (whole, got) {
    (Err(x), Err(y)) => assert_eq(err_eq(x, y), true)
    (_, _) => fail("both paths must fail with the same error")
  }
  // A chunked feed crossing the limit reports the identical error.
  let got2 = run_decoder_limits(data, [30, 10, 100], l)
  match (whole, got2) {
    (Err(x), Err(y)) => assert_eq(err_eq(x, y), true)
    (_, _) => fail("both paths must fail with the same error")
  }
}

///|
test "decoder enforces max_records like parse_archive" {
  let l = Limits::default().with_max_records(1)
  let data = cat(make_record(b"one"), make_record(b"two"))
  let whole = parse_archive(data, l)
  let got = run_decoder_limits(data, [data.length()], l)
  match (whole, got) {
    (Err(x), Err(y)) => assert_eq(err_eq(x, y), true)
    (_, _) => fail("both paths must fail with the same error")
  }
}

///|
test "decoder enforces max_block_bytes like parse_archive" {
  let l = Limits::default().with_max_block_bytes(10L)
  let data = make_record_raw(
    ["WARC-Type: response", "Content-Length: 1000"],
    b"",
  )
  let whole = parse_archive(data, l)
  let got = run_decoder_limits(data, [7, 3, 1000], l)
  match (whole, got) {
    (Err(x), Err(y)) => assert_eq(err_eq(x, y), true)
    (_, _) => fail("both paths must fail with the same error")
  }
}

///|
test "decoder truncation errors match parse_archive exactly" {
  // A truncated first record keeps the raw unexpected-eof diagnosis.
  let full = make_record(b"hello")
  let cut = full[0:full.length() - 1].to_owned()
  let whole = parse_archive(cut, Limits::default())
  let got = run_decoder(cut, [3, 2, 100])
  match (whole, got) {
    (Err(x), Err(y)) => {
      assert_eq(err_eq(x, y), true)
      assert_eq(x.kind.kind_name(), "unexpected-eof")
      assert_eq(x.stage, stage_of_code("block").unwrap())
    }
    (_, _) => fail("both paths must fail with the same error")
  }
  // After a complete record the same truncation is trailing garbage.
  let data = cat(full, cut)
  let whole2 = parse_archive(data, Limits::default())
  let got2 = run_decoder(data, [full.length(), 1, 100])
  match (whole2, got2) {
    (Err(x), Err(y)) => {
      assert_eq(err_eq(x, y), true)
      assert_eq(x.kind.kind_name(), "trailing-garbage")
      assert_eq(x.byte_offset, full.length().to_int64())
    }
    (_, _) => fail("both paths must fail with the same error")
  }
}

///|
test "decoder trailing-garbage context matches parse_archive" {
  let full = make_record(b"hello")
  let data = cat(full, b"junk")
  let whole = parse_archive(data, Limits::default())
  let got = run_decoder(data, [2, 2, 100])
  match (whole, got) {
    (Err(x), Err(y)) => assert_eq(x.context, y.context)
    (_, _) => fail("both paths must fail with trailing garbage")
  }
}

///|
test "decoder rejects a bad separator at the right offset" {
  let record = make_record(b"hi")
  let cut = record[0:record.length() - 4].to_owned()
  let data = cat(cut, b"XX\r\n")
  let whole = parse_archive(data, Limits::default())
  let got = run_decoder(data, [1, 1, 1, 1, 1, 1, 100])
  match (whole, got) {
    (Err(x), Err(y)) => {
      assert_eq(err_eq(x, y), true)
      assert_eq(x.kind.kind_name(), "invalid-separator")
    }
    (_, _) => fail("both paths must fail with invalid-separator")
  }
}

///|
test "decoder byte-by-byte feed of a binary archive equals parse_archive" {
  let bin = b"\x00\x01\xffWARC/1.1\r\n\r\nContent-Length: 999\r\n\r\n"
  let data = cat(
    cat(make_record(bin), make_record(b"mid")),
    make_record(b"end"),
  )
  let ones : Array[Int] = []
  for i = 0; i < data.length(); i = i + 1 {
    ones.push(1)
  }
  assert_eq(check_chunking(data, ones), true)
}
