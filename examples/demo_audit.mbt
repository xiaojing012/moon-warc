// Example: auditing.
//
// The audit engine emits advisory findings — conditions that are
// legal WARC but usually worth a human's attention.

///|
/// Audit a small archive and print every finding.
pub fn demo_audit() -> Unit {
  // No digest, empty block on a response, and a dangling
  // WARC-Refers-To.
  let r1 = ex_response(
    "00000000-0000-0000-0000-000000000031", "http://example.org/a", b"",
  )
  let r2 = @warc.WarcBuilder::new()
    .with_type("revisit")
    .record_id("<urn:uuid:00000000-0000-0000-0000-000000000032>")
    .warc_date("2021-03-14T08:00:00Z")
    .field("WARC-Target-URI", "<http://example.org/a>")
    .field(
      "WARC-Profile", "<http://netpreserve.org/warc/1.1/revisit/identical-payload-digest>",
    )
    .field("WARC-Refers-To", "<urn:uuid:00000000-0000-0000-0000-000000000099>")
    .build(b"")
    .unwrap()
  let fs = @warc.audit_archive(ex_archive_of([r1, r2]))
  for i = 0; i < fs.length(); i = i + 1 {
    println(fs[i].to_string())
  }
}
