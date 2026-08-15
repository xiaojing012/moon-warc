// Streaming WARC decoding (ISO 28500:2017 clause 4).
//
// `WarcDecoder` turns an incremental byte stream into WARC records.
// Callers feed arbitrary chunks; each `feed` returns the records that
// became complete within that chunk, and `finish` diagnoses bytes left
// over at end of input. The decoder never buffers more than one
// record's worth of input, and it never scans content blocks for
// framing markers: the block boundary is taken from Content-Length
// only. (Input that never terminates a header is buffered until the
// archive-level byte limit is reached, mirroring the buffered parser.)
//
// Decoding is chunking-independent: for any byte stream, feeding it in
// any sequence of chunks yields exactly the same records, or exactly
// the same structured error, as parsing the stream in one piece.

///|
/// A partially parsed record whose header is complete but whose block
/// and trailing CRLF CRLF have not fully arrived.
struct PendingRecord {
  version : String
  fields : Array[WarcField]
  block_start : Int
  block_len : Int64
}

///|
/// A streaming WARC decoder.
pub struct WarcDecoder {
  limits : Limits
  mut bytes : Bytes
  mut start : Int
  mut pos : Int64
  mut records_done : Int
  mut total_fed : Int64
  mut pending : PendingRecord?
  mut error : WarcError?
}

///|
/// Rebuild a copy of an error from its parts (the decoder replays a
/// stored error on every later call).
fn dup_error(e : WarcError) -> WarcError {
  WarcError::new(e.stage, e.kind, e.byte_offset, e.record_index, e.context)
}

///|
/// Shift the byte offset of an error parsed from a buffer fragment to
/// its absolute position in the input stream.
fn shift_error(e : WarcError, delta : Int64) -> WarcError {
  WarcError::new(
    e.stage,
    e.kind,
    e.byte_offset + delta,
    e.record_index,
    e.context,
  )
}

///|
/// Relabel a parse failure after at least one complete record as
/// trailing garbage, mirroring `parse_archive`.
fn trailing_error(
  e : WarcError,
  offset : Int64,
  record_index : Int64,
) -> WarcError {
  WarcError::new(
    WarcErrorStage::Archive,
    WarcErrorKind::TrailingGarbage,
    offset,
    record_index,
    "trailing bytes after record \{record_index - 1} do not form a complete record: \{e.context}",
  )
}

///|
/// Index just past the first CRLF CRLF sequence at or after `from`,
/// or -1 when none is present. The first blank line ends the header:
/// no header line can contain CR or LF, so the first CRLF CRLF in the
/// stream is always the header terminator (or evidence of a structural
/// error, which the shared header parser reports).
fn find_header_end(data : Bytes, from : Int) -> Int {
  let mut i = from
  while i + 3 < data.length() {
    if data[i] == b'\r' &&
      data[i + 1] == b'\n' &&
      data[i + 2] == b'\r' &&
      data[i + 3] == b'\n' {
      return i + 4
    }
    i = i + 1
  }
  -1
}

///|
/// Create a decoder with the given limits.
pub fn WarcDecoder::new(limits : Limits) -> WarcDecoder {
  {
    limits,
    bytes: b"",
    start: 0,
    pos: 0L,
    records_done: 0,
    total_fed: 0L,
    pending: None,
    error: None,
  }
}

///|
/// Record a terminal error and return it.
fn WarcDecoder::fail(self : WarcDecoder, e : WarcError) -> WarcError {
  self.error = Some(dup_error(e))
  e
}

///|
/// Feed one chunk of the input stream.
///
/// Returns the records completed by this chunk (possibly none). The
/// first error makes the decoder terminal: later `feed`/`finish` calls
/// return the same error. Enforces `max_archive_bytes` across the
/// whole stream, `max_records` at each record boundary and all
/// per-record limits through the shared parsing functions.
pub fn WarcDecoder::feed(
  self : WarcDecoder,
  chunk : Bytes,
) -> Result[Array[WarcRecord], WarcError] {
  match self.error {
    Some(e) => return Err(dup_error(e))
    None => ()
  }
  self.total_fed = self.total_fed + chunk.length().to_int64()
  if self.total_fed > self.limits.max_archive_bytes {
    return Err(
      self.fail(
        WarcError::new(
          WarcErrorStage::Archive,
          WarcErrorKind::LimitExceeded,
          0L,
          0L,
          "archive exceeds max_archive_bytes",
        ),
      ),
    )
  }
  // Append the chunk to the unconsumed remainder.
  if self.start == self.bytes.length() {
    self.bytes = chunk
    self.start = 0
  } else {
    let buf = Buffer(
      size_hint=self.bytes.length() - self.start + chunk.length(),
    )
    buf.write_bytes(self.bytes[self.start:])
    buf.write_bytes(chunk)
    self.bytes = buf.to_bytes()
    self.start = 0
  }
  let out : Array[WarcRecord] = []
  while self.start < self.bytes.length() {
    if self.records_done >= self.limits.max_records {
      return Err(
        self.fail(
          WarcError::new(
            WarcErrorStage::Archive,
            WarcErrorKind::LimitExceeded,
            self.pos,
            self.records_done.to_int64(),
            "record count exceeds max_records",
          ),
        ),
      )
    }
    match self.pending {
      None => {
        // Header phase: wait for the blank line that ends the header.
        let idx = find_header_end(self.bytes, self.start)
        if idx < 0 {
          break
        }
        let rec_ix = self.records_done.to_int64()
        let rec_start = self.pos
        // Parse the completed header with the same functions the
        // buffered parser uses. Their offsets are relative to the
        // header fragment, so shift them to the absolute stream
        // position.
        let slice = self.bytes[self.start:idx].to_owned()
        let line = scan_line(slice, 0, rec_ix)
        let (vs, ve) = match line {
          Ok(x) => x
          Err(e) => return Err(self.fail(shift_error(e, rec_start)))
        }
        let version = parse_version_line(slice, vs, ve, rec_ix)
        let version_str = match version {
          Ok(v) => v
          Err(e) =>
            if self.records_done > 0 && e.kind == InvalidVersion {
              return Err(self.fail(trailing_error(e, rec_start, rec_ix)))
            } else {
              return Err(self.fail(shift_error(e, rec_start)))
            }
        }
        let hdr = parse_header(slice, ve + 2, self.limits, rec_ix)
        let (fields, block_start) = match hdr {
          Ok(x) => x
          Err(e) => return Err(self.fail(shift_error(e, rec_start)))
        }
        // Content-Length errors carry their own offsets and must not
        // be shifted.
        let len = parse_content_length(fields, self.limits, rec_ix)
        let block_len = match len {
          Ok(x) => x
          Err(e) => return Err(self.fail(e))
        }
        self.pending = Some(PendingRecord::{
          version: version_str,
          fields,
          block_start,
          block_len,
        })
      }
      Some(p) => {
        // Block phase: Content-Length is the sole framing authority.
        // The block bytes are never scanned.
        let need = p.block_start + p.block_len.to_int() + 4
        if self.bytes.length() - self.start < need {
          break
        }
        let sep = self.start + p.block_start + p.block_len.to_int()
        if self.bytes[sep] != b'\r' ||
          self.bytes[sep + 1] != b'\n' ||
          self.bytes[sep + 2] != b'\r' ||
          self.bytes[sep + 3] != b'\n' {
          return Err(
            self.fail(
              WarcError::new(
                WarcErrorStage::Separator,
                WarcErrorKind::InvalidSeparator,
                self.pos + (sep - self.start).to_int64(),
                self.records_done.to_int64(),
                "record must end with CRLF CRLF after the content block",
              ),
            ),
          )
        }
        if need.to_int64() > self.limits.max_record_bytes {
          return Err(
            self.fail(
              WarcError::new(
                WarcErrorStage::Record,
                WarcErrorKind::LimitExceeded,
                self.pos,
                self.records_done.to_int64(),
                "record exceeds max_record_bytes",
              ),
            ),
          )
        }
        let block_start_abs = self.start + p.block_start
        let block = self.bytes[block_start_abs:block_start_abs +
        p.block_len.to_int()].to_owned()
        out.push(WarcRecord::new(p.version, p.fields, block))
        self.start = self.start + need
        self.pos = self.pos + need.to_int64()
        self.records_done = self.records_done + 1
        self.pending = None
      }
    }
  }
  if self.start == self.bytes.length() {
    self.bytes = b""
    self.start = 0
  }
  Ok(out)
}

///|
/// Signal end of input.
///
/// Returns `Ok` when the stream ended exactly at a record boundary
/// and every record was complete. Bytes that remain at end of input —
/// a truncated record or anything after the last complete record that
/// cannot start a new one — are reported with the same
/// trailing-garbage semantics as `parse_archive`.
pub fn WarcDecoder::finish(self : WarcDecoder) -> Result[Unit, WarcError] {
  match self.error {
    Some(e) => return Err(dup_error(e))
    None => ()
  }
  let rec_ix = self.records_done.to_int64()
  let remaining = self.bytes.length() - self.start
  match self.pending {
    Some(_) => {
      // The header was complete but the block never arrived.
      let e = WarcError::new(
        WarcErrorStage::Block,
        WarcErrorKind::UnexpectedEof,
        self.pos + remaining.to_int64(),
        rec_ix,
        "record truncated: content block or trailing CRLF CRLF missing",
      )
      if self.records_done > 0 {
        return Err(trailing_error(e, self.pos, rec_ix))
      }
      return Err(e)
    }
    None => {
      if remaining == 0 {
        return Ok(())
      }
      let r = parse_record(self.bytes, self.start, self.limits, rec_ix)
      match r {
        Ok(_) =>
          // Unreachable: the feed loop consumes any record the moment
          // its bytes are complete.
          return Err(
            WarcError::new(
              WarcErrorStage::Input,
              WarcErrorKind::UnexpectedEof,
              self.pos,
              rec_ix,
              "internal: incomplete input parsed as a complete record",
            ),
          )
        Err(e) =>
          if self.records_done > 0 &&
            (e.kind == UnexpectedEof || e.kind == InvalidVersion) {
            return Err(trailing_error(e, self.pos, rec_ix))
          } else {
            return Err(shift_error(e, self.pos))
          }
      }
    }
  }
}
