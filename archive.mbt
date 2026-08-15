// Buffered whole-archive parsing (ISO 28500:2017 clause 4).
//
// A WARC archive is one or more records back to back. This module
// parses a complete in-memory archive into an ordered list of records,
// enforces the archive-level limits, and diagnoses trailing bytes that
// do not form a complete record.

///|
/// A fully parsed in-memory WARC archive: the records in file order.
pub struct WarcArchive {
  records : Array[WarcRecord]
}

///|
/// The number of records in the archive.
pub fn WarcArchive::record_count(self : WarcArchive) -> Int {
  self.records.length()
}

///|
/// The record at `index`, or `None` when out of range.
pub fn WarcArchive::record(self : WarcArchive, index : Int) -> WarcRecord? {
  if index < 0 || index >= self.records.length() {
    return None
  }
  Some(self.records[index])
}

///|
/// The total number of octets across all content blocks.
pub fn WarcArchive::total_block_bytes(self : WarcArchive) -> Int64 {
  let mut total = 0L
  for i = 0; i < self.records.length(); i = i + 1 {
    total = total + self.records[i].block.length().to_int64()
  }
  total
}

///|
/// Parse a complete archive from a byte buffer.
///
/// An empty buffer parses to an archive with no records. Bytes that
/// follow the last complete record but cannot form another complete
/// record — a truncated record or a version line that is not
/// `WARC/1.1` — are reported as `TrailingGarbage`; failures inside the
/// first record keep their original, more specific diagnosis. Enforces
/// `max_archive_bytes` and `max_records`.
pub fn parse_archive(
  data : Bytes,
  limits : Limits,
) -> Result[WarcArchive, WarcError] {
  if data.length().to_int64() > limits.max_archive_bytes {
    return Err(
      WarcError::new(
        WarcErrorStage::Archive,
        WarcErrorKind::LimitExceeded,
        0L,
        0L,
        "archive exceeds max_archive_bytes",
      ),
    )
  }
  let records : Array[WarcRecord] = []
  let mut pos = 0
  let mut index = 0
  while pos < data.length() {
    if index >= limits.max_records {
      return Err(
        WarcError::new(
          WarcErrorStage::Archive,
          WarcErrorKind::LimitExceeded,
          pos.to_int64(),
          index.to_int64(),
          "record count exceeds max_records",
        ),
      )
    }
    let r = parse_record(data, pos, limits, index.to_int64())
    let (rec, next) = match r {
      Ok(x) => x
      Err(e) =>
        if index > 0 && (e.kind == UnexpectedEof || e.kind == InvalidVersion) {
          return Err(
            WarcError::new(
              WarcErrorStage::Archive,
              WarcErrorKind::TrailingGarbage,
              pos.to_int64(),
              index.to_int64(),
              "trailing bytes after record \{index - 1} do not form a complete record: \{e.context}",
            ),
          )
        } else {
          return Err(e)
        }
    }
    records.push(rec)
    pos = next
    index = index + 1
  }
  Ok(WarcArchive::{ records, })
}
