// WARC-Date parsing (ISO 28500:2017 clause 5.4).
//
// WARC-Date uses the W3CDTF profile of ISO 8601: a calendar date at
// one of the granularities YYYY, YYYY-MM or YYYY-MM-DD, optionally
// followed by a time of day with one to nine fractional-second digits
// and a mandatory `Z` suffix when the time part is present. Values are
// parsed digit-by-digit over raw bytes; no floating point is involved,
// so fractional seconds are kept as their exact digit string.

///|
/// A parsed WARC-Date. Optional components are absent at coarser
/// granularities; `fraction` is the exact fractional-second digit
/// string ("" when there are no fractional seconds).
pub struct WarcDate {
  year : Int
  month : Int?
  day : Int?
  hour : Int?
  minute : Int?
  second : Int?
  fraction : String
}

///|
/// The days in each month (non-leap year).
fn days_in_month(year : Int, month : Int) -> Int {
  if month == 2 {
    if year % 400 == 0 || (year % 4 == 0 && year % 100 != 0) {
      return 29
    }
    return 28
  }
  let days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
  days[month - 1]
}

///|
/// A structured invalid-date error at a byte offset.
fn bad(pos : Int, record_index : Int64, context : String) -> WarcError {
  WarcError::new(
    WarcErrorStage::Date,
    WarcErrorKind::InvalidDate,
    pos.to_int64(),
    record_index,
    context,
  )
}

///|
/// Read exactly `n` digits at `pos`; on success returns the value and
/// the position past the digits, otherwise a structured error.
fn read_digits(
  data : Bytes,
  pos : Int,
  end : Int,
  n : Int,
  record_index : Int64,
  what : String,
) -> Result[(Int, Int), WarcError] {
  if pos + n > end {
    return Err(bad(pos, record_index, "expected \{n} digits for \{what}"))
  }
  let mut value = 0
  let mut i = pos
  while i < pos + n {
    if !is_digit(data[i]) {
      return Err(bad(i, record_index, "expected \{n} digits for \{what}"))
    }
    value = value * 10 + digit_value(data[i])
    i = i + 1
  }
  Ok((value, pos + n))
}

///|
/// Parse a WARC-Date value (without the field name or line ending).
pub fn parse_warc_date(
  s : String,
  record_index : Int64,
) -> Result[WarcDate, WarcError] {
  let data = @utf8.encode(s)
  parse_warc_date_bytes(data, 0, data.length(), record_index)
}

///|
/// Parse a WARC-Date over a byte span. Shared with the streaming
/// decoder, which works on raw bytes rather than field strings.
pub fn parse_warc_date_bytes(
  data : Bytes,
  start : Int,
  end : Int,
  record_index : Int64,
) -> Result[WarcDate, WarcError] {
  let mut pos = start
  let year_read = read_digits(data, pos, end, 4, record_index, "year")
  let (year, p) = match year_read {
    Ok(x) => x
    Err(e) => return Err(e)
  }
  pos = p
  let mut month : Int? = None
  let mut day : Int? = None
  let mut hour : Int? = None
  let mut minute : Int? = None
  let mut second : Int? = None
  let mut fraction = ""
  if pos < end && data[pos] == b'-' {
    let m_read = read_digits(data, pos + 1, end, 2, record_index, "month")
    let (m, p2) = match m_read {
      Ok(x) => x
      Err(e) => return Err(e)
    }
    if m < 1 || m > 12 {
      return Err(bad(pos, record_index, "month must be between 1 and 12"))
    }
    month = Some(m)
    pos = p2
    if pos < end && data[pos] == b'-' {
      let d_read = read_digits(data, pos + 1, end, 2, record_index, "day")
      let (d, p3) = match d_read {
        Ok(x) => x
        Err(e) => return Err(e)
      }
      if d < 1 || d > days_in_month(year, m) {
        return Err(
          bad(
            pos, record_index, "day is out of range for the given year and month",
          ),
        )
      }
      day = Some(d)
      pos = p3
    }
  }
  if pos < end && data[pos] == b'T' {
    let h_read = read_digits(data, pos + 1, end, 2, record_index, "hour")
    let (h, p4) = match h_read {
      Ok(x) => x
      Err(e) => return Err(e)
    }
    if h > 23 {
      return Err(bad(pos, record_index, "hour must be between 0 and 23"))
    }
    hour = Some(h)
    pos = p4
    if pos < end && data[pos] == b':' {
      let min_read = read_digits(data, pos + 1, end, 2, record_index, "minute")
      let (mi, p5) = match min_read {
        Ok(x) => x
        Err(e) => return Err(e)
      }
      if mi > 59 {
        return Err(bad(pos, record_index, "minute must be between 0 and 59"))
      }
      minute = Some(mi)
      pos = p5
      if pos < end && data[pos] == b':' {
        let s_read = read_digits(data, pos + 1, end, 2, record_index, "second")
        let (sec, p6) = match s_read {
          Ok(x) => x
          Err(e) => return Err(e)
        }
        if sec > 59 {
          return Err(bad(pos, record_index, "second must be between 0 and 59"))
        }
        second = Some(sec)
        pos = p6
        if pos < end && data[pos] == b'.' {
          let fs = pos + 1
          let mut fp = fs
          while fp < end && is_digit(data[fp]) {
            fp = fp + 1
          }
          let flen = fp - fs
          if flen == 0 || flen > 9 {
            return Err(
              bad(
                pos, record_index, "fractional seconds must have 1 to 9 digits",
              ),
            )
          }
          // The bytes are all ASCII digits, so decoding cannot fail.
          fraction = @utf8.decode(data.view(start=fs, end=fp)) catch {
            _ => return Err(bad(fs, record_index, "invalid fractional digits"))
          }
          pos = fp
        }
      }
    }
    // The time form is UTC and must end with Z.
    if pos >= end || data[pos] != b'Z' {
      return Err(bad(pos, record_index, "date-time form must end with Z (UTC)"))
    }
    pos = pos + 1
  }
  if pos != end {
    return Err(bad(pos, record_index, "unexpected trailing characters"))
  }
  Ok(WarcDate::{ year, month, day, hour, minute, second, fraction })
}

///|
/// The four-digit year.
pub fn WarcDate::year(self : WarcDate) -> Int {
  self.year
}

///|
/// The month, present at YYYY-MM granularity and finer.
pub fn WarcDate::month(self : WarcDate) -> Int? {
  self.month
}

///|
/// The day, present at YYYY-MM-DD granularity and finer.
pub fn WarcDate::day(self : WarcDate) -> Int? {
  self.day
}

///|
/// Whether a time of day is present.
pub fn WarcDate::has_time(self : WarcDate) -> Bool {
  self.hour != None
}

///|
/// Whether this is the finest granularity: date plus time plus
/// fractional seconds.
pub fn WarcDate::has_fraction(self : WarcDate) -> Bool {
  self.fraction.length() > 0
}
