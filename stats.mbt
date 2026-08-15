// Aggregate archive statistics.
//
// `archive_stats` walks an in-memory archive once and collects
// counts, byte totals, the type histogram, the set of distinct
// target URIs and the earliest/latest WARC-Date. Dates are compared
// by their present fields only, so a coarser date sorts before a
// finer one that begins the same way.

///|
/// Aggregate statistics over an archive.
pub struct ArchiveStats {
  record_count : Int
  total_record_bytes : Int64
  total_block_bytes : Int64
  type_counts : Array[(String, Int)]
  distinct_targets : Array[String]
  earliest : WarcDate?
  latest : WarcDate?
}

///|
/// Compute aggregate statistics over an archive.
pub fn archive_stats(a : WarcArchive) -> ArchiveStats {
  let type_counts : Array[(String, Int)] = []
  let distinct_targets : Array[String] = []
  let mut total_record = 0L
  let mut total_block = 0L
  let mut earliest : WarcDate? = None
  let mut latest : WarcDate? = None
  for i = 0; i < a.record_count(); i = i + 1 {
    let rec = a.record(i).unwrap()
    total_record = total_record + rec.to_bytes().length().to_int64()
    total_block = total_block + rec.block_length().to_int64()
    let t = match rec.record_type() {
      Some(x) => x.type_name()
      None => "unknown"
    }
    bump_count(type_counts, t)
    let target = field_first_of(rec.fields, "WARC-Target-URI")
    match target {
      Some(v) =>
        match parse_uri_ref(v, i.to_int64()) {
          Ok(interior) =>
            if !contains_string(distinct_targets, interior) {
              distinct_targets.push(interior)
            }
          Err(_) => ()
        }
      None => ()
    }
    match rec.warc_date(i.to_int64()) {
      Ok(d) => {
        let key = date_sort_key(d)
        match earliest {
          Some(e) => if key < date_sort_key(e) { earliest = Some(d) }
          None => earliest = Some(d)
        }
        match latest {
          Some(l) => if key > date_sort_key(l) { latest = Some(d) }
          None => latest = Some(d)
        }
      }
      Err(_) => ()
    }
  }
  {
    record_count: a.record_count(),
    total_record_bytes: total_record,
    total_block_bytes: total_block,
    type_counts,
    distinct_targets,
    earliest,
    latest,
  }
}

///|
/// The number of records in the archive.
pub fn ArchiveStats::record_count(self : ArchiveStats) -> Int {
  self.record_count
}

///|
/// The total serialized size of all records in octets.
pub fn ArchiveStats::total_record_bytes(self : ArchiveStats) -> Int64 {
  self.total_record_bytes
}

///|
/// The total size of all content blocks in octets.
pub fn ArchiveStats::total_block_bytes(self : ArchiveStats) -> Int64 {
  self.total_block_bytes
}

///|
/// The number of records of the given type name (lowercase); records
/// of unknown WARC-Type count as `unknown`.
pub fn ArchiveStats::type_count(self : ArchiveStats, name : String) -> Int {
  for i = 0; i < self.type_counts.length(); i = i + 1 {
    let (k, c) = self.type_counts[i]
    if k == name {
      return c
    }
  }
  0
}

///|
/// The number of distinct WARC-Target-URI values.
pub fn ArchiveStats::distinct_target_count(self : ArchiveStats) -> Int {
  self.distinct_targets.length()
}

///|
/// The earliest WARC-Date seen, when any record carried a parseable
/// one.
pub fn ArchiveStats::earliest_date(self : ArchiveStats) -> WarcDate? {
  self.earliest
}

///|
/// The latest WARC-Date seen, when any record carried a parseable
/// one.
pub fn ArchiveStats::latest_date(self : ArchiveStats) -> WarcDate? {
  self.latest
}

///|
/// Increment the count for a key in an ordered (key, count) list.
fn bump_count(counts : Array[(String, Int)], name : String) -> Unit {
  for i = 0; i < counts.length(); i = i + 1 {
    let (k, c) = counts[i]
    if k == name {
      counts[i] = (k, c + 1)
      return
    }
  }
  counts.push((name, 1))
}

///|
/// True when the string list contains the value.
fn contains_string(xs : Array[String], x : String) -> Bool {
  for i = 0; i < xs.length(); i = i + 1 {
    if xs[i] == x {
      return true
    }
  }
  false
}

///|
/// The value of an optional field, or a fallback when absent.
fn opt_or(v : Int?, fallback : Int) -> Int {
  match v {
    Some(x) => x
    None => fallback
  }
}

///|
/// A sort key over the present fields of a date, most significant
/// first. Fields absent at coarser granularities count as zero.
fn date_sort_key(d : WarcDate) -> Int64 {
  d.year.to_int64() * 10000000000L +
  opt_or(d.month, 0).to_int64() * 100000000L +
  opt_or(d.day, 0).to_int64() * 1000000L +
  opt_or(d.hour, 0).to_int64() * 10000L +
  opt_or(d.minute, 0).to_int64() * 100L +
  opt_or(d.second, 0).to_int64()
}
