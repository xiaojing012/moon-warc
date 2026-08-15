// WARC version line parsing (ISO 28500:2017 clause 4).
//
// The version line must appear first in every record and hence begins
// the WARC file itself. Only the exact "WARC/1.1" spelling of the 2017
// edition of the standard is accepted.

///|
/// Parse a raw version line (without its trailing CRLF) as the WARC
/// version string.
///
/// Any other spelling — including WARC/1.0, which differs in its
/// framing rules — yields a structured `InvalidVersion` error.
pub fn parse_version_line(
  data : Bytes,
  start : Int,
  end : Int,
  record_index : Int64,
) -> Result[String, WarcError] {
  if eq_bytes(data, start, end, WARC_VERSION_LINE) {
    return Ok(WARC_VERSION_LINE)
  }
  let context = if eq_bytes(data, start, end, "WARC/1.0") {
    "WARC/1.0 records are not supported (ISO 28500:2017 WARC/1.1 only)"
  } else {
    "expected the exact version line WARC/1.1"
  }
  Err(
    WarcError::new(
      WarcErrorStage::Version,
      WarcErrorKind::InvalidVersion,
      start.to_int64(),
      record_index,
      context,
    ),
  )
}
