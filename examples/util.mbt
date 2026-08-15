// Shared helpers for the examples.
//
// Each example demonstrates one slice of the library. The helpers
// here keep the demo files themselves small and readable.

///|
/// Concatenate two byte buffers.
pub fn ex_cat(a : Bytes, b : Bytes) -> Bytes {
  let buf = Buffer(size_hint=a.length() + b.length())
  buf.write_bytes(a)
  buf.write_bytes(b)
  buf.to_bytes()
}

///|
/// Parse a list of records as one archive.
pub fn ex_archive_of(recs : Array[@warc.WarcRecord]) -> @warc.WarcArchive {
  let mut data = b""
  for i = 0; i < recs.length(); i = i + 1 {
    data = ex_cat(data, recs[i].to_bytes())
  }
  @warc.parse_archive(data, @warc.Limits::default()).unwrap()
}

///|
/// A small response record with the given target URI.
pub fn ex_response(
  id : String,
  target : String,
  block : Bytes,
) -> @warc.WarcRecord {
  @warc.WarcBuilder::new()
  .with_type("response")
  .record_id("<urn:uuid:\{id}>")
  .warc_date("2021-03-14T08:00:00Z")
  .field("WARC-Target-URI", "<\{target}>")
  .build(block)
  .unwrap()
}

///|
/// Render a UTF-8 byte buffer as text (demo blocks are ASCII).
pub fn ex_text(bytes : Bytes) -> String {
  @utf8.decode(bytes.view(start=0, end=bytes.length())) catch {
    _ => "(non-UTF-8 bytes omitted)"
  }
}
