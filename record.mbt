// Record types and mandatory field helpers (ISO 28500:2017 clauses
// 5.2, 5.4, 5.5, 6).
//
// The eight standard record types are modelled as an enum so callers
// can match on them; parsing is case-insensitive per the field-value
// conventions of the specification, and unknown types map to `None`
// (readers must skip records of unknown type rather than fail).

///|
/// The eight standard WARC record types of clause 6.
pub enum WarcRecordType {
  Warcinfo
  Response
  Resource
  Request
  Metadata
  Revisit
  Conversion
  Continuation
} derive(Eq, @debug.Debug)

///|
/// Every record type code in declaration order (lowercase, as written
/// in the specification).
pub fn all_record_type_codes() -> Array[String] {
  [
    "warcinfo", "response", "resource", "request", "metadata", "revisit", "conversion",
    "continuation",
  ]
}

///|
/// Resolve a lowercase type code back to a record type.
pub fn record_type_of_code(code : String) -> WarcRecordType? {
  match code {
    "warcinfo" => Some(Warcinfo)
    "response" => Some(Response)
    "resource" => Some(Resource)
    "request" => Some(Request)
    "metadata" => Some(Metadata)
    "revisit" => Some(Revisit)
    "conversion" => Some(Conversion)
    "continuation" => Some(Continuation)
    _ => None
  }
}

///|
/// Parse a WARC-Type field value case-insensitively; unknown types
/// yield `None`.
pub fn WarcRecordType::parse(s : String) -> WarcRecordType? {
  record_type_of_code(s.to_lower())
}

///|
/// The canonical lowercase spelling of the type.
pub fn WarcRecordType::type_name(self : WarcRecordType) -> String {
  match self {
    Warcinfo => "warcinfo"
    Response => "response"
    Resource => "resource"
    Request => "request"
    Metadata => "metadata"
    Revisit => "revisit"
    Conversion => "conversion"
    Continuation => "continuation"
  }
}

///|
/// The record type declared by WARC-Type, or `None` when the field is
/// absent or carries an unknown type.
pub fn WarcRecord::record_type(self : WarcRecord) -> WarcRecordType? {
  let v = self.field_first("WARC-Type")
  match v {
    Some(t) => WarcRecordType::parse(t)
    None => None
  }
}

///|
/// The value of a mandatory field, or a structured error naming it.
pub fn WarcRecord::require_field(
  self : WarcRecord,
  name : String,
  record_index : Int64,
) -> Result[String, WarcError] {
  let v = self.field_first(name)
  match v {
    Some(x) => Ok(x)
    None =>
      Err(
        WarcError::new(
          WarcErrorStage::Record,
          WarcErrorKind::MissingRequiredField,
          0L,
          record_index,
          "missing mandatory field \{name}",
        ),
      )
  }
}

///|
/// The WARC-Record-ID of the record: the mandatory field, parsed as a
/// `<uri>` reference. Returns the URI inside the angle brackets.
pub fn WarcRecord::record_id(
  self : WarcRecord,
  record_index : Int64,
) -> Result[String, WarcError] {
  let v = self.require_field("WARC-Record-ID", record_index)
  let value = match v {
    Ok(x) => x
    Err(e) => return Err(e)
  }
  parse_uri_ref(value, record_index)
}

///|
/// The WARC-Date of the record, parsed to a structured date.
pub fn WarcRecord::warc_date(
  self : WarcRecord,
  record_index : Int64,
) -> Result[WarcDate, WarcError] {
  let v = self.require_field("WARC-Date", record_index)
  let value = match v {
    Ok(x) => x
    Err(e) => return Err(e)
  }
  parse_warc_date(value, record_index)
}

///|
/// The WARC-Target-URI of the record, parsed as a `<uri>` reference.
/// Callers decide whether the record type requires the field; this
/// helper parses it whenever it is present.
pub fn WarcRecord::target_uri(
  self : WarcRecord,
  record_index : Int64,
) -> Result[String, WarcError] {
  let v = self.require_field("WARC-Target-URI", record_index)
  let value = match v {
    Ok(x) => x
    Err(e) => return Err(e)
  }
  parse_uri_ref(value, record_index)
}

///|
/// The raw Content-Length field value, when present.
pub fn WarcRecord::declared_content_length(self : WarcRecord) -> String? {
  self.field_first("Content-Length")
}
