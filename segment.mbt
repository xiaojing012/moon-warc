// Record segmentation (ISO 28500:2017 clauses 5.20-5.22 and 7).
//
// A logical record that is too large to store in one physical record
// may be split into a sequence of physical records that share a
// WARC-Segment-Origin-ID: the first record has WARC-Segment-Number 1,
// later records increment the number, and the final record may carry
// WARC-Segment-Total-Length for the whole logical record.
//
// This module parses the three segmentation fields of one record
// (`segment_info`) and reports syntax violations; the sequence-level
// consistency checks (contiguity, increasing numbers, placement of
// the total length) live in `validate_archive` (validator.mbt).

///|
/// The parsed segmentation fields of a record. Absent fields are
/// `None`.
pub struct SegmentInfo {
  number : Int64?
  origin_id : String?
  total_length : Int64?
}

///|
/// Construct segment info from optional parts.
pub fn SegmentInfo::new(
  number : Int64?,
  origin_id : String?,
  total_length : Int64?,
) -> SegmentInfo {
  { number, origin_id, total_length }
}

///|
/// The WARC-Segment-Number value, when present.
pub fn SegmentInfo::number(self : SegmentInfo) -> Int64? {
  self.number
}

///|
/// The interior URI of WARC-Segment-Origin-ID, when present.
pub fn SegmentInfo::origin_id(self : SegmentInfo) -> String? {
  self.origin_id
}

///|
/// The WARC-Segment-Total-Length value, when present.
pub fn SegmentInfo::total_length(self : SegmentInfo) -> Int64? {
  self.total_length
}

///|
/// A structured segmentation error.
fn seg_err(index : Int64, kind : WarcErrorKind, context : String) -> WarcError {
  WarcError::new(WarcErrorStage::Segment, kind, 0L, index, context)
}

///|
/// Parse the segmentation fields of a record.
///
/// Fails when a field is present but malformed: a non-decimal or
/// non-positive WARC-Segment-Number, a WARC-Segment-Origin-ID that is
/// not a `<uri>`, or a non-decimal WARC-Segment-Total-Length.
pub fn WarcRecord::segment_info(
  self : WarcRecord,
  index : Int64,
) -> Result[SegmentInfo, WarcError] {
  let number = match field_first_of(self.fields, "WARC-Segment-Number") {
    Some(v) => {
      let vb = @utf8.encode(v)
      let parsed = parse_decimal(vb, 0, vb.length(), 19, "WARC-Segment-Number")
      match parsed {
        Ok(n) => {
          if n < 1 {
            return Err(
              seg_err(
                index,
                WarcErrorKind::InvalidFieldValue,
                "WARC-Segment-Number must be at least 1",
              ),
            )
          }
          Some(n)
        }
        Err(_) =>
          return Err(
            seg_err(
              index,
              WarcErrorKind::InvalidFieldValue,
              "WARC-Segment-Number is not a decimal integer",
            ),
          )
      }
    }
    None => (None : Int64?)
  }
  let origin_id = match field_first_of(self.fields, "WARC-Segment-Origin-ID") {
    Some(v) => {
      let parsed = parse_uri_ref(v, index)
      match parsed {
        Ok(interior) => Some(interior)
        Err(_) =>
          return Err(
            seg_err(
              index,
              WarcErrorKind::InvalidUri,
              "WARC-Segment-Origin-ID must be written as <uri>",
            ),
          )
      }
    }
    None => (None : String?)
  }
  let total_length = match
    field_first_of(self.fields, "WARC-Segment-Total-Length") {
    Some(v) => {
      let vb = @utf8.encode(v)
      let parsed = parse_decimal(
        vb,
        0,
        vb.length(),
        19,
        "WARC-Segment-Total-Length",
      )
      match parsed {
        Ok(n) => Some(n)
        Err(_) =>
          return Err(
            seg_err(
              index,
              WarcErrorKind::InvalidFieldValue,
              "WARC-Segment-Total-Length is not a decimal integer",
            ),
          )
      }
    }
    None => (None : Int64?)
  }
  Ok(SegmentInfo::new(number, origin_id, total_length))
}

///|
/// Segmentation field syntax errors of one record, if any.
pub fn segment_errors(rec : WarcRecord, index : Int64) -> Array[WarcError] {
  let errs : Array[WarcError] = []
  let parsed = rec.segment_info(index)
  match parsed {
    Ok(_) => ()
    Err(e) => errs.push(e)
  }
  errs
}
