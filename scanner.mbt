// Line scanning over raw WARC header bytes.
//
// WARC headers are CRLF-delimited (ISO 28500 clause 4). Lone CR or LF
// bytes corrupt the framing, so they are reported as structured errors
// instead of being silently tolerated as line breaks.

///|
/// Scan one CRLF-terminated line starting at `from`.
///
/// Returns `(line_start, line_end)` where `[line_start, line_end)`
/// excludes the trailing CRLF. Fails with `UnexpectedEof` when the
/// buffer ends without a line terminator and with `InvalidSeparator`
/// on a bare CR or bare LF.
pub fn scan_line(
  data : Bytes,
  from : Int,
  record_index : Int64,
) -> Result[(Int, Int), WarcError] {
  let mut i = from
  while i < data.length() {
    let b = data[i]
    if b == b'\r' {
      if i + 1 < data.length() && data[i + 1] == b'\n' {
        return Ok((from, i))
      }
      return Err(
        WarcError::new(
          WarcErrorStage::Separator,
          WarcErrorKind::InvalidSeparator,
          i.to_int64(),
          record_index,
          "bare CR without LF",
        ),
      )
    }
    if b == b'\n' {
      return Err(
        WarcError::new(
          WarcErrorStage::Separator,
          WarcErrorKind::InvalidSeparator,
          i.to_int64(),
          record_index,
          "bare LF without CR",
        ),
      )
    }
    i = i + 1
  }
  Err(
    WarcError::new(
      WarcErrorStage::Separator,
      WarcErrorKind::UnexpectedEof,
      data.length().to_int64(),
      record_index,
      "unterminated line",
    ),
  )
}
