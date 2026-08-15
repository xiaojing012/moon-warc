// Archive audit engine.
//
// Where the validator reports hard specification violations, the
// audit engine reports advisory findings: conditions that are legal
// WARC but usually indicate a capturing, indexing or curation
// problem. Findings never fail a parse; they inform a human or a
// downstream policy.

///|
/// The severity of an audit finding.
pub enum FindingSeverity {
  Info
  Warning
} derive(Eq, @debug.Debug)

///|
/// Every severity code in declaration order.
pub fn all_severity_codes() -> Array[String] {
  ["info", "warning"]
}

///|
/// Resolve a severity code back to a severity.
pub fn severity_of_code(code : String) -> FindingSeverity? {
  match code {
    "info" => Some(Info)
    "warning" => Some(Warning)
    _ => None
  }
}

///|
/// The lowercase machine-readable severity name.
pub fn FindingSeverity::severity_name(self : FindingSeverity) -> String {
  match self {
    Info => "info"
    Warning => "warning"
  }
}

///|
/// An advisory audit finding anchored to a record.
pub struct WarcFinding {
  severity : FindingSeverity
  code : String
  record_index : Int64
  context : String
}

///|
/// Construct a finding.
pub fn WarcFinding::new(
  severity : FindingSeverity,
  code : String,
  record_index : Int64,
  context : String,
) -> WarcFinding {
  { severity, code, record_index, context }
}

///|
/// The finding's severity.
pub fn WarcFinding::severity(self : WarcFinding) -> FindingSeverity {
  self.severity
}

///|
/// The machine-readable finding code.
pub fn WarcFinding::code(self : WarcFinding) -> String {
  self.code
}

///|
/// The record the finding is anchored to.
pub fn WarcFinding::record_index(self : WarcFinding) -> Int64 {
  self.record_index
}

///|
/// A human-readable description of the finding.
pub fn WarcFinding::context(self : WarcFinding) -> String {
  self.context
}

///|
/// A one-line rendering of the finding.
pub fn WarcFinding::to_string(self : WarcFinding) -> String {
  "[\{self.severity.severity_name()}] \{self.code} (record \{self.record_index}): \{self.context}"
}

///|
/// Run the audit over a whole archive and return every finding in
/// file order.
pub fn audit_archive(a : WarcArchive) -> Array[WarcFinding] {
  let findings : Array[WarcFinding] = []
  let n = a.record_count()
  // Collect record ids first so dangling references can be checked.
  let ids : Array[String] = []
  for i = 0; i < n; i = i + 1 {
    let id = field_first_of(a.record(i).unwrap().fields, "WARC-Record-ID")
    match id {
      Some(v) =>
        match parse_uri_ref(v, i.to_int64()) {
          Ok(interior) => ids.push(interior)
          Err(_) => ()
        }
      None => ()
    }
  }
  for i = 0; i < n; i = i + 1 {
    let rec = a.record(i).unwrap()
    audit_record(rec, i, ids, findings)
  }
  findings
}

///|
/// Audit one record, appending findings to `out`.
fn audit_record(
  rec : WarcRecord,
  index : Int,
  ids : Array[String],
  out : Array[WarcFinding],
) -> Unit {
  // Unknown WARC-Type: readers must skip the record per clause 5.5,
  // so a capture that produced one is worth a warning.
  let type_value = field_first_of(rec.fields, "WARC-Type")
  match type_value {
    Some(t) =>
      match rec.record_type() {
        None =>
          out.push(
            WarcFinding::new(
              Warning,
              "unknown-record-type",
              index.to_int64(),
              "unknown WARC-Type value \{t}; readers must skip this record",
            ),
          )
        Some(_) => ()
      }
    None => ()
  }
  // Empty blocks on payload-bearing records usually indicate a
  // failed capture.
  if rec.block_length() == 0 {
    match rec.record_type() {
      Some(t) =>
        if t == Response || t == Resource || t == Conversion {
          out.push(
            WarcFinding::new(
              Info,
              "empty-block",
              index.to_int64(),
              "record type \{t.type_name()} carries an empty content block",
            ),
          )
        }
      None => ()
    }
  }
  // Digests are the standard integrity check; their absence is
  // advisory.
  if field_first_of(rec.fields, "WARC-Block-Digest") is None {
    out.push(
      WarcFinding::new(
        Info,
        "missing-block-digest",
        index.to_int64(),
        "record has no WARC-Block-Digest",
      ),
    )
  }
  // Clause 5.6 recommends Content-Type on non-empty blocks.
  if rec.block_length() > 0 &&
    field_first_of(rec.fields, "Content-Type") is None {
    out.push(
      WarcFinding::new(
        Info,
        "missing-content-type",
        index.to_int64(),
        "non-empty block has no Content-Type (recommended by clause 5.6)",
      ),
    )
  }
  // A WARC-Refers-To that matches no record id in the archive points
  // outside it, which is often a curation mistake.
  let refers = field_first_of(rec.fields, "WARC-Refers-To")
  match refers {
    Some(v) =>
      match parse_uri_ref(v, index.to_int64()) {
        Ok(interior) =>
          if !contains_string(ids, interior) {
            out.push(
              WarcFinding::new(
                Warning,
                "dangling-refers-to",
                index.to_int64(),
                "WARC-Refers-To \{interior} matches no WARC-Record-ID in this archive",
              ),
            )
          }
        Err(_) => ()
      }
    None => ()
  }
}
