// Tests for the audit engine (audit.mbt).
// make_rec() comes from validator_test.mbt, cat() from
// framing_test.mbt.

///|
/// Run the audit and return the (severity, code) pairs in order.
fn finding_codes(a : WarcArchive) -> Array[(String, String)] {
  let fs = audit_archive(a)
  let out : Array[(String, String)] = []
  for i = 0; i < fs.length(); i = i + 1 {
    out.push((fs[i].severity().severity_name(), fs[i].code()))
  }
  out
}

///|
/// Assert that exactly the given (severity, code) pairs are reported,
/// in order.
fn assert_findings(
  a : WarcArchive,
  expected : Array[(String, String)],
) -> Unit raise Failure {
  let got = finding_codes(a)
  if got.length() != expected.length() {
    fail("expected \{expected.length()} findings, got \{got.length()}")
  }
  for i = 0; i < expected.length(); i = i + 1 {
    let (gs, gc) = got[i]
    let (es, ec) = expected[i]
    if gs != es || gc != ec {
      fail("finding \{i} was [\{gs}] \{gc}, expected [\{es}] \{ec}")
    }
  }
}

///|
/// An archive holding a single parsed record.
fn single_archive(rec : WarcRecord) -> WarcArchive {
  parse_archive(rec.to_bytes(), Limits::default()).unwrap()
}

///|
test "an empty-block response notes the empty block and missing digest" {
  let rec = make_rec("response", [("WARC-Target-URI", "<http://example.org/>")])
  assert_findings(single_archive(rec), [
    ("info", "empty-block"),
    ("info", "missing-block-digest"),
  ])
}

///|
test "unknown record types are warned about" {
  let rec = make_rec("future-thing", [])
  assert_findings(single_archive(rec), [
    ("warning", "unknown-record-type"),
    ("info", "missing-block-digest"),
  ])
}

///|
test "non-empty blocks without content type or digest are noted" {
  let b = WarcBuilder::new()
    .with_type("resource")
    .record_id("<urn:uuid:00000000-0000-0000-0000-000000000000>")
    .warc_date("2010-11-13T01:36:57Z")
    .field("WARC-Target-URI", "<http://example.org/>")
    .build(b"data")
    .unwrap()
  let a = single_archive(b)
  assert_findings(a, [
    ("info", "missing-block-digest"),
    ("info", "missing-content-type"),
  ])
}

///|
test "a satisfied refers-to is quiet, a dangling one is warned" {
  // Record 0 with id u1; record 1 refers back to u1.
  let r0 = make_rec("response", [("WARC-Target-URI", "<http://example.org/>")])
  let r1 = make_rec("revisit", [
    ("WARC-Target-URI", "<http://example.org/>"),
    (
      "WARC-Profile", "<http://netpreserve.org/warc/1.1/revisit/identical-payload-digest>",
    ),
    ("WARC-Refers-To", "<urn:uuid:00000000-0000-0000-0000-000000000000>"),
  ])
  let data = cat(r0.to_bytes(), r1.to_bytes())
  let a = parse_archive(data, Limits::default()).unwrap()
  assert_findings(a, [
    ("info", "empty-block"),
    ("info", "missing-block-digest"),
    ("info", "missing-block-digest"),
  ])
  // The same archive with a reference to a record id that does not
  // exist in it.
  let r2 = make_rec("revisit", [
    ("WARC-Target-URI", "<http://example.org/>"),
    (
      "WARC-Profile", "<http://netpreserve.org/warc/1.1/revisit/identical-payload-digest>",
    ),
    ("WARC-Refers-To", "<urn:uuid:deadbeef-0000-0000-0000-000000000000>"),
  ])
  let data2 = cat(r0.to_bytes(), r2.to_bytes())
  let a2 = parse_archive(data2, Limits::default()).unwrap()
  assert_findings(a2, [
    ("info", "empty-block"),
    ("info", "missing-block-digest"),
    ("info", "missing-block-digest"),
    ("warning", "dangling-refers-to"),
  ])
}

///|
test "severity codes resolve and round-trip" {
  let codes = all_severity_codes()
  assert_eq(codes.length(), 2)
  assert_eq(severity_of_code("info").unwrap().severity_name(), "info")
  assert_eq(severity_of_code("warning").unwrap().severity_name(), "warning")
  assert_eq(severity_of_code("nope"), None)
}

///|
test "findings carry their fields and render on one line" {
  let f = WarcFinding::new(
    severity_of_code("warning").unwrap(),
    "empty-block",
    3L,
    "record type response carries an empty content block",
  )
  assert_eq(f.severity().severity_name(), "warning")
  assert_eq(f.code(), "empty-block")
  assert_eq(f.record_index(), 3L)
  assert_eq(f.context(), "record type response carries an empty content block")
  let s = f.to_string()
  assert_true(s.contains("[warning]"))
  assert_true(s.contains("empty-block"))
  assert_true(s.contains("record 3"))
  assert_true(s.contains("empty content block"))
}
