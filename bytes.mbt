// Raw byte helpers used by the WARC parser.
//
// WARC content blocks may hold arbitrary binary (images, audio,
// compressed data, HTTP message bytes), so framing decisions are made
// exclusively on byte values. All positions are byte offsets.

///|
/// ASCII carriage return (13).
pub fn is_cr(b : Byte) -> Bool {
  b == b'\r'
}

///|
/// ASCII line feed (10).
pub fn is_lf(b : Byte) -> Bool {
  b == b'\n'
}

///|
/// ASCII space (32).
pub fn is_sp(b : Byte) -> Bool {
  b == b' '
}

///|
/// ASCII horizontal tab (9).
pub fn is_ht(b : Byte) -> Bool {
  b == b'\t'
}

///|
/// ASCII digit '0'..'9'.
pub fn is_digit(b : Byte) -> Bool {
  b >= b'0' && b <= b'9'
}

///|
/// US-ASCII upper-case letter.
pub fn is_upper_ascii(b : Byte) -> Bool {
  b >= b'A' && b <= b'Z'
}

///|
/// US-ASCII lower-case letter.
pub fn is_lower_ascii(b : Byte) -> Bool {
  b >= b'a' && b <= b'z'
}

///|
/// US-ASCII control character (0..31 or 127).
pub fn is_ctl(b : Byte) -> Bool {
  b < b' ' || b == b'\x7f'
}

///|
/// Lower-case an US-ASCII letter; other bytes are returned unchanged.
pub fn lower_ascii(b : Byte) -> Byte {
  if b >= b'A' && b <= b'Z' {
    b + 32
  } else {
    b
  }
}

///|
/// The decimal value of an ASCII digit byte, or -1 if it is no digit.
pub fn digit_value(b : Byte) -> Int {
  if is_digit(b) {
    (b - b'0').to_int()
  } else {
    -1
  }
}

///|
/// Whether `data[start:end]` byte-equals `needle` ignoring ASCII case.
pub fn eq_ignore_ascii_case(
  data : Bytes,
  start : Int,
  end : Int,
  needle : String,
) -> Bool {
  let nb = @utf8.encode(needle)
  if end - start != nb.length() {
    return false
  }
  let mut i = 0
  while i < nb.length() {
    if lower_ascii(data[start + i]) != lower_ascii(nb[i]) {
      return false
    }
    i = i + 1
  }
  true
}

///|
/// Whether `data` starts with the byte sequence `prefix`.
pub fn starts_with(data : Bytes, prefix : Bytes) -> Bool {
  if data.length() < prefix.length() {
    return false
  }
  let mut i = 0
  while i < prefix.length() {
    if data[i] != prefix[i] {
      return false
    }
    i = i + 1
  }
  true
}

///|
/// Index of the first `needle` byte at or after `from`, or -1.
pub fn index_of_byte(data : Bytes, from : Int, needle : Byte) -> Int {
  let mut i = from
  while i < data.length() {
    if data[i] == needle {
      return i
    }
    i = i + 1
  }
  -1
}

///|
/// Index of the CR that starts a CRLF pair at or after `from`, or -1.
///
/// A trailing CR without a following LF is never reported: it cannot
/// form a line ending and the caller must treat it as data (or EOF).
pub fn find_crlf(data : Bytes, from : Int) -> Int {
  let mut i = from
  while i + 1 < data.length() {
    if data[i] == b'\r' && data[i + 1] == b'\n' {
      return i
    }
    i = i + 1
  }
  -1
}

///|
/// Whether `data[start:end]` consists solely of US-ASCII digits.
pub fn all_digits(data : Bytes, start : Int, end : Int) -> Bool {
  let mut i = start
  while i < end {
    if !is_digit(data[i]) {
      return false
    }
    i = i + 1
  }
  true
}
