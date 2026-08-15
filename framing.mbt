// Binary-safe record framing (ISO 28500:2017 clause 4).
//
// A record is `version CRLF fields CRLF block CRLF CRLF`. The block
// boundary is computed exclusively from Content-Length; the parser
// never scans block bytes for framing markers, so arbitrary binary
// payloads (including bytes that spell "WARC/1.1" or CRLF pairs)
// cannot confuse it.

///|
/// Parse one complete record starting at `start`.
///
/// Returns the record and the offset of the next record (just past
/// the trailing CRLF CRLF). Fails with a structured `WarcError` on
/// malformed framing: unterminated lines, bad version, bad header,
/// missing/duplicate/overflowing Content-Length, a truncated block or
/// a missing/invalid trailing CRLF CRLF separator.
pub fn parse_record(
  data : Bytes,
  start : Int,
  limits : Limits,
  record_index : Int64,
) -> Result[(WarcRecord, Int), WarcError] {
  // Version line.
  let line = scan_line(data, start, record_index)
  let (vs, ve) = match line {
    Ok(x) => x
    Err(e) => return Err(e)
  }
  let version = parse_version_line(data, vs, ve, record_index)
  let version_str = match version {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  // Fields and blank line; the returned offset is the block start.
  let header = parse_header(data, ve + 2, limits, record_index)
  let (fields, block_start) = match header {
    Ok(x) => x
    Err(e) => return Err(e)
  }
  // Content-Length is the sole framing authority.
  let len = parse_content_length(fields, limits, record_index)
  let block_len = match len {
    Ok(x) => x
    Err(e) => return Err(e)
  }
  let block_end = block_start + block_len.to_int()
  // The block plus the trailing CRLF CRLF must fit in the input.
  if data.length() < block_end + 4 {
    return Err(
      WarcError::new(
        WarcErrorStage::Block,
        WarcErrorKind::UnexpectedEof,
        data.length().to_int64(),
        record_index,
        "record truncated: content block or trailing CRLF CRLF missing",
      ),
    )
  }
  if data[block_end] != b'\r' ||
    data[block_end + 1] != b'\n' ||
    data[block_end + 2] != b'\r' ||
    data[block_end + 3] != b'\n' {
    return Err(
      WarcError::new(
        WarcErrorStage::Separator,
        WarcErrorKind::InvalidSeparator,
        block_end.to_int64(),
        record_index,
        "record must end with CRLF CRLF after the content block",
      ),
    )
  }
  let next = block_end + 4
  if (next - start).to_int64() > limits.max_record_bytes {
    return Err(
      WarcError::new(
        WarcErrorStage::Record,
        WarcErrorKind::LimitExceeded,
        start.to_int64(),
        record_index,
        "record exceeds max_record_bytes",
      ),
    )
  }
  let block = data[block_start:block_end].to_owned()
  Ok((WarcRecord::new(version_str, fields, block), next))
}
