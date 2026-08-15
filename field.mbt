// Named-field token syntax and ordered field lookup
// (ISO 28500:2017 clauses 4 and 5).
//
// Field names follow the RFC 2616 token rule; comparison is
// case-insensitive while the original spelling is preserved. Lookup
// helpers operate on the ordered field array of a parsed record.

///|
/// Whether `b` is an RFC 2616 separator. Separators terminate a token
/// and can never appear inside a field name.
pub fn is_separator(b : Byte) -> Bool {
  match b {
    b'('
    | b')'
    | b'<'
    | b'>'
    | b'@'
    | b','
    | b';'
    | b':'
    | b'\\'
    | b'"'
    | b'/'
    | b'['
    | b']'
    | b'?'
    | b'='
    | b'{'
    | b'}'
    | b' '
    | b'\t' => true
    _ => false
  }
}

///|
/// Whether `b` is a legal token byte: US-ASCII CHAR (0..127), not a
/// control character, not a separator. Bytes above 127 are not tokens.
pub fn is_token_byte(b : Byte) -> Bool {
  b < 0x80 && !is_ctl(b) && !is_separator(b)
}

///|
/// Whether `data[start:end]` forms a valid field name (1*token).
pub fn valid_field_name(data : Bytes, start : Int, end : Int) -> Bool {
  if end - start == 0 {
    return false
  }
  let mut i = start
  while i < end {
    if !is_token_byte(data[i]) {
      return false
    }
    i = i + 1
  }
  true
}

///|
/// The value of the first field with a case-insensitive name match.
pub fn WarcRecord::field_first(self : WarcRecord, name : String) -> String? {
  for i = 0; i < self.fields.length(); i = i + 1 {
    if self.fields[i].name.equal_ignore_ascii_case(name) {
      return Some(self.fields[i].value)
    }
  }
  None
}

///|
/// All values of fields with a case-insensitive name match, in input
/// order (relevant for repeatable fields such as WARC-Concurrent-To).
pub fn WarcRecord::field_all(self : WarcRecord, name : String) -> Array[String] {
  let out : Array[String] = []
  for i = 0; i < self.fields.length(); i = i + 1 {
    if self.fields[i].name.equal_ignore_ascii_case(name) {
      out.push(self.fields[i].value)
    }
  }
  out
}

///|
/// How many fields carry a case-insensitive name match.
pub fn WarcRecord::field_count(self : WarcRecord, name : String) -> Int {
  let mut n = 0
  for i = 0; i < self.fields.length(); i = i + 1 {
    if self.fields[i].name.equal_ignore_ascii_case(name) {
      n = n + 1
    }
  }
  n
}

///|
/// Whether at least one field carries a case-insensitive name match.
pub fn WarcRecord::field_has(self : WarcRecord, name : String) -> Bool {
  self.field_first(name) != None
}
