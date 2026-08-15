// Tests for the WARC core model (model.mbt).

///|
test "WarcField::new keeps name and value" {
  let f = WarcField::new("WARC-Type", "response")
  assert_eq(f.name, "WARC-Type")
  assert_eq(f.value, "response")
}

///|
test "WarcRecord::new keeps version fields and binary block" {
  let fields = [WarcField::new("WARC-Type", "resource")]
  let block = b"\x00\xff\x01"
  let r = WarcRecord::new("WARC/1.1", fields, block)
  assert_eq(r.version, "WARC/1.1")
  assert_eq(r.fields.length(), 1)
  assert_eq(r.fields[0].name, "WARC-Type")
  assert_eq(r.block.length(), 3)
  assert_eq(r.block[0], b'\x00')
  assert_eq(r.block[2], b'\x01')
}

///|
test "WARC_VERSION_LINE declares WARC 1.1" {
  assert_eq(WARC_VERSION_LINE, "WARC/1.1")
}

///|
test "block_length reports the raw octet count" {
  let r = WarcRecord::new("WARC/1.1", [], b"hello")
  assert_eq(r.block_length(), 5)
  let e = WarcRecord::new("WARC/1.1", [], b"")
  assert_eq(e.block_length(), 0)
}

///|
test "clause 8 MIME constants are declared" {
  assert_eq(WARC_MIME_TYPE, "application/warc")
  assert_eq(WARC_FIELDS_MIME_TYPE, "application/warc-fields")
}
