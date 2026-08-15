// Example: buffered parsing.
//
// @warc.parse_archive() reads a whole in-memory archive at once and returns
// either a @warc.WarcArchive or a structured error carrying the stage and
// kind of the failure.

///|
/// Parse a small archive and report what came back.
pub fn demo_parse() -> Unit {
  let r1 = ex_response(
    "00000000-0000-0000-0000-000000000001", "http://example.org/a", b"page A",
  )
  let r2 = ex_response(
    "00000000-0000-0000-0000-000000000002", "http://example.org/b", b"page B",
  )
  let data = ex_cat(r1.to_bytes(), r2.to_bytes())
  match @warc.parse_archive(data, @warc.Limits::default()) {
    Ok(a) => {
      println("parsed \{a.record_count()} records")
      println("block bytes: \{a.total_block_bytes()}")
    }
    Err(e) => println("error: " + e.to_string())
  }
  // Structured error reporting on truncated input.
  let cut = data.view(start=0, end=data.length() - 2).to_owned()
  match @warc.parse_archive(cut, @warc.Limits::default()) {
    Ok(_) => println("truncated input unexpectedly parsed")
    Err(e) =>
      println(
        "truncated input -> stage=\{e.stage.stage_name()}, kind=\{e.kind.kind_name()}",
      )
  }
}
