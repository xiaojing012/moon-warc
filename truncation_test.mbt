// Exhaustive truncation and size-stress tests.
//
// Every prefix of a multi-record archive must be handled by the
// streaming decoder exactly as the buffered parser handles it: both
// succeed, or both fail — never a silent partial success. The
// decoder is also exercised against archives large enough to span
// many feed boundaries, without ever scanning for a record
// terminator inside the block.

///|
test "every truncation point agrees with the buffered parser" {
  let r1 = WarcBuilder::new()
    .with_type("response")
    .record_id("<urn:uuid:00000000-0000-0000-0000-000000000001>")
    .warc_date("2010-11-13T01:36:57Z")
    .field("WARC-Target-URI", "<http://example.org/a>")
    .build(b"hello world")
    .unwrap()
  let r2 = WarcBuilder::new()
    .with_type("resource")
    .record_id("<urn:uuid:00000000-0000-0000-0000-000000000002>")
    .warc_date("2010-11-13T01:36:58Z")
    .field("WARC-Target-URI", "<http://example.org/b>")
    .build(b"")
    .unwrap()
  let r3 = WarcBuilder::new()
    .with_type("response")
    .record_id("<urn:uuid:00000000-0000-0000-0000-000000000003>")
    .warc_date("2010-11-13T01:36:59Z")
    .field("WARC-Target-URI", "<http://example.org/c>")
    // Binary block that contains a fake "WARC/1.1" line: the decoder
    // must not treat it as a record boundary (Content-Length only).
    .build(b"\x00\x01\xffWARC/1.1\r\n\r\n not a header")
    .unwrap()
  let data = cat(cat(r1.to_bytes(), r2.to_bytes()), r3.to_bytes())
  for cut = 0; cut <= data.length(); cut = cut + 1 {
    let prefix = data.view(start=0, end=cut).to_owned()
    let parsed_ok = parse_archive(prefix, Limits::default()) is Ok(_)
    let decoded = run_decoder(prefix, [prefix.length()])
    let decoded_ok = decoded is Ok(_)
    if parsed_ok != decoded_ok {
      fail(
        "truncation at byte \{cut}: buffered parser \{parsed_ok}, streaming decoder \{decoded_ok}",
      )
    }
    match decoded {
      Ok(recs) => {
        let parsed = parse_archive(prefix, Limits::default()).unwrap()
        assert_eq(recs.length(), parsed.record_count())
      }
      Err(_) => ()
    }
  }
}

///|
test "default limits pass a moderately large multi-record archive" {
  let mut data = b""
  for i = 0; i < 32; i = i + 1 {
    // A deterministic 256-octet block per record.
    let mut block = b""
    for j = 0; j < 16; j = j + 1 {
      block = cat(block, b"0123456789abcdef")
    }
    let rec = WarcBuilder::new()
      .with_type("response")
      .record_id("<urn:uuid:00000000-0000-0000-0000-0000000000\{i}>")
      .warc_date("2020-01-01T00:00:00Z")
      .field("WARC-Target-URI", "<http://example.org/\{i}>")
      .build(block)
      .unwrap()
    data = cat(data, rec.to_bytes())
  }
  let a = parse_archive(data, Limits::default()).unwrap()
  assert_eq(a.record_count(), 32)
  assert_eq(a.total_block_bytes(), 32L * 256L)
  // The streaming decoder must emit exactly the same records from a
  // single feed and from byte-by-byte feeding.
  let whole = run_decoder(data, [data.length()]).unwrap()
  assert_eq(whole.length(), 32)
  let dec = WarcDecoder::new(Limits::default())
  let recs : Array[WarcRecord] = []
  for i = 0; i < data.length(); i = i + 1 {
    let got = dec.feed(data.view(start=i, end=i + 1).to_owned())
    match got {
      Ok(batch) =>
        for k = 0; k < batch.length(); k = k + 1 {
          recs.push(batch[k])
        }
      Err(e) => fail("byte-by-byte feed failed at byte \{i}: " + e.to_string())
    }
  }
  match dec.finish() {
    Ok(_) => ()
    Err(e) => fail("byte-by-byte feed failed at finish: " + e.to_string())
  }
  assert_eq(recs.length(), 32)
}

///|
test "tight limits are enforced on larger archives" {
  // 8 records of 64 octets each: max_records 4 must trip, and a
  // max_block_bytes of 32 must trip on the blocks.
  let mut data = b""
  for i = 0; i < 8; i = i + 1 {
    let mut block = b""
    for j = 0; j < 4; j = j + 1 {
      block = cat(block, b"0123456789abcdef")
    }
    let rec = WarcBuilder::new()
      .with_type("response")
      .record_id("<urn:uuid:00000000-0000-0000-0000-0000000000\{i}>")
      .warc_date("2020-01-01T00:00:00Z")
      .field("WARC-Target-URI", "<http://example.org/\{i}>")
      .build(block)
      .unwrap()
    data = cat(data, rec.to_bytes())
  }
  // Record count limit: buffered parser and streaming decoder agree.
  let strict = Limits::default().with_max_records(4)
  match parse_archive(data, strict) {
    Ok(_) => fail("expected a record-count limit error")
    Err(e) => {
      assert_eq(e.kind.kind_name(), "limit-exceeded")
      assert_eq(e.stage, stage_of_code("archive").unwrap())
    }
  }
  match run_decoder_limits(data, [data.length()], strict) {
    Ok(_) => fail("expected a record-count limit error from the decoder")
    Err(e) => assert_eq(e.kind.kind_name(), "limit-exceeded")
  }
  // Block size limit: trip on the first record's block. (The check
  // fires while reading Content-Length, before any block bytes are
  // consumed.)
  let small_block = Limits::default().with_max_block_bytes(32L)
  match parse_archive(data, small_block) {
    Ok(_) => fail("expected a block-size limit error")
    Err(e) => assert_eq(e.kind.kind_name(), "limit-exceeded")
  }
  match run_decoder_limits(data, [data.length()], small_block) {
    Ok(_) => fail("expected a block-size limit error from the decoder")
    Err(e) => assert_eq(e.kind.kind_name(), "limit-exceeded")
  }
}
