// WARC record header parsing (ISO 28500:2017 clause 4).
//
// The header is the region between the version line and the blank
// line: a sequence of named fields. This module parses that region
// into ordered WARC fields, folding continuation lines (lines starting
// with SP/HT) into the previous field's value with a single space,
// per the LWS semantics of the specification.

///|
/// Decode `data[start:end]` as strict UTF-8, mapping malformed input
/// to a structured `InvalidUtf8` error.
fn decode_utf8(
  data : Bytes,
  start : Int,
  end : Int,
  record_index : Int64,
) -> Result[String, WarcError] {
  Ok(@utf8.decode(data.view(start~, end~))) catch {
    _ =>
      Err(
        WarcError::new(
          WarcErrorStage::Field,
          WarcErrorKind::InvalidUtf8,
          start.to_int64(),
          record_index,
          "header bytes are not valid UTF-8",
        ),
      )
  }
}

///|
/// Parse named fields from `start` up to and including the blank line
/// that terminates the header.
///
/// Returns the ordered fields and the byte offset just past the blank
/// line, i.e. the start of the content block. Enforces the header
/// size, field count, name length and value length limits.
pub fn parse_header(
  data : Bytes,
  start : Int,
  limits : Limits,
  record_index : Int64,
) -> Result[(Array[WarcField], Int), WarcError] {
  let fields : Array[WarcField] = []
  let mut pos = start
  while true {
    if (pos - start).to_int64() > limits.max_header_bytes {
      return Err(
        WarcError::new(
          WarcErrorStage::Header,
          WarcErrorKind::LimitExceeded,
          pos.to_int64(),
          record_index,
          "header exceeds max_header_bytes",
        ),
      )
    }
    let line = scan_line(data, pos, record_index)
    let (ls, le) = match line {
      Ok(x) => x
      Err(e) => return Err(e)
    }
    let next_pos = le + 2
    if le == ls {
      // The blank line terminates the header.
      return Ok((fields, next_pos))
    }
    if data[ls] == b' ' || data[ls] == b'\t' {
      // Continuation line: fold into the previous field value.
      if fields.length() == 0 {
        return Err(
          WarcError::new(
            WarcErrorStage::Field,
            WarcErrorKind::InvalidFieldName,
            ls.to_int64(),
            record_index,
            "continuation line before any field",
          ),
        )
      }
      // The leading LWS is only the continuation marker; it folds into
      // a single space when real content follows. A line of pure LWS
      // contributes nothing.
      let mut cs = ls
      while cs < le && (data[cs] == b' ' || data[cs] == b'\t') {
        cs = cs + 1
      }
      if cs < le {
        let cont = decode_utf8(data, cs, le, record_index)
        let cont_value = match cont {
          Ok(v) => v
          Err(e) => return Err(e)
        }
        let prev = fields[fields.length() - 1]
        let joined = prev.value + " " + cont_value
        if joined.length() > limits.max_field_value_bytes {
          return Err(
            WarcError::new(
              WarcErrorStage::Field,
              WarcErrorKind::LimitExceeded,
              ls.to_int64(),
              record_index,
              "field value exceeds max_field_value_bytes",
            ),
          )
        }
        fields[fields.length() - 1] = WarcField::new(prev.name, joined)
      }
      pos = next_pos
      continue
    }
    // A new named field line.
    if fields.length() >= limits.max_header_count {
      return Err(
        WarcError::new(
          WarcErrorStage::Header,
          WarcErrorKind::LimitExceeded,
          ls.to_int64(),
          record_index,
          "header field count exceeds max_header_count",
        ),
      )
    }
    let colon = index_of_byte(data, ls, b':')
    if colon < 0 || colon >= le {
      return Err(
        WarcError::new(
          WarcErrorStage::Field,
          WarcErrorKind::MissingColon,
          ls.to_int64(),
          record_index,
          "field line without a colon",
        ),
      )
    }
    if !valid_field_name(data, ls, colon) {
      return Err(
        WarcError::new(
          WarcErrorStage::Field,
          WarcErrorKind::InvalidFieldName,
          ls.to_int64(),
          record_index,
          "invalid field name bytes",
        ),
      )
    }
    if colon - ls > limits.max_field_name_bytes {
      return Err(
        WarcError::new(
          WarcErrorStage::Field,
          WarcErrorKind::LimitExceeded,
          ls.to_int64(),
          record_index,
          "field name exceeds max_field_name_bytes",
        ),
      )
    }
    let name = decode_utf8(data, ls, colon, record_index)
    let name_value = match name {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    // The value may be preceded by linear white space; a single space
    // is preferred but any amount is legal.
    let mut vs = colon + 1
    while vs < le && (data[vs] == b' ' || data[vs] == b'\t') {
      vs = vs + 1
    }
    if le - vs > limits.max_field_value_bytes {
      return Err(
        WarcError::new(
          WarcErrorStage::Field,
          WarcErrorKind::LimitExceeded,
          vs.to_int64(),
          record_index,
          "field value exceeds max_field_value_bytes",
        ),
      )
    }
    let value = decode_utf8(data, vs, le, record_index)
    let value_str = match value {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    fields.push(WarcField::new(name_value, value_str))
    pos = next_pos
  }
  // Unreachable: scan_line fails on unterminated input instead of
  // returning an incomplete line.
  Err(
    WarcError::new(
      WarcErrorStage::Header,
      WarcErrorKind::UnexpectedEof,
      pos.to_int64(),
      record_index,
      "unreachable",
    ),
  )
}
