// Example: indexing and querying.
//
// @warc.WarcIndex maps record ids, target URIs and record types to record
// indices. All values are compared as strings; a target URI is never
// interpreted as a file-system path.

///|
/// Build an index and query it by target URI and by type.
pub fn demo_index() -> Unit {
  let r1 = ex_response(
    "00000000-0000-0000-0000-000000000021", "http://example.org/a", b"first capture of A",
  )
  let r2 = ex_response(
    "00000000-0000-0000-0000-000000000022", "http://example.org/a", b"second capture of A",
  )
  let r3 = @warc.WarcBuilder::new()
    .with_type("resource")
    .record_id("<urn:uuid:00000000-0000-0000-0000-000000000023>")
    .warc_date("2021-03-14T08:00:00Z")
    .field("WARC-Target-URI", "<http://example.org/b>")
    .build(b"asset")
    .unwrap()
  let idx = @warc.WarcIndex::build(ex_archive_of([r1, r2, r3]))
  println("index size: \{idx.size()}")
  let hits = idx.by_target_uri("http://example.org/a")
  println("target http://example.org/a -> records: " + join_ints(hits))
  let responses = idx.by_type(@warc.record_type_of_code("response").unwrap())
  println("type response -> records: " + join_ints(responses))
  match idx.by_record_id("urn:uuid:00000000-0000-0000-0000-000000000021") {
    Some(i) => println("record id ...021 -> record \{i}")
    None => println("record id ...021 -> not found")
  }
}

///|
/// Render an index list as "0, 1".
fn join_ints(xs : Array[Int]) -> String {
  let parts : Array[String] = []
  for i = 0; i < xs.length(); i = i + 1 {
    parts.push(xs[i].to_string())
  }
  let mut s = ""
  for i = 0; i < parts.length(); i = i + 1 {
    if i > 0 {
      s = s + ", "
    }
    s = s + parts[i]
  }
  s
}
