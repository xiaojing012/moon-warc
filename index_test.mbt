// Tests for archive indexing and querying (index.mbt) and aggregate
// statistics (stats.mbt). cat() comes from framing_test.mbt.

///|
/// Build one record with the given type, id, optional target URI and
/// date, serialized and parsed back.
fn make_indexed_record(
  t : String,
  id : String,
  target : String?,
  date : String,
) -> WarcRecord {
  let mut b = WarcBuilder::new()
    .with_type(t)
    .record_id("<urn:uuid:" + id + ">")
    .warc_date(date)
  match target {
    Some(u) => b = b.field("WARC-Target-URI", u)
    None => ()
  }
  let bytes = b.build(b"").unwrap().to_bytes()
  parse_record(bytes, 0, Limits::default(), 0L).unwrap().0
}

///|
/// A four-record archive: two responses sharing a target, one
/// resource, one metadata record without a target.
fn index_archive() -> WarcArchive {
  let recs = [
    make_indexed_record(
      "response",
      "u1",
      Some("<http://a/>"),
      "2020-01-01T00:00:00Z",
    ),
    make_indexed_record(
      "response",
      "u2",
      Some("<http://a/>"),
      "2021-06-15T12:00:00Z",
    ),
    make_indexed_record(
      "resource",
      "u3",
      Some("<http://b/>"),
      "2019-03-10T08:30:00Z",
    ),
    make_indexed_record("metadata", "u4", None, "2022-12-31T23:59:59Z"),
  ]
  let mut data = b""
  for i = 0; i < recs.length(); i = i + 1 {
    data = cat(data, recs[i].to_bytes())
  }
  parse_archive(data, Limits::default()).unwrap()
}

///|
/// Assert that two index arrays match element by element.
fn assert_ints(got : Array[Int], expected : Array[Int]) -> Unit raise Failure {
  if got.length() != expected.length() {
    fail("expected \{expected.length()} indices, got \{got.length()}")
  }
  for i = 0; i < expected.length(); i = i + 1 {
    if got[i] != expected[i] {
      fail("index \{i} was \{got[i]}, expected \{expected[i]}")
    }
  }
}

///|
test "index resolves record ids" {
  let idx = WarcIndex::build(index_archive())
  assert_eq(idx.by_record_id("urn:uuid:u1"), Some(0))
  assert_eq(idx.by_record_id("urn:uuid:u3"), Some(2))
  assert_eq(idx.by_record_id("urn:uuid:missing"), None)
}

///|
test "index resolves target uris in file order" {
  let idx = WarcIndex::build(index_archive())
  assert_ints(idx.by_target_uri("http://a/"), [0, 1])
  assert_ints(idx.by_target_uri("http://b/"), [2])
  assert_ints(idx.by_target_uri("http://x/"), [])
}

///|
test "index resolves record types" {
  let idx = WarcIndex::build(index_archive())
  assert_ints(idx.by_type(record_type_of_code("response").unwrap()), [0, 1])
  assert_ints(idx.by_type(record_type_of_code("resource").unwrap()), [2])
  assert_ints(idx.by_type(record_type_of_code("metadata").unwrap()), [3])
  assert_ints(idx.by_type(record_type_of_code("warcinfo").unwrap()), [])
}

///|
test "index counts all indexed keys" {
  let idx = WarcIndex::build(index_archive())
  // 4 ids + 3 targets + 4 types.
  assert_eq(idx.size(), 11)
}

///|
test "archive stats collect counts and byte totals" {
  let s = archive_stats(index_archive())
  assert_eq(s.record_count(), 4)
  assert_eq(s.type_count("response"), 2)
  assert_eq(s.type_count("resource"), 1)
  assert_eq(s.type_count("metadata"), 1)
  assert_eq(s.type_count("warcinfo"), 0)
  assert_eq(s.distinct_target_count(), 2)
  assert_eq(s.total_block_bytes(), 0L)
  assert_true(s.total_record_bytes() > 0L)
}

///|
test "archive stats find the earliest and latest dates" {
  let s = archive_stats(index_archive())
  let earliest = s.earliest_date().unwrap()
  assert_eq(earliest.year(), 2019)
  let latest = s.latest_date().unwrap()
  assert_eq(latest.year(), 2022)
  assert_eq(latest.month(), Some(12))
  assert_eq(latest.day(), Some(31))
}

///|
test "archive stats handle records without parseable dates" {
  // A record whose WARC-Date is missing: skipped, not fatal.
  let rec = WarcRecord::new(
    "WARC/1.1",
    [
      WarcField::new("WARC-Type", "response"),
      WarcField::new("WARC-Record-ID", "<urn:uuid:u9>"),
      WarcField::new("WARC-Target-URI", "<http://a/>"),
      WarcField::new("Content-Length", "0"),
    ],
    b"",
  )
  let a = parse_archive(rec.to_bytes(), Limits::default()).unwrap()
  let s = archive_stats(a)
  assert_eq(s.record_count(), 1)
  assert_eq(s.earliest_date(), None)
  assert_eq(s.latest_date(), None)
  assert_eq(s.distinct_target_count(), 1)
}
