// The built-in demo archive used by every warc-tool command.
//
// This build has no file-system I/O (see the library's limitations),
// so the CLI demonstrates parsing, validation, indexing, statistics,
// auditing and building on a fixed in-memory archive.

///|
/// Concatenate two byte buffers.
fn cat_bytes(a : Bytes, b : Bytes) -> Bytes {
  let buf = Buffer(size_hint=a.length() + b.length())
  buf.write_bytes(a)
  buf.write_bytes(b)
  buf.to_bytes()
}

///|
/// Parse a list of records as one archive.
fn archive_of(recs : Array[@warc.WarcRecord]) -> @warc.WarcArchive {
  let mut data = b""
  for i = 0; i < recs.length(); i = i + 1 {
    data = cat_bytes(data, recs[i].to_bytes())
  }
  @warc.parse_archive(data, @warc.Limits::default()).unwrap()
}

///|
/// The built-in demo archive: a warcinfo record, two responses that
/// share a target URI, a resource, a revisit and a metadata record.
fn demo_archive() -> @warc.WarcArchive {
  let warcinfo = @warc.WarcBuilder::new()
    .with_type("warcinfo")
    .record_id("<urn:uuid:11111111-1111-1111-1111-111111111111>")
    .warc_date("2020-01-01T00:00:00Z")
    .field("WARC-Filename", "demo.warc")
    .field("Content-Type", "application/warc-fields")
    .build(b"software: moon-warc 0.1.0\r\nformat: WARC File Format 1.1\r\n")
    .unwrap()
  let resp_a = @warc.WarcBuilder::new()
    .with_type("response")
    .record_id("<urn:uuid:22222222-2222-2222-2222-222222222222>")
    .warc_date("2020-01-02T10:30:00Z")
    .field("WARC-Target-URI", "<http://example.org/a>")
    .field("WARC-IP-Address", "192.0.2.1")
    .field("Content-Type", "text/plain")
    .field("WARC-Block-Digest", "sha1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA")
    .build(b"hello from example.org/a\r\n")
    .unwrap()
  let resp_b = @warc.WarcBuilder::new()
    .with_type("response")
    .record_id("<urn:uuid:22222222-2222-2222-2222-222222222223>")
    .warc_date("2020-01-03T10:30:00Z")
    .field("WARC-Target-URI", "<http://example.org/a>")
    .field("Content-Type", "text/plain")
    .field("WARC-Block-Digest", "sha1:BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB")
    .build(b"hello again from example.org/a\r\n")
    .unwrap()
  let resource = @warc.WarcBuilder::new()
    .with_type("resource")
    .record_id("<urn:uuid:33333333-3333-3333-3333-333333333333>")
    .warc_date("2020-01-04T10:30:00Z")
    .field("WARC-Target-URI", "<http://example.org/b>")
    .field("Content-Type", "image/png")
    .build(b"\x89PNG demo")
    .unwrap()
  let revisit = @warc.WarcBuilder::new()
    .with_type("revisit")
    .record_id("<urn:uuid:44444444-4444-4444-4444-444444444444>")
    .warc_date("2020-01-05T10:30:00Z")
    .field("WARC-Target-URI", "<http://example.org/a>")
    .field(
      "WARC-Profile", "<http://netpreserve.org/warc/1.1/revisit/identical-payload-digest>",
    )
    .field("WARC-Refers-To", "<urn:uuid:22222222-2222-2222-2222-222222222222>")
    .field("WARC-Refers-To-Target-URI", "<http://example.org/a>")
    .field("WARC-Refers-To-Date", "2020-01-02T10:30:00Z")
    .field("WARC-Block-Digest", "sha1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA")
    .build(b"")
    .unwrap()
  let metadata = @warc.WarcBuilder::new()
    .with_type("metadata")
    .record_id("<urn:uuid:55555555-5555-5555-5555-555555555555>")
    .warc_date("2020-01-06T10:30:00Z")
    .field("Content-Type", "text/plain")
    .build(b"capture note: demo archive\r\n")
    .unwrap()
  archive_of([warcinfo, resp_a, resp_b, resource, revisit, metadata])
}

///|
/// Render a UTF-8 byte buffer as text (demo blocks are ASCII).
fn bytes_to_string(bytes : Bytes) -> String {
  @utf8.decode(bytes.view(start=0, end=bytes.length())) catch {
    _ => "(non-UTF-8 bytes omitted)"
  }
}
