// Tests for semantic record validation (validator.mbt).
//
// Records are built with WarcBuilder, serialized and parsed back so
// the validator runs over records that also satisfy the structural
// parser; placement and value-domain checks are exercised per type.

///|
/// Build a record of the given type with the standard mandatory
/// fields plus `extra` (name, value) pairs, then parse it back so
/// structural checks are enforced before validation.
fn make_rec(t : String, extra : Array[(String, String)]) -> WarcRecord {
  let mut b = WarcBuilder::new()
    .with_type(t)
    .record_id("<urn:uuid:00000000-0000-0000-0000-000000000000>")
    .warc_date("2010-11-13T01:36:57Z")
  for i = 0; i < extra.length(); i = i + 1 {
    let (name, value) = extra[i]
    b = b.field(name, value)
  }
  let bytes = b.build(b"").unwrap().to_bytes()
  parse_record(bytes, 0, Limits::default(), 0L).unwrap().0
}

///|
/// The kind names reported for a record, in discovery order.
fn kind_names(errs : Array[WarcError]) -> Array[String] {
  let out : Array[String] = []
  for i = 0; i < errs.length(); i = i + 1 {
    out.push(errs[i].kind.kind_name())
  }
  out
}

///|
/// Assert that exactly the given kind names are reported, in order.
fn assert_kinds(
  rec : WarcRecord,
  expected : Array[String],
) -> Unit raise Failure {
  let got = kind_names(validate_record(rec, 0L))
  if got.length() != expected.length() {
    fail("expected \{expected.length()} validation errors, got \{got.length()}")
  }
  for i = 0; i < expected.length(); i = i + 1 {
    if got[i] != expected[i] {
      fail("validation error \{i} was \{got[i]}, expected \{expected[i]}")
    }
  }
}

///|
test "a well-formed response record validates cleanly" {
  let rec = make_rec("response", [
    ("WARC-Target-URI", "<http://example.org/>"),
    ("WARC-IP-Address", "192.168.1.1"),
    ("WARC-Block-Digest", "sha1:B2QYELGDQWXWAWJ4OA2GSCBXDAOB7UHR"),
  ])
  assert_kinds(rec, [])
}

///|
test "repeated fields are reported except WARC-Concurrent-To" {
  let dup = make_rec("response", [
    ("WARC-Target-URI", "<http://example.org/>"),
    ("X-Note", "1"),
    ("X-Note", "2"),
  ])
  assert_kinds(dup, ["duplicate-field"])
  let concurrent = make_rec("response", [
    ("WARC-Target-URI", "<http://example.org/>"),
    ("WARC-Concurrent-To", "<urn:uuid:aaaaaaaa-0000-0000-0000-000000000000>"),
    ("WARC-Concurrent-To", "<urn:uuid:bbbbbbbb-0000-0000-0000-000000000000>"),
  ])
  assert_kinds(concurrent, [])
}

///|
test "warcinfo rejects target URI concurrent-to IP and warcinfo ID" {
  let rec = make_rec("warcinfo", [
    ("WARC-Target-URI", "<http://example.org/>"),
    ("WARC-IP-Address", "192.168.1.1"),
    ("WARC-Concurrent-To", "<urn:uuid:aaaaaaaa-0000-0000-0000-000000000000>"),
    ("WARC-Warcinfo-ID", "<urn:uuid:bbbbbbbb-0000-0000-0000-000000000000>"),
    ("WARC-Filename", "example.warc.gz"),
  ])
  assert_kinds(rec, [
    "misplaced-field", "misplaced-field", "misplaced-field", "misplaced-field",
  ])
  // WARC-Filename itself belongs on warcinfo.
  let clean = make_rec("warcinfo", [("WARC-Filename", "example.warc.gz")])
  assert_kinds(clean, [])
}

///|
test "target URI requirements by record type" {
  // response/resource/request/conversion/continuation require it.
  for t in ["response", "resource", "request", "conversion", "continuation"] {
    assert_kinds(make_rec(t, []), ["missing-required-field"])
  }
  // revisit requires both the target and a profile.
  assert_kinds(make_rec("revisit", []), [
    "missing-required-field", "missing-required-field",
  ])
  // metadata carries no target; warcinfo must not carry one.
  assert_kinds(make_rec("metadata", []), [])
  assert_kinds(make_rec("warcinfo", []), [])
}

///|
test "revisit records require a profile and own the refers-to family" {
  let missing = make_rec("revisit", [
    ("WARC-Target-URI", "<http://example.org/>"),
    ("WARC-Refers-To", "<http://example.org/old>"),
  ])
  assert_kinds(missing, ["missing-required-field"])
  let ok = make_rec("revisit", [
    ("WARC-Target-URI", "<http://example.org/>"),
    (
      "WARC-Profile", "<http://netpreserve.org/warc/1.1/revisit/identical-payload-digest>",
    ),
    ("WARC-Refers-To", "<http://example.org/old>"),
    ("WARC-Refers-To-Target-URI", "<http://example.org/old>"),
    ("WARC-Refers-To-Date", "2010-11-12T01:36:57Z"),
  ])
  assert_kinds(ok, [])
  let stray = make_rec("metadata", [
    (
      "WARC-Profile", "<http://netpreserve.org/warc/1.1/revisit/identical-payload-digest>",
    ),
    ("WARC-Refers-To", "<http://example.org/old>"),
    ("WARC-Refers-To-Target-URI", "<http://example.org/old>"),
    ("WARC-Refers-To-Date", "2010-11-12T01:36:57Z"),
  ])
  assert_kinds(stray, [
    "misplaced-field", "misplaced-field", "misplaced-field", "misplaced-field",
  ])
}

///|
test "truncated reason tokens are checked" {
  for good in ["length", "time", "disconnect", "unspecified"] {
    assert_kinds(
      make_rec("response", [
        ("WARC-Target-URI", "<http://example.org/>"),
        ("WARC-Truncated", good),
      ]),
      [],
    )
  }
  assert_kinds(
    make_rec("response", [
      ("WARC-Target-URI", "<http://example.org/>"),
      ("WARC-Truncated", "partial"),
    ]),
    ["invalid-field-value"],
  )
}

///|
test "ip address syntax" {
  for
    good in [
      "192.168.1.1", "0.0.0.0", "255.255.255.255", "::1", "2001:db8::1", "fe80::1",
    ] {
    assert_kinds(
      make_rec("response", [
        ("WARC-Target-URI", "<http://example.org/>"),
        ("WARC-IP-Address", good),
      ]),
      [],
    )
  }
  for
    bad in [
      "256.1.1.1", "1.2.3", "1.2.3.4.5", "01.2.3.4", "1.2.3.a", "abc", "", "1.2.3.4:5",
      "1234.5.6.7",
    ] {
    assert_kinds(
      make_rec("response", [
        ("WARC-Target-URI", "<http://example.org/>"),
        ("WARC-IP-Address", bad),
      ]),
      ["invalid-ip-address"],
    )
  }
}

///|
test "digest fields are checked on every record type" {
  for
    good in [
      "sha1:B2QYELGDQWXWAWJ4OA2GSCBXDAOB7UHR", "md5:d41d8cd98f00b204e9800998ecf8427e",
    ] {
    assert_kinds(
      make_rec("response", [
        ("WARC-Target-URI", "<http://example.org/>"),
        ("WARC-Payload-Digest", good),
        ("WARC-Block-Digest", good),
      ]),
      [],
    )
  }
  for bad in ["sha1:", "sha1:B2QY G", "no-colon"] {
    assert_kinds(
      make_rec("response", [
        ("WARC-Target-URI", "<http://example.org/>"),
        ("WARC-Block-Digest", bad),
      ]),
      ["invalid-digest"],
    )
  }
}

///|
test "unknown record types skip placement but not value checks" {
  let ok = make_rec("future-thing", [
    ("WARC-Target-URI", "<http://example.org/>"),
    ("WARC-IP-Address", "192.168.1.1"),
    ("WARC-Concurrent-To", "<urn:uuid:aaaaaaaa-0000-0000-0000-000000000000>"),
  ])
  assert_kinds(ok, [])
  let bad_ip = make_rec("future-thing", [("WARC-IP-Address", "not-an-ip")])
  assert_kinds(bad_ip, ["invalid-ip-address"])
}

///|
test "a missing WARC-Type is reported" {
  let rec = WarcRecord::new(
    "WARC/1.1",
    [
      WarcField::new(
        "WARC-Record-ID", "<urn:uuid:00000000-0000-0000-0000-000000000000>",
      ),
      WarcField::new("WARC-Date", "2010-11-13T01:36:57Z"),
    ],
    b"",
  )
  assert_kinds(rec, ["missing-required-field"])
}

///|
test "refers-to family values are syntax-checked" {
  let bad_uri = make_rec("revisit", [
    ("WARC-Target-URI", "<http://example.org/>"),
    (
      "WARC-Profile", "<http://netpreserve.org/warc/1.1/revisit/identical-payload-digest>",
    ),
    ("WARC-Refers-To", "<"),
  ])
  assert_kinds(bad_uri, ["invalid-uri"])
  let bad_date = make_rec("revisit", [
    ("WARC-Target-URI", "<http://example.org/>"),
    (
      "WARC-Profile", "<http://netpreserve.org/warc/1.1/revisit/identical-payload-digest>",
    ),
    ("WARC-Refers-To-Date", "not-a-date"),
  ])
  assert_kinds(bad_date, ["invalid-date"])
}

///|
test "identified payload type placement" {
  // Target-less types: warcinfo forbids a target, metadata carries none.
  for t in ["warcinfo", "metadata"] {
    assert_kinds(make_rec(t, [("WARC-Identified-Payload-Type", "text/html")]), [
      "misplaced-field",
    ])
  }
  // Target-bearing types: give them a target (and revisit a profile)
  // so only the payload-type violation remains.
  for t in ["request", "continuation"] {
    assert_kinds(
      make_rec(t, [
        ("WARC-Target-URI", "<http://example.org/>"),
        ("WARC-Identified-Payload-Type", "text/html"),
      ]),
      ["misplaced-field"],
    )
  }
  assert_kinds(
    make_rec("revisit", [
      ("WARC-Target-URI", "<http://example.org/>"),
      (
        "WARC-Profile", "<http://netpreserve.org/warc/1.1/revisit/identical-payload-digest>",
      ),
      ("WARC-Identified-Payload-Type", "text/html"),
    ]),
    ["misplaced-field"],
  )
  for t in ["response", "resource", "conversion"] {
    assert_kinds(
      make_rec(t, [
        ("WARC-Target-URI", "<http://example.org/>"),
        ("WARC-Identified-Payload-Type", "text/html"),
      ]),
      [],
    )
  }
}

///|
test "filename placement" {
  assert_kinds(
    make_rec("response", [
      ("WARC-Target-URI", "<http://example.org/>"),
      ("WARC-Filename", "x.warc"),
    ]),
    ["misplaced-field"],
  )
  assert_kinds(make_rec("warcinfo", [("WARC-Filename", "x.warc")]), [])
}

///|
test "validation errors carry the record index" {
  let rec = make_rec("response", [
    ("WARC-Target-URI", "<http://example.org/>"),
    ("X-Note", "1"),
    ("X-Note", "2"),
  ])
  let errs = validate_record(rec, 5L)
  assert_eq(errs.length(), 1)
  assert_eq(errs[0].record_index, 5L)
  assert_eq(errs[0].stage, stage_of_code("record").unwrap())
}
