// WARC record construction (ISO 28500:2017 clause 4).
//
// `WarcBuilder` assembles records programmatically: fields are added
// in order, Content-Length is generated automatically from the block
// (or checked against it when the caller provided one), and names and
// values are validated so the built record always serializes to a
// parseable byte form.

///|
/// Whether a field value can be written back as a single header line.
/// CR and LF would break the line structure, so values containing them
/// are rejected at build time rather than silently mangled.
fn value_is_single_line(value : String) -> Bool {
  let b = @utf8.encode(value)
  for i = 0; i < b.length(); i = i + 1 {
    if is_cr(b[i]) || is_lf(b[i]) {
      return false
    }
  }
  true
}

///|
/// An incremental WARC record builder.
pub struct WarcBuilder {
  mut version : String
  fields : Array[WarcField]
}

///|
/// Create a builder for a WARC/1.1 record with no fields.
pub fn WarcBuilder::new() -> WarcBuilder {
  { version: WARC_VERSION_LINE, fields: [] }
}

///|
/// Set the version line. Only `WARC/1.1` is accepted at build time.
pub fn WarcBuilder::version(self : WarcBuilder, v : String) -> WarcBuilder {
  self.version = v
  self
}

///|
/// Append a named field. The original spelling is preserved; names are
/// validated at build time and values must fit on one header line.
pub fn WarcBuilder::field(
  self : WarcBuilder,
  name : String,
  value : String,
) -> WarcBuilder {
  self.fields.push(WarcField::new(name, value))
  self
}

///|
/// Append a WARC-Type field.
pub fn WarcBuilder::with_type(self : WarcBuilder, t : String) -> WarcBuilder {
  self.field("WARC-Type", t)
}

///|
/// Append a WARC-Record-ID field (value in `<uri>` form).
pub fn WarcBuilder::record_id(self : WarcBuilder, uri : String) -> WarcBuilder {
  self.field("WARC-Record-ID", uri)
}

///|
/// Append a WARC-Date field (W3CDTF UTC timestamp).
pub fn WarcBuilder::warc_date(self : WarcBuilder, date : String) -> WarcBuilder {
  self.field("WARC-Date", date)
}

///|
/// Append a WARC-Target-URI field (value in `<uri>` form).
pub fn WarcBuilder::target_uri(self : WarcBuilder, uri : String) -> WarcBuilder {
  self.field("WARC-Target-URI", uri)
}

///|
/// Build the record around a content block.
///
/// A missing Content-Length is generated from the block size; a
/// present one must match it exactly (and must not be repeated). Field
/// names must be legal tokens and values must be single-line, so the
/// result always serializes to a parseable record.
pub fn WarcBuilder::build(
  self : WarcBuilder,
  block : Bytes,
) -> Result[WarcRecord, WarcError] {
  if self.version != WARC_VERSION_LINE {
    return Err(
      WarcError::new(
        WarcErrorStage::Builder,
        WarcErrorKind::InvalidVersion,
        0L,
        0L,
        "builder version must be exactly WARC/1.1",
      ),
    )
  }
  for i = 0; i < self.fields.length(); i = i + 1 {
    let name_bytes = @utf8.encode(self.fields[i].name)
    if !valid_field_name(name_bytes, 0, name_bytes.length()) {
      return Err(
        WarcError::new(
          WarcErrorStage::Builder,
          WarcErrorKind::InvalidFieldName,
          i.to_int64(),
          0L,
          "field name \{i} is not a legal token",
        ),
      )
    }
    if !value_is_single_line(self.fields[i].value) {
      return Err(
        WarcError::new(
          WarcErrorStage::Builder,
          WarcErrorKind::InvalidFieldValue,
          i.to_int64(),
          0L,
          "field value \{i} contains CR or LF and cannot be written as one header line",
        ),
      )
    }
  }
  let cl_count = field_count_of(self.fields, "Content-Length")
  if cl_count > 1 {
    return Err(
      WarcError::new(
        WarcErrorStage::Builder,
        WarcErrorKind::DuplicateField,
        0L,
        0L,
        "Content-Length must not be repeated",
      ),
    )
  }
  let fields = self.fields
  if cl_count == 0 {
    fields.push(WarcField::new("Content-Length", block.length().to_string()))
  } else {
    let declared = field_first_of(fields, "Content-Length").unwrap()
    let vb = @utf8.encode(declared)
    let parsed = parse_decimal(vb, 0, vb.length(), 19, "Content-Length")
    match parsed {
      Ok(n) =>
        if n != block.length().to_int64() {
          return Err(
            WarcError::new(
              WarcErrorStage::Builder,
              WarcErrorKind::ContentLengthMismatch,
              0L,
              0L,
              "declared Content-Length does not match the block size",
            ),
          )
        }
      Err(_) =>
        return Err(
          WarcError::new(
            WarcErrorStage::Builder,
            WarcErrorKind::InvalidContentLength,
            0L,
            0L,
            "declared Content-Length is not a decimal octet count",
          ),
        )
    }
  }
  Ok(WarcRecord::new(WARC_VERSION_LINE, fields, block))
}

///|
/// Count fields with a case-insensitive name match.
fn field_count_of(fields : Array[WarcField], name : String) -> Int {
  let mut n = 0
  for i = 0; i < fields.length(); i = i + 1 {
    if fields[i].name.equal_ignore_ascii_case(name) {
      n = n + 1
    }
  }
  n
}

///|
/// The value of the first field with a case-insensitive name match.
fn field_first_of(fields : Array[WarcField], name : String) -> String? {
  for i = 0; i < fields.length(); i = i + 1 {
    if fields[i].name.equal_ignore_ascii_case(name) {
      return Some(fields[i].value)
    }
  }
  None
}
