// Configurable resource limits for WARC parsing.
//
// All limits are hard bounds: exceeding one yields a structured
// `LimitExceeded` error instead of silent truncation. Defaults follow
// the ISO 28500 Annex C recommendation of ~1 GB WARC files while keeping
// in-memory parsing bounded; `strict` is for adversarial input and
// embedded targets; `permissive` removes practical ceilings for
// controlled batch processing of large archives.

///|
pub struct Limits {
  max_archive_bytes : Int64
  max_record_bytes : Int64
  max_header_bytes : Int64
  max_header_count : Int
  max_field_name_bytes : Int
  max_field_value_bytes : Int
  max_block_bytes : Int64
  max_records : Int
  max_content_length_digits : Int
}

///|
/// Balanced defaults for general-purpose archive processing.
pub fn Limits::default() -> Limits {
  {
    max_archive_bytes: 1_000_000_000L,
    max_record_bytes: 536_870_912L,
    max_header_bytes: 1_048_576L,
    max_header_count: 1000,
    max_field_name_bytes: 256,
    max_field_value_bytes: 65536,
    max_block_bytes: 536_870_912L,
    max_records: 1_000_000,
    max_content_length_digits: 19,
  }
}

///|
/// Tight bounds for untrusted input and memory-constrained targets.
pub fn Limits::strict() -> Limits {
  {
    max_archive_bytes: 16_777_216L,
    max_record_bytes: 4_194_304L,
    max_header_bytes: 65_536L,
    max_header_count: 100,
    max_field_name_bytes: 64,
    max_field_value_bytes: 8192,
    max_block_bytes: 4_194_304L,
    max_records: 10_000,
    max_content_length_digits: 10,
  }
}

///|
/// Near-unbounded ceilings for controlled offline processing.
pub fn Limits::permissive() -> Limits {
  {
    max_archive_bytes: 9_223_372_036_854_775_807L,
    max_record_bytes: 9_223_372_036_854_775_807L,
    max_header_bytes: 9_223_372_036_854_775_807L,
    max_header_count: 1_000_000,
    max_field_name_bytes: 1_048_576,
    max_field_value_bytes: 16_777_216,
    max_block_bytes: 9_223_372_036_854_775_807L,
    max_records: 100_000_000,
    max_content_length_digits: 19,
  }
}

///|
/// A copy of these limits with `max_archive_bytes` replaced.
pub fn Limits::with_max_archive_bytes(self : Limits, n : Int64) -> Limits {
  { ..self, max_archive_bytes: n }
}

///|
/// A copy of these limits with `max_record_bytes` replaced.
pub fn Limits::with_max_record_bytes(self : Limits, n : Int64) -> Limits {
  { ..self, max_record_bytes: n }
}

///|
/// A copy of these limits with `max_header_bytes` replaced.
pub fn Limits::with_max_header_bytes(self : Limits, n : Int64) -> Limits {
  { ..self, max_header_bytes: n }
}

///|
/// A copy of these limits with `max_header_count` replaced.
pub fn Limits::with_max_header_count(self : Limits, n : Int) -> Limits {
  { ..self, max_header_count: n }
}

///|
/// A copy of these limits with `max_field_name_bytes` replaced.
pub fn Limits::with_max_field_name_bytes(self : Limits, n : Int) -> Limits {
  { ..self, max_field_name_bytes: n }
}

///|
/// A copy of these limits with `max_field_value_bytes` replaced.
pub fn Limits::with_max_field_value_bytes(self : Limits, n : Int) -> Limits {
  { ..self, max_field_value_bytes: n }
}

///|
/// A copy of these limits with `max_block_bytes` replaced.
pub fn Limits::with_max_block_bytes(self : Limits, n : Int64) -> Limits {
  { ..self, max_block_bytes: n }
}

///|
/// A copy of these limits with `max_records` replaced.
pub fn Limits::with_max_records(self : Limits, n : Int) -> Limits {
  { ..self, max_records: n }
}

///|
/// A copy of these limits with `max_content_length_digits` replaced.
pub fn Limits::with_max_content_length_digits(self : Limits, n : Int) -> Limits {
  { ..self, max_content_length_digits: n }
}
