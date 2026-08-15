// Tests for labelled digest parsing (digest.mbt).

///|
test "parse_digest accepts labelled base-encoded digests" {
  let cases : Array[(String, String, String)] = [
    (
      "sha1:B2QYELGDQWXWAWJ4OA2GSCBXDAOB7UHR", "sha1", "B2QYELGDQWXWAWJ4OA2GSCBXDAOB7UHR",
    ),
    (
      "md5:d41d8cd98f00b204e9800998ecf8427e", "md5", "d41d8cd98f00b204e9800998ecf8427e",
    ),
    (
      "sha256:9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08",
      "sha256", "9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08",
    ),
    // Algorithm labels are case-insensitive tokens.
    (
      "SHA-1:B2QYELGDQWXWAWJ4OA2GSCBXDAOB7UHR", "SHA-1", "B2QYELGDQWXWAWJ4OA2GSCBXDAOB7UHR",
    ),
  ]
  for i = 0; i < cases.length(); i = i + 1 {
    let (text, algorithm, value) = cases[i]
    let d = parse_digest(text, 0L).unwrap()
    assert_eq(d.algorithm(), algorithm)
    assert_eq(d.value(), value)
    assert_eq(d.to_string(), text)
  }
}

///|
test "parse_digest rejects malformed digest values" {
  for
    bad in [
      "", // empty
       "B2QYELGDQWXWAWJ4OA2GSCBXDAOB7UHR", // no colon
       ":B2QYELGDQWXWAWJ4OA2GSCBXDAOB7UHR", // empty algorithm
       "sha1:", // empty value
       "sha 1:B2QY", // space in algorithm
       "sha1:B2QY G", // space in value
       "sha1:B2QY:G", // extra colon in value
       "sha1:\tB2QY", // tab in value
       "sha1:", // duplicate guard: value missing
    ] {
    let r = parse_digest(bad, 3L)
    match r {
      Ok(_) => fail("expected an invalid-digest error for: " + bad)
      Err(e) => {
        assert_eq(e.stage, stage_of_code("digest").unwrap())
        assert_eq(e.kind, kind_of_code("invalid-digest").unwrap())
        assert_eq(e.record_index, 3L)
      }
    }
  }
}

///|
test "parse_digest preserves the algorithm spelling" {
  let d = parse_digest("sha1:ABC", 0L).unwrap()
  let rebuilt = WarcDigest::new(d.algorithm(), d.value())
  assert_eq(rebuilt.to_string(), "sha1:ABC")
}
