// WARC 1.1 core model (ISO 28500:2017).
//
// The record header region is UTF-8 text and is modelled as ordered
// named fields; the record content block is arbitrary binary and stays
// as raw `Bytes`. Field order and original spelling are preserved for
// round-trip fidelity, debugging and forensic analysis.

///|
/// The version string that begins every WARC 1.1 record.
pub const WARC_VERSION_LINE : String = "WARC/1.1"

///|
/// One named field of a WARC record header.
///
/// Per ISO 28500 clause 5, field names are compared case-insensitively;
/// the original spelling is kept so callers can inspect or reproduce it.
pub struct WarcField {
  name : String
  value : String
}

///|
/// A fully framed WARC record: version line, ordered named fields and
/// the raw binary content block.
pub struct WarcRecord {
  version : String
  fields : Array[WarcField]
  block : Bytes
}

///|
/// Construct a named field from its raw spelling and value.
pub fn WarcField::new(name : String, value : String) -> WarcField {
  { name, value }
}

///|
/// Construct a WARC record from its parts.
pub fn WarcRecord::new(
  version : String,
  fields : Array[WarcField],
  block : Bytes,
) -> WarcRecord {
  { version, fields, block }
}

///|
/// The number of octets in the record's content block.
pub fn WarcRecord::block_length(self : WarcRecord) -> Int {
  self.block.length()
}
