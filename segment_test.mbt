// Tests for record segmentation parsing (segment.mbt) and the
// archive-level checks of validate_archive (validator.mbt).
//
// make_rec() comes from validator_test.mbt, cat() from
// framing_test.mbt.

///|
/// Build a response record with segmentation fields, serialize it and
/// parse it back so structural checks are enforced.
fn seg_rec(
  number : String,
  origin : String,
  total : String?,
  id : String,
) -> WarcRecord {
  let mut b = WarcBuilder::new()
    .with_type("response")
    .record_id("<urn:uuid:" + id + ">")
    .warc_date("2010-11-13T01:36:57Z")
    .field("WARC-Target-URI", "<http://example.org/>")
    .field("WARC-Segment-Number", number)
    .field("WARC-Segment-Origin-ID", origin)
  match total {
    Some(t) => b = b.field("WARC-Segment-Total-Length", t)
    None => ()
  }
  let bytes = b.build(b"").unwrap().to_bytes()
  parse_record(bytes, 0, Limits::default(), 0L).unwrap().0
}

///|
/// Concatenate record serializations and parse them as one archive.
fn arch_of(recs : Array[WarcRecord]) -> WarcArchive {
  let mut data = b""
  for i = 0; i < recs.length(); i = i + 1 {
    data = cat(data, recs[i].to_bytes())
  }
  parse_archive(data, Limits::default()).unwrap()
}

///|
test "segment info parses valid segmentation fields" {
  let rec = seg_rec(
    "1",
    "<urn:uuid:origin>",
    Some("3000"),
    "11111111-0000-0000-0000-000000000001",
  )
  let info = rec.segment_info(0L).unwrap()
  assert_eq(info.number(), Some(1L))
  assert_eq(info.origin_id(), Some("urn:uuid:origin"))
  assert_eq(info.total_length(), Some(3000L))
}

///|
test "segment info is all None without segmentation fields" {
  let rec = make_rec("response", [("WARC-Target-URI", "<http://example.org/>")])
  let info = rec.segment_info(0L).unwrap()
  assert_eq(info.number(), None)
  assert_eq(info.origin_id(), None)
  assert_eq(info.total_length(), None)
}

///|
test "segment field syntax errors are reported" {
  // WARC-Segment-Number must be a positive decimal integer.
  for bad in ["abc", "0", "-1", "1.5", ""] {
    let rec = seg_rec(
      bad,
      "<urn:uuid:origin>",
      None,
      "11111111-0000-0000-0000-000000000001",
    )
    let errs = segment_errors(rec, 0L)
    assert_eq(errs.length(), 1)
    assert_eq(errs[0].kind.kind_name(), "invalid-field-value")
    assert_eq(errs[0].stage, stage_of_code("segment").unwrap())
  }
  // WARC-Segment-Origin-ID must be a <uri>.
  let bad_origin = seg_rec(
    "1",
    "not-a-uri",
    None,
    "11111111-0000-0000-0000-000000000001",
  )
  let errs = segment_errors(bad_origin, 0L)
  assert_eq(errs.length(), 1)
  assert_eq(errs[0].kind.kind_name(), "invalid-uri")
  // WARC-Segment-Total-Length must be a decimal integer.
  let bad_total = seg_rec(
    "1",
    "<urn:uuid:origin>",
    Some("12x"),
    "11111111-0000-0000-0000-000000000001",
  )
  let errs2 = segment_errors(bad_total, 0L)
  assert_eq(errs2.length(), 1)
  assert_eq(errs2[0].kind.kind_name(), "invalid-field-value")
}

///|
test "validate_record reports segment syntax errors" {
  let rec = seg_rec(
    "abc",
    "<urn:uuid:origin>",
    None,
    "11111111-0000-0000-0000-000000000001",
  )
  let errs = validate_record(rec, 0L)
  assert_eq(errs.length(), 1)
  assert_eq(errs[0].kind.kind_name(), "invalid-field-value")
  assert_eq(errs[0].stage, stage_of_code("segment").unwrap())
}

///|
test "validate_archive reports duplicate record IDs" {
  let a = arch_of([
    seg_rec("1", "<urn:uuid:o1>", None, "11111111-0000-0000-0000-000000000001"),
    seg_rec("2", "<urn:uuid:o1>", None, "11111111-0000-0000-0000-000000000001"),
  ])
  let errs = validate_archive(a)
  assert_eq(errs.length(), 1)
  assert_eq(errs[0].kind.kind_name(), "duplicate-field")
  assert_eq(errs[0].record_index, 1L)
  // Distinct IDs validate cleanly.
  let ok = arch_of([
    seg_rec("1", "<urn:uuid:o1>", None, "11111111-0000-0000-0000-000000000001"),
    seg_rec("2", "<urn:uuid:o1>", None, "22222222-0000-0000-0000-000000000002"),
  ])
  assert_eq(validate_archive(ok).length(), 0)
}

///|
test "validate_archive checks segment sequence consistency" {
  // A clean two-record sequence with the total length at the end.
  let ok = arch_of([
    seg_rec("1", "<urn:uuid:o1>", None, "11111111-0000-0000-0000-000000000001"),
    seg_rec(
      "2",
      "<urn:uuid:o1>",
      Some("500"),
      "22222222-0000-0000-0000-000000000002",
    ),
  ])
  assert_eq(validate_archive(ok).length(), 0)

  // Numbers must run 1, 2, 3, ...
  let jump = arch_of([
    seg_rec("1", "<urn:uuid:o1>", None, "11111111-0000-0000-0000-000000000001"),
    seg_rec("3", "<urn:uuid:o1>", None, "22222222-0000-0000-0000-000000000002"),
  ])
  let errs = validate_archive(jump)
  assert_eq(errs.length(), 1)
  assert_eq(errs[0].kind.kind_name(), "invalid-field-value")
  assert_eq(errs[0].stage, stage_of_code("segment").unwrap())
  assert_eq(errs[0].record_index, 1L)

  // The first record of a sequence must carry number 1.
  let not_one = arch_of([
    seg_rec("2", "<urn:uuid:o1>", None, "11111111-0000-0000-0000-000000000001"),
    seg_rec("3", "<urn:uuid:o1>", None, "22222222-0000-0000-0000-000000000002"),
  ])
  assert_eq(validate_archive(not_one).length(), 1)

  // Total length may only appear on the final record of a sequence.
  let early_total = arch_of([
    seg_rec(
      "1",
      "<urn:uuid:o1>",
      Some("500"),
      "11111111-0000-0000-0000-000000000001",
    ),
    seg_rec("2", "<urn:uuid:o1>", None, "22222222-0000-0000-0000-000000000002"),
  ])
  assert_eq(validate_archive(early_total).length(), 1)

  // Records of one sequence must be contiguous.
  let interleaved = arch_of([
    seg_rec("1", "<urn:uuid:o1>", None, "11111111-0000-0000-0000-000000000001"),
    seg_rec("1", "<urn:uuid:o2>", None, "33333333-0000-0000-0000-000000000003"),
    seg_rec("2", "<urn:uuid:o1>", None, "22222222-0000-0000-0000-000000000002"),
  ])
  assert_eq(validate_archive(interleaved).length(), 1)

  // Two independent sequences validate cleanly.
  let two_groups = arch_of([
    seg_rec("1", "<urn:uuid:o1>", None, "11111111-0000-0000-0000-000000000001"),
    seg_rec("2", "<urn:uuid:o1>", None, "22222222-0000-0000-0000-000000000002"),
    seg_rec("1", "<urn:uuid:o2>", None, "33333333-0000-0000-0000-000000000003"),
    seg_rec("2", "<urn:uuid:o2>", None, "44444444-0000-0000-0000-000000000004"),
  ])
  assert_eq(validate_archive(two_groups).length(), 0)
}
