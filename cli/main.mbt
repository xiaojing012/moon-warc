// warc-tool: a command-line entry point for the moon-warc library.
//
// This build has no file-system I/O (see docs/limitations.md in the
// library), so every command operates on a built-in demo archive;
// `query` additionally takes a target URI from the command line.

///|
/// The version reported by `version`.
const VERSION : String = "0.1.0-dev"

///|
/// Dispatch on argv[1].
fn main {
  let argv = @env.args()
  if argv.length() < 2 {
    println("usage: warc-tool <command> [args]")
    println(
      "commands: version help demo parse validate inspect stats query build audit",
    )
    return
  }
  match argv[1] {
    "version" => println("warc-tool \{VERSION}")
    "help" => print_help()
    "demo" => print_demo_archive()
    "parse" => cmd_parse()
    "validate" => cmd_validate()
    "inspect" => cmd_inspect()
    "stats" => cmd_stats()
    "query" =>
      if argv.length() < 3 {
        println("usage: warc-tool query <target-uri>")
      } else {
        cmd_query(argv[2])
      }
    "build" => cmd_build()
    "audit" => cmd_audit()
    _ => {
      println("unknown command: \{argv[1]}")
      print_help()
    }
  }
}

///|
/// Print the command summary.
fn print_help() -> Unit {
  println("warc-tool \{VERSION} — MoonBit WARC 1.1 tooling")
  println("commands:")
  println("  version             print the version")
  println("  help                print this help")
  println("  demo                print the built-in demo archive")
  println(
    "  parse               parse the demo archive and report record counts",
  )
  println("  validate            validate the demo archive (and a broken one)")
  println("  inspect             list every record of the demo archive")
  println("  stats               print aggregate statistics")
  println("  query <target-uri>  list record indices matching a target URI")
  println("  build               build and serialize one record")
  println("  audit               run the audit engine")
}

///|
/// Print the demo archive as text.
fn print_demo_archive() -> Unit {
  let a = demo_archive()
  let mut data = b""
  for i = 0; i < a.record_count(); i = i + 1 {
    data = cat_bytes(data, a.record(i).unwrap().to_bytes())
  }
  println(bytes_to_string(data))
}

///|
/// `parse`: run the buffered parser over the demo archive, then show
/// structured error reporting on a truncated copy.
fn cmd_parse() -> Unit {
  let a = demo_archive()
  let mut data = b""
  for i = 0; i < a.record_count(); i = i + 1 {
    data = cat_bytes(data, a.record(i).unwrap().to_bytes())
  }
  match @warc.parse_archive(data, @warc.Limits::default()) {
    Ok(parsed) => {
      println("parsed \{parsed.record_count()} records")
      println("total block bytes: \{parsed.total_block_bytes()}")
    }
    Err(e) => println("parse failed: " + e.to_string())
  }
  // Truncate mid-block: the parser must report a structured error,
  // never a silent partial archive.
  let truncated = data.view(start=0, end=data.length() - 3).to_owned()
  match @warc.parse_archive(truncated, @warc.Limits::default()) {
    Ok(_) => println("truncated demo still parsed (unexpected)")
    Err(e) => println("truncated demo: " + e.to_string())
  }
}

///|
/// `validate`: semantic validation of the demo archive, then of a
/// purpose-built record with violations.
fn cmd_validate() -> Unit {
  let errs = @warc.validate_archive(demo_archive())
  if errs.length() == 0 {
    println("demo archive: valid (no violations)")
  } else {
    println("demo archive: \{errs.length()} violation(s)")
    for i = 0; i < errs.length(); i = i + 1 {
      println("  " + errs[i].to_string())
    }
  }
  // A broken record to demonstrate violation reporting.
  let bad = @warc.WarcBuilder::new()
    .with_type("response")
    .record_id("<urn:uuid:99999999-9999-9999-9999-999999999999>")
    .warc_date("2020-01-07T00:00:00Z")
    .field("WARC-Target-URI", "<http://example.org/c>")
    .field("WARC-IP-Address", "not-an-ip")
    .build(b"x")
    .unwrap()
  let bad_errs = @warc.validate_archive(archive_of([bad]))
  for i = 0; i < bad_errs.length(); i = i + 1 {
    println("  " + bad_errs[i].to_string())
  }
}

///|
/// `inspect`: one line per record.
fn cmd_inspect() -> Unit {
  let a = demo_archive()
  for i = 0; i < a.record_count(); i = i + 1 {
    let rec = a.record(i).unwrap()
    let t = match rec.record_type() {
      Some(x) => x.type_name()
      None => "unknown"
    }
    let id = match rec.record_id(i.to_int64()) {
      Ok(u) => u
      Err(_) => "(missing)"
    }
    let target = match rec.target_uri(i.to_int64()) {
      Ok(u) => u
      Err(_) => "(none)"
    }
    println(
      "record \{i}: \{t} \{id} -> \{target} (block \{rec.block_length()} bytes)",
    )
  }
}

///|
/// `stats`: aggregate statistics over the demo archive.
fn cmd_stats() -> Unit {
  let s = @warc.archive_stats(demo_archive())
  println("records: \{s.record_count()}")
  println("record bytes: \{s.total_record_bytes()}")
  println("block bytes: \{s.total_block_bytes()}")
  println("distinct target URIs: \{s.distinct_target_count()}")
  for i = 0; i < @warc.all_record_type_codes().length(); i = i + 1 {
    let t = @warc.all_record_type_codes()[i]
    let c = s.type_count(t)
    if c > 0 {
      println("  \{t}: \{c}")
    }
  }
  match s.earliest_date() {
    Some(d) =>
      println(
        "earliest date: \{d.year()}-\{d.month().unwrap_or(1)}-\{d.day().unwrap_or(1)}",
      )
    None => println("earliest date: none")
  }
  match s.latest_date() {
    Some(d) =>
      println(
        "latest date: \{d.year()}-\{d.month().unwrap_or(1)}-\{d.day().unwrap_or(1)}",
      )
    None => println("latest date: none")
  }
}

///|
/// `query <uri>`: list record indices whose WARC-Target-URI equals
/// the argument (compared as a string, never treated as a path).
fn cmd_query(uri : String) -> Unit {
  let idx = @warc.WarcIndex::build(demo_archive())
  let hits = idx.by_target_uri(uri)
  if hits.length() == 0 {
    println("no records with target URI \{uri}")
  } else {
    for i = 0; i < hits.length(); i = i + 1 {
      println("record \{hits[i]} has target URI \{uri}")
    }
  }
}

///|
/// `build`: construct one record with the builder and serialize it.
fn cmd_build() -> Unit {
  let rec = @warc.WarcBuilder::new()
    .with_type("response")
    .record_id("<urn:uuid:44444444-4444-4444-4444-444444444445>")
    .warc_date("2020-02-02T02:02:02Z")
    .field("WARC-Target-URI", "<http://example.org/built>")
    .build(b"built by warc-tool\r\n")
    .unwrap()
  println(bytes_to_string(rec.to_bytes()))
}

///|
/// `audit`: advisory findings over the demo archive.
fn cmd_audit() -> Unit {
  let fs = @warc.audit_archive(demo_archive())
  if fs.length() == 0 {
    println("no findings")
  } else {
    for i = 0; i < fs.length(); i = i + 1 {
      println(fs[i].to_string())
    }
  }
}
