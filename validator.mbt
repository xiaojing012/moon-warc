// Semantic record validation (ISO 28500:2017 clause 5).
//
// `validate_record` checks the field placement rules of the
// specification: which named fields may appear on which record types,
// the value domains of WARC-Truncated and WARC-IP-Address, the
// labelled-digest syntax of WARC-Payload-Digest / WARC-Block-Digest
// and the URI/date syntax of the WARC-Refers-To family. Structural
// rules (framing, mandatory fields, Content-Length) are already
// enforced by the parser, so they are not repeated here. Records of
// unknown WARC-Type are tolerated per clause 5.5: placement checks
// are skipped for them, value-domain checks still apply.

///|
/// Validate one record and return every semantic violation found, in
/// discovery order.
pub fn validate_record(rec : WarcRecord, index : Int64) -> Array[WarcError] {
  let errs : Array[WarcError] = []
  // Repeated fields: every named field shall appear at most once,
  // except WARC-Concurrent-To (clause 5.7).
  push_all(errs, duplicate_errors(rec.fields, index))
  // WARC-Type is mandatory; unknown types skip placement checks.
  match field_first_of(rec.fields, "WARC-Type") {
    None =>
      errs.push(
        val_err(
          index,
          WarcErrorKind::MissingRequiredField,
          "missing mandatory field WARC-Type",
        ),
      )
    Some(_) =>
      match rec.record_type() {
        None => ()
        Some(_) => push_all(errs, placement_errors(rec, index))
      }
  }
  // Value-domain checks apply on every record type, known or unknown.
  push_all(errs, value_domain_errors(rec, index))
  // Segmentation field syntax (clause 7).
  push_all(errs, segment_errors(rec, index))
  errs
}

///|
/// A semantic validation error anchored to a record.
fn val_err(index : Int64, kind : WarcErrorKind, context : String) -> WarcError {
  WarcError::new(WarcErrorStage::Record, kind, 0L, index, context)
}

///|
/// Append every element of `src` to `dst`.
fn push_all(dst : Array[WarcError], src : Array[WarcError]) -> Unit {
  for i = 0; i < src.length(); i = i + 1 {
    dst.push(src[i])
  }
}

///|
/// True when the record carries the named field.
fn has_field(rec : WarcRecord, name : String) -> Bool {
  field_first_of(rec.fields, name) is Some(_)
}

///|
/// Report a field that must not appear on records of this type.
fn misplaced(errs : Array[WarcError], index : Int64, name : String) -> Unit {
  errs.push(
    val_err(
      index,
      WarcErrorKind::MisplacedField,
      "field \{name} must not appear on this record type",
    ),
  )
}

///|
/// Repeated-field violations in discovery order.
fn duplicate_errors(
  fields : Array[WarcField],
  index : Int64,
) -> Array[WarcError] {
  let errs : Array[WarcError] = []
  for i = 0; i < fields.length(); i = i + 1 {
    if fields[i].name.equal_ignore_ascii_case("WARC-Concurrent-To") {
      continue
    }
    for j = 0; j < i; j = j + 1 {
      if fields[j].name.equal_ignore_ascii_case(fields[i].name) {
        errs.push(
          val_err(
            index,
            WarcErrorKind::DuplicateField,
            "field \{fields[i].name} must not be repeated",
          ),
        )
        break
      }
    }
  }
  errs
}

///|
/// Field placement rules for the eight standard record types
/// (clauses 5.6, 5.7, 5.10, 5.11-5.14, 5.16-5.19, 6.6).
fn placement_errors(rec : WarcRecord, index : Int64) -> Array[WarcError] {
  let errs : Array[WarcError] = []
  let rtype = rec.record_type().unwrap()
  let type_name = rtype.type_name()
  // WARC-Concurrent-To: forbidden on warcinfo/conversion/continuation.
  let no_concurrent = rtype == Warcinfo ||
    rtype == Conversion ||
    rtype == Continuation
  if no_concurrent && has_field(rec, "WARC-Concurrent-To") {
    misplaced(errs, index, "WARC-Concurrent-To")
  }
  // WARC-IP-Address: forbidden on warcinfo/conversion/continuation.
  let no_ip = rtype == Warcinfo || rtype == Conversion || rtype == Continuation
  if no_ip && has_field(rec, "WARC-IP-Address") {
    misplaced(errs, index, "WARC-IP-Address")
  }
  // WARC-Target-URI: forbidden on warcinfo, required on the other
  // target-bearing types (metadata has no target).
  if rtype == Warcinfo {
    if has_field(rec, "WARC-Target-URI") {
      misplaced(errs, index, "WARC-Target-URI")
    }
  } else if rtype != Metadata && !has_field(rec, "WARC-Target-URI") {
    errs.push(
      val_err(
        index,
        WarcErrorKind::MissingRequiredField,
        "record type \{type_name} requires WARC-Target-URI",
      ),
    )
  }
  // WARC-Warcinfo-ID: forbidden on warcinfo (it identifies the file,
  // so only other records may point back at it).
  if rtype == Warcinfo && has_field(rec, "WARC-Warcinfo-ID") {
    misplaced(errs, index, "WARC-Warcinfo-ID")
  }
  // WARC-Filename: warcinfo only.
  if rtype != Warcinfo && has_field(rec, "WARC-Filename") {
    misplaced(errs, index, "WARC-Filename")
  }
  // WARC-Profile: mandatory on revisit, forbidden elsewhere.
  if rtype == Revisit {
    if !has_field(rec, "WARC-Profile") {
      errs.push(
        val_err(
          index,
          WarcErrorKind::MissingRequiredField,
          "revisit records require WARC-Profile",
        ),
      )
    }
  } else if has_field(rec, "WARC-Profile") {
    misplaced(errs, index, "WARC-Profile")
  }
  // WARC-Refers-To family: revisit only.
  if rtype != Revisit {
    if has_field(rec, "WARC-Refers-To") {
      misplaced(errs, index, "WARC-Refers-To")
    }
    if has_field(rec, "WARC-Refers-To-Target-URI") {
      misplaced(errs, index, "WARC-Refers-To-Target-URI")
    }
    if has_field(rec, "WARC-Refers-To-Date") {
      misplaced(errs, index, "WARC-Refers-To-Date")
    }
  }
  // WARC-Identified-Payload-Type: payload-bearing types only.
  let payload_type = rtype == Response ||
    rtype == Resource ||
    rtype == Conversion
  if !payload_type && has_field(rec, "WARC-Identified-Payload-Type") {
    misplaced(errs, index, "WARC-Identified-Payload-Type")
  }
  errs
}

///|
/// Value-domain checks that apply on every record type.
fn value_domain_errors(rec : WarcRecord, index : Int64) -> Array[WarcError] {
  let errs : Array[WarcError] = []
  // WARC-Truncated: one of the four reason tokens (clause 5.15).
  let trunc = field_first_of(rec.fields, "WARC-Truncated")
  match trunc {
    Some(v) =>
      if v != "length" && v != "time" && v != "disconnect" && v != "unspecified" {
        errs.push(
          val_err(
            index,
            WarcErrorKind::InvalidFieldValue,
            "WARC-Truncated value must be one of length, time, disconnect, unspecified",
          ),
        )
      }
    None => ()
  }
  for i = 0; i < rec.fields.length(); i = i + 1 {
    let name = rec.fields[i].name
    // WARC-IP-Address: a strict dotted-quad IPv4 or a permissive IPv6.
    if name.equal_ignore_ascii_case("WARC-IP-Address") {
      if !valid_ip_address(rec.fields[i].value) {
        errs.push(
          val_err(
            index,
            WarcErrorKind::InvalidIpAddress,
            "WARC-IP-Address value is not a valid IPv4 or IPv6 address",
          ),
        )
      }
      continue
    }
    // WARC-Payload-Digest / WARC-Block-Digest: labelled digest syntax.
    if name.equal_ignore_ascii_case("WARC-Payload-Digest") ||
      name.equal_ignore_ascii_case("WARC-Block-Digest") {
      let parsed = parse_digest(rec.fields[i].value, index)
      match parsed {
        Err(e) => errs.push(e)
        Ok(_) => ()
      }
      continue
    }
    // WARC-Refers-To / WARC-Refers-To-Target-URI: <uri> form.
    if name.equal_ignore_ascii_case("WARC-Refers-To") ||
      name.equal_ignore_ascii_case("WARC-Refers-To-Target-URI") {
      let parsed = parse_uri_ref(rec.fields[i].value, index)
      match parsed {
        Err(e) => errs.push(e)
        Ok(_) => ()
      }
      continue
    }
    // WARC-Refers-To-Date: W3CDTF UTC timestamp.
    if name.equal_ignore_ascii_case("WARC-Refers-To-Date") {
      let parsed = parse_warc_date(rec.fields[i].value, index)
      match parsed {
        Err(e) => errs.push(e)
        Ok(_) => ()
      }
      continue
    }
  }
  errs
}

///|
/// Validate a whole archive: per-record semantic validation, unique
/// WARC-Record-IDs, and segment-sequence consistency. Errors are
/// reported in file order.
pub fn validate_archive(a : WarcArchive) -> Array[WarcError] {
  let errs : Array[WarcError] = []
  let n = a.record_count()
  for i = 0; i < n; i = i + 1 {
    push_all(errs, validate_record(a.record(i).unwrap(), i.to_int64()))
  }
  push_all(errs, duplicate_id_errors(a))
  push_all(errs, segment_group_errors(a))
  errs
}

///|
/// Duplicate WARC-Record-ID violations: each later occurrence is
/// reported once.
fn duplicate_id_errors(a : WarcArchive) -> Array[WarcError] {
  let errs : Array[WarcError] = []
  let n = a.record_count()
  for i = 0; i < n; i = i + 1 {
    let id = field_first_of(a.record(i).unwrap().fields, "WARC-Record-ID")
    match id {
      None => continue
      Some(v) =>
        for j = 0; j < i; j = j + 1 {
          let prev = field_first_of(
            a.record(j).unwrap().fields,
            "WARC-Record-ID",
          )
          match prev {
            Some(p) =>
              if p == v {
                errs.push(
                  val_err(
                    i.to_int64(),
                    WarcErrorKind::DuplicateField,
                    "duplicate WARC-Record-ID \{v}",
                  ),
                )
                break
              }
            None => ()
          }
        }
    }
  }
  errs
}

///|
/// Segment-sequence consistency checks over the whole archive: records
/// sharing a WARC-Segment-Origin-ID must be contiguous, their
/// WARC-Segment-Number values must run 1, 2, 3, ... and a
/// WARC-Segment-Total-Length may only sit on the final record of its
/// sequence.
fn segment_group_errors(a : WarcArchive) -> Array[WarcError] {
  let errs : Array[WarcError] = []
  let n = a.record_count()
  let origins : Array[String] = []
  let first_idx : Array[Int] = []
  let last_idx : Array[Int] = []
  let counts : Array[Int] = []
  let expected_next : Array[Int64] = []
  let total_at : Array[Int] = []
  for i = 0; i < n; i = i + 1 {
    let rec = a.record(i).unwrap()
    let origin = field_first_of(rec.fields, "WARC-Segment-Origin-ID")
    match origin {
      None => continue
      Some(oid) => {
        let mut g = -1
        for k = 0; k < origins.length(); k = k + 1 {
          if origins[k] == oid {
            g = k
            break
          }
        }
        let seg = rec.segment_info(i.to_int64())
        let number = match seg {
          Ok(x) => x.number()
          Err(_) => None
        }
        let total_len = match seg {
          Ok(x) => x.total_length()
          Err(_) => None
        }
        if g == -1 {
          origins.push(oid)
          first_idx.push(i)
          last_idx.push(i)
          counts.push(1)
          expected_next.push(1)
          total_at.push(-1)
          g = origins.length() - 1
        } else {
          last_idx[g] = i
          counts[g] = counts[g] + 1
        }
        match number {
          Some(num) => {
            if num != expected_next[g] {
              errs.push(
                seg_err(
                  i.to_int64(),
                  WarcErrorKind::InvalidFieldValue,
                  "WARC-Segment-Number \{num} does not continue sequence \{oid} (expected \{expected_next[g]})",
                ),
              )
            }
            expected_next[g] = num + 1
          }
          None => ()
        }
        match total_len {
          Some(_) => {
            if total_at[g] != -1 {
              errs.push(
                seg_err(
                  i.to_int64(),
                  WarcErrorKind::InvalidFieldValue,
                  "WARC-Segment-Total-Length appears on more than one record of sequence \{oid}",
                ),
              )
            }
            total_at[g] = i
          }
          None => ()
        }
      }
    }
  }
  for g = 0; g < origins.length(); g = g + 1 {
    if counts[g] != last_idx[g] - first_idx[g] + 1 {
      errs.push(
        seg_err(
          last_idx[g].to_int64(),
          WarcErrorKind::InvalidFieldValue,
          "records of segment sequence \{origins[g]} are not contiguous",
        ),
      )
    }
    if total_at[g] != -1 && total_at[g] != last_idx[g] {
      errs.push(
        seg_err(
          total_at[g].to_int64(),
          WarcErrorKind::InvalidFieldValue,
          "WARC-Segment-Total-Length appears before the final record of sequence \{origins[g]}",
        ),
      )
    }
  }
  errs
}

///|
/// Validate an IP address value: a strict dotted-quad IPv4 or a
/// permissive IPv6 form. Anything else is invalid.
pub fn valid_ip_address(s : String) -> Bool {
  let data = @utf8.encode(s)
  if data.length() == 0 {
    return false
  }
  let mut has_colon = false
  let mut has_dot = false
  for i = 0; i < data.length(); i = i + 1 {
    if data[i] == b':' {
      has_colon = true
    }
    if data[i] == b'.' {
      has_dot = true
    }
  }
  if has_colon && !has_dot {
    return valid_ipv6(data)
  }
  if has_dot && !has_colon {
    return valid_ipv4(data)
  }
  false
}

///|
/// True when the byte is an ASCII hex digit.
fn is_hex(b : Byte) -> Bool {
  if is_digit(b) {
    return true
  }
  if b >= b'a' && b <= b'f' {
    return true
  }
  b >= b'A' && b <= b'F'
}

///|
/// Strict dotted-quad IPv4: four decimal octets 0-255, no empty
/// octets, no leading zeros, digits only.
fn valid_ipv4(data : Bytes) -> Bool {
  let len = data.length()
  let mut parts = 0
  let mut i = 0
  while i < len {
    let start = i
    while i < len && data[i] != b'.' {
      i = i + 1
    }
    let n = i - start
    if n == 0 || n > 3 {
      return false
    }
    if n > 1 && data[start] == b'0' {
      return false
    }
    let mut v = 0
    for j = start; j < i; j = j + 1 {
      if !is_digit(data[j]) {
        return false
      }
      v = v * 10 + (data[j].to_int() - 48)
    }
    if v > 255 {
      return false
    }
    parts = parts + 1
    if i < len {
      i = i + 1
      if i >= len {
        return false
      }
    }
  }
  parts == 4
}

///|
/// Permissive IPv6: hex digits and colons only, with at least one
/// colon and at least one hex digit. Group counts and `::` placement
/// are not enforced.
fn valid_ipv6(data : Bytes) -> Bool {
  let mut colons = 0
  let mut hexes = 0
  for i = 0; i < data.length(); i = i + 1 {
    let b = data[i]
    if b == b':' {
      colons = colons + 1
    } else {
      if !is_hex(b) {
        return false
      }
      hexes = hexes + 1
    }
  }
  colons >= 1 && hexes >= 1
}
