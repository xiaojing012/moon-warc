// Content-Length field handling (ISO 28500:2017 clause 5.3).
//
// Content-Length is the single framing authority of a WARC record: it
// states the exact octet count of the content block. Framing never
// searches for record boundaries in the block itself, so the value is
// parsed with the same overflow-safe decimal machinery as every other
// number in the format, and a missing or repeated field is refused
// before framing can become ambiguous.

///|
/// Extract and parse the mandatory Content-Length field of a parsed
/// record header.
///
/// Fails with `MissingRequiredField` when absent, `DuplicateField`
/// when repeated (both spellings being case-insensitive matches),
/// `InvalidContentLength` on a non-decimal value, `IntegerOverflow`
/// when the digit count or value overflows, and `LimitExceeded` when
/// the declared block size exceeds `max_block_bytes`.
pub fn parse_content_length(
  fields : Array[WarcField],
  limits : Limits,
  record_index : Int64,
) -> Result[Int64, WarcError] {
  let found : Array[String] = []
  for i = 0; i < fields.length(); i = i + 1 {
    if fields[i].name.equal_ignore_ascii_case("Content-Length") {
      found.push(fields[i].value)
    }
  }
  if found.length() == 0 {
    return Err(
      WarcError::new(
        WarcErrorStage::ContentLength,
        WarcErrorKind::MissingRequiredField,
        0L,
        record_index,
        "missing mandatory Content-Length field",
      ),
    )
  }
  if found.length() > 1 {
    return Err(
      WarcError::new(
        WarcErrorStage::ContentLength,
        WarcErrorKind::DuplicateField,
        0L,
        record_index,
        "Content-Length must not be repeated",
      ),
    )
  }
  let vb = @utf8.encode(found[0])
  let parsed = parse_decimal(
    vb,
    0,
    vb.length(),
    limits.max_content_length_digits,
    "Content-Length",
  )
  let len = match parsed {
    Ok(x) => x
    Err(e) =>
      return Err(
        WarcError::new(e.stage, e.kind, e.byte_offset, record_index, e.context),
      )
  }
  if len > limits.max_block_bytes {
    return Err(
      WarcError::new(
        WarcErrorStage::ContentLength,
        WarcErrorKind::LimitExceeded,
        0L,
        record_index,
        "Content-Length exceeds max_block_bytes",
      ),
    )
  }
  Ok(len)
}
