// Example: semantic validation.
//
// The validator reports specification violations (placement, value
// domains, segmentation, record-id duplicates) as a list of errors,
// one per violation.

///|
/// Validate a well-formed archive and a broken record.
pub fn demo_validate() -> Unit {
  let good = ex_response(
    "00000000-0000-0000-0000-000000000011", "http://example.org/ok", b"fine",
  )
  let a = ex_archive_of([good])
  let errs = @warc.validate_archive(a)
  println("good archive: \{errs.length()} violation(s)")
  // A revisit without WARC-Profile, and a response whose
  // WARC-IP-Address is malformed.
  let bad = @warc.WarcBuilder::new()
    .with_type("revisit")
    .record_id("<urn:uuid:00000000-0000-0000-0000-000000000012>")
    .warc_date("2021-03-14T08:00:00Z")
    .field("WARC-Target-URI", "<http://example.org/ok>")
    .field("WARC-IP-Address", "999.1.1.1")
    .build(b"")
    .unwrap()
  let bad_errs = @warc.validate_archive(ex_archive_of([bad]))
  for i = 0; i < bad_errs.length(); i = i + 1 {
    println("  " + bad_errs[i].to_string())
  }
}
