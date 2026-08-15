// Archive indexing and querying.
//
// The index is a set of parallel (key, record-index) pairs kept in
// file order, so lookups are linear scans — appropriate for a
// library whose archives are held in memory. Keys come only from
// record metadata: field values are compared as strings and are
// never interpreted as file-system paths.

///|
/// An in-memory index over an archive's records.
pub struct WarcIndex {
  by_id : Array[(String, Int)]
  by_target : Array[(String, Int)]
  by_type : Array[(String, Int)]
}

///|
/// Build an index over an archive. Records whose keys are absent or
/// malformed are simply not indexed.
pub fn WarcIndex::build(a : WarcArchive) -> WarcIndex {
  let by_id : Array[(String, Int)] = []
  let by_target : Array[(String, Int)] = []
  let by_type : Array[(String, Int)] = []
  for i = 0; i < a.record_count(); i = i + 1 {
    let rec = a.record(i).unwrap()
    let id = field_first_of(rec.fields, "WARC-Record-ID")
    match id {
      Some(v) =>
        match parse_uri_ref(v, i.to_int64()) {
          Ok(interior) => by_id.push((interior, i))
          Err(_) => ()
        }
      None => ()
    }
    let target = field_first_of(rec.fields, "WARC-Target-URI")
    match target {
      Some(v) =>
        match parse_uri_ref(v, i.to_int64()) {
          Ok(interior) => by_target.push((interior, i))
          Err(_) => ()
        }
      None => ()
    }
    let t = rec.record_type()
    match t {
      Some(x) => by_type.push((x.type_name(), i))
      None => ()
    }
  }
  { by_id, by_target, by_type }
}

///|
/// The index of the first record whose WARC-Record-ID interior is
/// `id`, or `None` when no record carries it.
pub fn WarcIndex::by_record_id(self : WarcIndex, id : String) -> Int? {
  for i = 0; i < self.by_id.length(); i = i + 1 {
    let (k, ix) = self.by_id[i]
    if k == id {
      return Some(ix)
    }
  }
  None
}

///|
/// The indices of all records whose WARC-Target-URI interior is
/// `uri`, in file order.
pub fn WarcIndex::by_target_uri(self : WarcIndex, uri : String) -> Array[Int] {
  let out : Array[Int] = []
  for i = 0; i < self.by_target.length(); i = i + 1 {
    let (k, ix) = self.by_target[i]
    if k == uri {
      out.push(ix)
    }
  }
  out
}

///|
/// The indices of all records of the given type, in file order.
pub fn WarcIndex::by_type(self : WarcIndex, t : WarcRecordType) -> Array[Int] {
  let out : Array[Int] = []
  let name = t.type_name()
  for i = 0; i < self.by_type.length(); i = i + 1 {
    let (k, ix) = self.by_type[i]
    if k == name {
      out.push(ix)
    }
  }
  out
}

///|
/// The total number of indexed keys across all three key kinds.
pub fn WarcIndex::size(self : WarcIndex) -> Int {
  self.by_id.length() + self.by_target.length() + self.by_type.length()
}
