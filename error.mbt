// Structured error model shared by the parser, validator and builder.
//
// Every error carries the parsing stage, the failure kind, the raw byte
// offset in the input stream (a real stream position, never a made-up
// one), the zero-based record index and a short context string such as
// the name of the field being processed.

///|
/// The processing stage in which an error occurred.
pub enum WarcErrorStage {
  Input
  Version
  Header
  Field
  Number
  ContentLength
  Block
  Separator
  Date
  Uri
  Digest
  Record
  Archive
  Segment
  Limit
  Builder
} derive(Eq, @debug.Debug)

///|
/// The precise failure kind. Parse-time failures and semantic
/// validation failures share this model; advisory findings are reported
/// separately by the audit engine.
pub enum WarcErrorKind {
  UnexpectedEof
  InvalidVersion
  MissingColon
  InvalidFieldName
  InvalidUtf8
  InvalidContentLength
  IntegerOverflow
  ContentLengthMismatch
  MissingRequiredField
  DuplicateField
  InvalidDate
  InvalidUri
  InvalidDigest
  InvalidRecordType
  InvalidSeparator
  TrailingGarbage
  LimitExceeded
} derive(Eq, @debug.Debug)

///|
/// A structured WARC error.
pub struct WarcError {
  stage : WarcErrorStage
  kind : WarcErrorKind
  byte_offset : Int64
  record_index : Int64
  context : String
}

///|
/// Create an error at a byte offset within a specific record.
pub fn WarcError::new(
  stage : WarcErrorStage,
  kind : WarcErrorKind,
  byte_offset : Int64,
  record_index : Int64,
  context : String,
) -> WarcError {
  { stage, kind, byte_offset, record_index, context }
}

///|
/// Every stage code in declaration order. Stable across versions so
/// callers can render error documentation without matching enums.
pub fn all_stage_codes() -> Array[String] {
  [
    "input", "version", "header", "field", "number", "content-length", "block", "separator",
    "date", "uri", "digest", "record", "archive", "segment", "limit", "builder",
  ]
}

///|
/// Every kind code in declaration order. Stable across versions.
pub fn all_kind_codes() -> Array[String] {
  [
    "unexpected-eof", "invalid-version", "missing-colon", "invalid-field-name", "invalid-utf8",
    "invalid-content-length", "integer-overflow", "content-length-mismatch", "missing-required-field",
    "duplicate-field", "invalid-date", "invalid-uri", "invalid-digest", "invalid-record-type",
    "invalid-separator", "trailing-garbage", "limit-exceeded",
  ]
}

///|
/// Resolve a machine-readable stage name back to a stage.
pub fn stage_of_code(code : String) -> WarcErrorStage? {
  match code {
    "input" => Some(Input)
    "version" => Some(Version)
    "header" => Some(Header)
    "field" => Some(Field)
    "number" => Some(Number)
    "content-length" => Some(ContentLength)
    "block" => Some(Block)
    "separator" => Some(Separator)
    "date" => Some(Date)
    "uri" => Some(Uri)
    "digest" => Some(Digest)
    "record" => Some(Record)
    "archive" => Some(Archive)
    "segment" => Some(Segment)
    "limit" => Some(Limit)
    "builder" => Some(Builder)
    _ => None
  }
}

///|
/// Resolve a machine-readable kind name back to a kind.
pub fn kind_of_code(code : String) -> WarcErrorKind? {
  match code {
    "unexpected-eof" => Some(UnexpectedEof)
    "invalid-version" => Some(InvalidVersion)
    "missing-colon" => Some(MissingColon)
    "invalid-field-name" => Some(InvalidFieldName)
    "invalid-utf8" => Some(InvalidUtf8)
    "invalid-content-length" => Some(InvalidContentLength)
    "integer-overflow" => Some(IntegerOverflow)
    "content-length-mismatch" => Some(ContentLengthMismatch)
    "missing-required-field" => Some(MissingRequiredField)
    "duplicate-field" => Some(DuplicateField)
    "invalid-date" => Some(InvalidDate)
    "invalid-uri" => Some(InvalidUri)
    "invalid-digest" => Some(InvalidDigest)
    "invalid-record-type" => Some(InvalidRecordType)
    "invalid-separator" => Some(InvalidSeparator)
    "trailing-garbage" => Some(TrailingGarbage)
    "limit-exceeded" => Some(LimitExceeded)
    _ => None
  }
}

///|
/// The lowercase machine-readable stage name.
pub fn WarcErrorStage::stage_name(self : WarcErrorStage) -> String {
  match self {
    Input => "input"
    Version => "version"
    Header => "header"
    Field => "field"
    Number => "number"
    ContentLength => "content-length"
    Block => "block"
    Separator => "separator"
    Date => "date"
    Uri => "uri"
    Digest => "digest"
    Record => "record"
    Archive => "archive"
    Segment => "segment"
    Limit => "limit"
    Builder => "builder"
  }
}

///|
/// The lowercase machine-readable kind name.
pub fn WarcErrorKind::kind_name(self : WarcErrorKind) -> String {
  match self {
    UnexpectedEof => "unexpected-eof"
    InvalidVersion => "invalid-version"
    MissingColon => "missing-colon"
    InvalidFieldName => "invalid-field-name"
    InvalidUtf8 => "invalid-utf8"
    InvalidContentLength => "invalid-content-length"
    IntegerOverflow => "integer-overflow"
    ContentLengthMismatch => "content-length-mismatch"
    MissingRequiredField => "missing-required-field"
    DuplicateField => "duplicate-field"
    InvalidDate => "invalid-date"
    InvalidUri => "invalid-uri"
    InvalidDigest => "invalid-digest"
    InvalidRecordType => "invalid-record-type"
    InvalidSeparator => "invalid-separator"
    TrailingGarbage => "trailing-garbage"
    LimitExceeded => "limit-exceeded"
  }
}

///|
/// A human-readable one-line description of the error.
pub fn WarcError::to_string(self : WarcError) -> String {
  "[\{self.stage.stage_name()}] \{self.kind.kind_name()} at byte \{self.byte_offset} (record \{self.record_index}): \{self.context}"
}
