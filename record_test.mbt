// Tests for record types and mandatory field helpers (record.mbt).

///|
test "all_record_type_codes lists the eight types in order" {
  assert_eq(all_record_type_codes().length(), 8)
  assert_eq(all_record_type_codes()[0], "warcinfo")
  assert_eq(all_record_type_codes()[7], "continuation")
}

///|
test "record_type_of_code resolves every code" {
  for i = 0; i < all_record_type_codes().length(); i = i + 1 {
    assert_eq(record_type_of_code(all_record_type_codes()[i]) != None, true)
  }
  assert_eq(record_type_of_code("bogus"), None)
}

///|
test "WarcRecordType::parse matches case-insensitively" {
  assert_eq(WarcRecordType::parse("response").unwrap().type_name(), "response")
  assert_eq(WarcRecordType::parse("RESPONSE").unwrap().type_name(), "response")
  assert_eq(WarcRecordType::parse("WarcInfo").unwrap().type_name(), "warcinfo")
  assert_eq(WarcRecordType::parse("revisit").unwrap().type_name(), "revisit")
  assert_eq(WarcRecordType::parse(""), None)
  assert_eq(WarcRecordType::parse("bogus"), None)
}

///|
test "type_name returns the canonical lowercase spelling" {
  assert_eq(record_type_of_code("warcinfo").unwrap().type_name(), "warcinfo")
  assert_eq(
    record_type_of_code("continuation").unwrap().type_name(),
    "continuation",
  )
}

///|
fn record_with_fields(fields : Array[WarcField]) -> WarcRecord {
  WarcRecord::new("WARC/1.1", fields, b"")
}

///|
fn minimal_fields() -> Array[WarcField] {
  [
    WarcField::new("WARC-Type", "response"),
    WarcField::new("WARC-Record-ID", "<urn:uuid:1234>"),
    WarcField::new("WARC-Date", "2010-11-13T01:36:57Z"),
    WarcField::new("Content-Length", "0"),
  ]
}

///|
test "record_type reads the WARC-Type field" {
  let rec = record_with_fields(minimal_fields())
  assert_eq(rec.record_type().unwrap().type_name(), "response")
  let rec2 = record_with_fields([WarcField::new("WARC-Type", "REVISIT")])
  assert_eq(rec2.record_type().unwrap().type_name(), "revisit")
}

///|
test "record_type is None for missing or unknown types" {
  let rec = record_with_fields([WarcField::new("WARC-Date", "2010")])
  assert_eq(rec.record_type(), None)
  let rec2 = record_with_fields([WarcField::new("WARC-Type", "weird")])
  assert_eq(rec2.record_type(), None)
}

///|
test "require_field returns present values case-insensitively" {
  let rec = record_with_fields(minimal_fields())
  assert_eq(rec.require_field("WARC-Record-ID", 0L).unwrap(), "<urn:uuid:1234>")
  assert_eq(rec.require_field("warc-record-id", 0L).unwrap(), "<urn:uuid:1234>")
}

///|
test "require_field fails with a structured error when missing" {
  let rec = record_with_fields(minimal_fields())
  let r = rec.require_field("WARC-Target-URI", 3L)
  match r {
    Ok(_) => fail("expected a missing-required-field error")
    Err(e) => {
      assert_eq(e.kind.kind_name(), "missing-required-field")
      assert_eq(e.stage, stage_of_code("record").unwrap())
      assert_eq(e.record_index, 3L)
    }
  }
}

///|
test "record_id parses the mandatory URI reference" {
  let rec = record_with_fields(minimal_fields())
  assert_eq(rec.record_id(0L).unwrap(), "urn:uuid:1234")
}

///|
test "record_id fails when the field is missing" {
  let rec = record_with_fields([WarcField::new("WARC-Type", "response")])
  let r = rec.record_id(0L)
  match r {
    Ok(_) => fail("expected a missing-required-field error")
    Err(e) => assert_eq(e.kind.kind_name(), "missing-required-field")
  }
}

///|
test "record_id fails when the value is not a URI reference" {
  let rec = record_with_fields([WarcField::new("WARC-Record-ID", "no-brackets")])
  let r = rec.record_id(0L)
  match r {
    Ok(_) => fail("expected an invalid-uri error")
    Err(e) => {
      assert_eq(e.kind.kind_name(), "invalid-uri")
      assert_eq(e.stage, stage_of_code("uri").unwrap())
    }
  }
}

///|
test "warc_date parses the mandatory timestamp" {
  let rec = record_with_fields(minimal_fields())
  let d = rec.warc_date(0L).unwrap()
  assert_eq(d.year, 2010)
  assert_eq(d.month, Some(11))
  assert_eq(d.day, Some(13))
  assert_eq(d.hour, Some(1))
}

///|
test "warc_date fails when the field is missing" {
  let rec = record_with_fields([WarcField::new("WARC-Type", "response")])
  let r = rec.warc_date(0L)
  match r {
    Ok(_) => fail("expected a missing-required-field error")
    Err(e) => assert_eq(e.kind.kind_name(), "missing-required-field")
  }
}

///|
test "warc_date fails on malformed timestamps" {
  let rec = record_with_fields([WarcField::new("WARC-Date", "not-a-date")])
  let r = rec.warc_date(0L)
  match r {
    Ok(_) => fail("expected an invalid-date error")
    Err(e) => assert_eq(e.kind.kind_name(), "invalid-date")
  }
}

///|
test "target_uri parses the URI reference when present" {
  let fields = [
    WarcField::new("WARC-Type", "response"),
    WarcField::new("WARC-Record-ID", "<urn:uuid:1234>"),
    WarcField::new("WARC-Date", "2010-11-13T01:36:57Z"),
    WarcField::new("Content-Length", "0"),
    WarcField::new("WARC-Target-URI", "<http://example.org/a>"),
  ]
  let rec = record_with_fields(fields)
  assert_eq(rec.target_uri(0L).unwrap(), "http://example.org/a")
}

///|
test "declared_content_length returns the raw field value" {
  let rec = record_with_fields(minimal_fields())
  assert_eq(rec.declared_content_length(), Some("0"))
  let rec2 = record_with_fields([])
  assert_eq(rec2.declared_content_length(), None)
}
