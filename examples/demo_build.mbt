// Example: building records.
//
// @warc.WarcBuilder assembles records field by field and rejects invalid
// header values before any bytes are written.

///|
/// Build one record and print its serialized form.
pub fn demo_build() -> Unit {
  let rec = @warc.WarcBuilder::new()
    .with_type("response")
    .record_id("<urn:uuid:00000000-0000-0000-0000-00000000000a>")
    .warc_date("2021-03-14T08:00:00Z")
    .field("WARC-Target-URI", "<http://example.org/built>")
    .field("Content-Type", "text/plain")
    .build(b"hello, WARC")
    .unwrap()
  println(ex_text(rec.to_bytes()))
  // Field names must be legal tokens; the offending field index is
  // reported in the error.
  match
    @warc.WarcBuilder::new()
    .with_type("response")
    .record_id("<urn:uuid:00000000-0000-0000-0000-00000000000b>")
    .warc_date("2021-03-14T08:00:00Z")
    .field("Bad Name", "x")
    .build(b"x") {
    Ok(_) => println("unexpectedly accepted")
    Err(e) => println("rejected: " + e.to_string())
  }
}
