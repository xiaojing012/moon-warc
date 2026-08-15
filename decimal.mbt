// Overflow-safe ASCII decimal parsing.
//
// ISO 28500 derives framing decisions from untrusted digit strings
// (Content-Length, WARC-Segment-Number, WARC-Segment-Total-Length), so
// parsing is checked digit by digit: negative values, silent wrapping
// and panics are impossible by construction.

///|
/// Number of leading ASCII digits in `data[start:end]`.
pub fn digit_count(data : Bytes, start : Int, end : Int) -> Int {
  let mut i = start
  while i < end && is_digit(data[i]) {
    i = i + 1
  }
  i - start
}

///|
/// Parse `data[start:end]`, which must consist entirely of ASCII
/// digits, as an `Int64`.
///
/// - an empty span fails with `InvalidContentLength` (a mandatory
///   numeric value is missing);
/// - more than `max_digits` digits or a value beyond `Int64` fails with
///   `IntegerOverflow`.
///
/// `context` names the field for error reporting (e.g. "Content-Length").
pub fn parse_decimal(
  data : Bytes,
  start : Int,
  end : Int,
  max_digits : Int,
  context : String,
) -> Result[Int64, WarcError] {
  if end - start == 0 {
    return Err(
      WarcError::new(
        WarcErrorStage::Number,
        WarcErrorKind::InvalidContentLength,
        start.to_int64(),
        0L,
        context + ": empty value",
      ),
    )
  }
  if end - start > max_digits {
    return Err(
      WarcError::new(
        WarcErrorStage::Number,
        WarcErrorKind::IntegerOverflow,
        start.to_int64(),
        0L,
        context + ": too many digits",
      ),
    )
  }
  let mut value = 0L
  let mut i = start
  while i < end {
    let d = digit_value(data[i])
    if d < 0 {
      return Err(
        WarcError::new(
          WarcErrorStage::Number,
          WarcErrorKind::InvalidContentLength,
          i.to_int64(),
          0L,
          context + ": non-digit byte 0x\{data[i].to_int().to_string(radix=16)}",
        ),
      )
    }
    let next = append_decimal_digit(value, d)
    match next {
      Some(v) => value = v
      None =>
        return Err(
          WarcError::new(
            WarcErrorStage::Number,
            WarcErrorKind::IntegerOverflow,
            start.to_int64(),
            0L,
            context + ": value exceeds Int64",
          ),
        )
    }
    i = i + 1
  }
  Ok(value)
}

///|
/// Append one decimal digit to `value`, returning `None` on overflow.
/// This is also the primitive used by the incremental streaming decoder
/// when a Content-Length is split across input chunks.
pub fn append_decimal_digit(value : Int64, d : Int) -> Int64? {
  if d < 0 || d > 9 {
    return None
  }
  // value * 10 + d <= Int64::max_value without overflow.
  if value > (9_223_372_036_854_775_807L - d.to_int64()) / 10L {
    return None
  }
  Some(value * 10L + d.to_int64())
}
