// WARC record serialization (ISO 28500:2017 clause 4).
//
// A record is written back in canonical byte form: version line, one
// line per field as `name: value`, the blank line, the raw content
// block and the trailing CRLF CRLF. Fields parsed from an archive can
// never contain CR or LF (the header parser enforces line structure),
// so writing them back is lossless: parse → write → parse reproduces
// the record exactly.

///|
/// Serialize a record to its canonical byte form.
///
/// The output is deterministic: field order and spelling are
/// preserved, a single space follows each colon, and the content
/// block is written byte-exact followed by CRLF CRLF. The block
/// boundary is expressed solely by the Content-Length field, as the
/// specification requires.
pub fn WarcRecord::to_bytes(self : WarcRecord) -> Bytes {
  let size = self.version.length() + 2 + self.block.length() + 4
  let mut field_bytes = 0
  for i = 0; i < self.fields.length(); i = i + 1 {
    field_bytes = field_bytes +
      self.fields[i].name.length() +
      self.fields[i].value.length() +
      4
  }
  let buf = Buffer(size_hint=size + field_bytes)
  buf.write_utf8(self.version)
  buf.write_utf8("\r\n")
  for i = 0; i < self.fields.length(); i = i + 1 {
    buf.write_utf8(self.fields[i].name)
    buf.write_utf8(": ")
    buf.write_utf8(self.fields[i].value)
    buf.write_utf8("\r\n")
  }
  buf.write_utf8("\r\n")
  buf.write_bytes(self.block)
  buf.write_utf8("\r\n\r\n")
  buf.to_bytes()
}
