// URI-reference values (ISO 28500:2017 clause 5.2).
//
// WARC fields such as WARC-Record-ID and WARC-Target-URI carry a URI
// reference written as `<uri>`. This module validates that envelope:
// the surrounding angle brackets, a non-empty interior, and the
// absence of whitespace and control characters. Deeper URI grammar
// checks (scheme rules, percent-encoding) belong to the validator.

///|
/// A structured invalid-uri error at a byte offset.
fn bad_uri(record_index : Int64, offset : Int, context : String) -> WarcError {
  WarcError::new(
    WarcErrorStage::Uri,
    WarcErrorKind::InvalidUri,
    offset.to_int64(),
    record_index,
    context,
  )
}

///|
/// Parse a `<uri>` field value and return the URI inside the angle
/// brackets.
///
/// Fails with `InvalidUri` when the value is not exactly `<...>` with
/// a non-empty interior, or when the interior contains whitespace or
/// control characters.
pub fn parse_uri_ref(
  s : String,
  record_index : Int64,
) -> Result[String, WarcError] {
  let data = @utf8.encode(s)
  let len = data.length()
  if len < 3 || data[0] != b'<' || data[len - 1] != b'>' {
    return Err(bad_uri(record_index, 0, "URI value must be written as <uri>"))
  }
  let mut i = 1
  while i < len - 1 {
    let b = data[i]
    if is_sp(b) || is_ht(b) || is_cr(b) || is_lf(b) || is_ctl(b) {
      return Err(
        bad_uri(
          record_index, i, "URI must not contain whitespace or control characters",
        ),
      )
    }
    i = i + 1
  }
  // Interior bytes came from a String, so decoding cannot fail.
  let interior = @utf8.decode(data.view(start=1, end=len - 1)) catch {
    _ => return Err(bad_uri(record_index, 0, "URI is not valid UTF-8"))
  }
  Ok(interior)
}
