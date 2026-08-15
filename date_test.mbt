// Tests for WARC-Date parsing (date.mbt).

///|
test "parse_warc_date accepts date-only granularities" {
  let y = parse_warc_date("2010", 0L).unwrap()
  assert_eq(y.year, 2010)
  assert_eq(y.month, None)
  assert_eq(y.day, None)
  assert_eq(y.has_time(), false)
  let ym = parse_warc_date("2010-11", 0L).unwrap()
  assert_eq(ym.year, 2010)
  assert_eq(ym.month, Some(11))
  assert_eq(ym.day, None)
  let ymd = parse_warc_date("2010-11-13", 0L).unwrap()
  assert_eq(ymd.year, 2010)
  assert_eq(ymd.month, Some(11))
  assert_eq(ymd.day, Some(13))
}

///|
test "parse_warc_date accepts the full UTC form" {
  let d = parse_warc_date("2010-11-13T01:36:57Z", 0L).unwrap()
  assert_eq(d.year, 2010)
  assert_eq(d.month, Some(11))
  assert_eq(d.day, Some(13))
  assert_eq(d.hour, Some(1))
  assert_eq(d.minute, Some(36))
  assert_eq(d.second, Some(57))
  assert_eq(d.has_time(), true)
  assert_eq(d.has_fraction(), false)
}

///|
test "parse_warc_date accepts partial time forms" {
  let h = parse_warc_date("2010-11-13T01Z", 0L).unwrap()
  assert_eq(h.hour, Some(1))
  assert_eq(h.minute, None)
  let hm = parse_warc_date("2010-11-13T01:36Z", 0L).unwrap()
  assert_eq(hm.hour, Some(1))
  assert_eq(hm.minute, Some(36))
  assert_eq(hm.second, None)
}

///|
test "parse_warc_date keeps fractional seconds as exact digits" {
  let d = parse_warc_date("2010-11-13T01:36:57.1Z", 0L).unwrap()
  assert_eq(d.fraction, "1")
  let d2 = parse_warc_date("2010-11-13T01:36:57.123456789Z", 0L).unwrap()
  assert_eq(d2.fraction, "123456789")
  let d3 = parse_warc_date("2010-11-13T01:36:57.000001Z", 0L).unwrap()
  assert_eq(d3.fraction, "000001")
}

///|
test "parse_warc_date handles leap years" {
  assert_eq(parse_warc_date("2024-02-29", 0L) is Ok(_), true)
  assert_eq(parse_warc_date("2023-02-28", 0L) is Ok(_), true)
  let r = parse_warc_date("2023-02-29", 0L)
  match r {
    Ok(_) => fail("expected an invalid-date error for 2023-02-29")
    Err(e) => assert_eq(e.kind.kind_name(), "invalid-date")
  }
  let r2 = parse_warc_date("2000-02-29", 0L)
  assert_eq(r2 is Ok(_), true)
}

///|
test "parse_warc_date rejects out-of-range components" {
  for
    bad in [
      "2010-13", "2010-00", "2010-00-01", "2010-04-31", "2010-06-31", "2010-11-13T24Z",
      "2010-11-13T01:60Z", "2010-11-13T01:36:60Z",
    ] {
    let r = parse_warc_date(bad, 0L)
    match r {
      Ok(_) => fail("expected an invalid-date error for: " + bad)
      Err(e) => assert_eq(e.kind.kind_name(), "invalid-date")
    }
  }
}

///|
test "parse_warc_date rejects fractional second violations" {
  for
    bad in [
      "2010-11-13T01:36:57.Z", "2010-11-13T01:36:57.1234567890Z", "2010-11-13T01:36:57.1xZ",
    ] {
    let r = parse_warc_date(bad, 0L)
    match r {
      Ok(_) => fail("expected an invalid-date error for: " + bad)
      Err(e) => assert_eq(e.kind.kind_name(), "invalid-date")
    }
  }
}

///|
test "parse_warc_date requires Z on the time form" {
  for
    bad in [
      "2010-11-13T01:36:57", "2010-11-13T01:36:57+08:00", "2010-11-13T01:36:57z",
    ] {
    let r = parse_warc_date(bad, 0L)
    match r {
      Ok(_) => fail("expected an invalid-date error for: " + bad)
      Err(e) => assert_eq(e.kind.kind_name(), "invalid-date")
    }
  }
}

///|
test "parse_warc_date rejects trailing garbage on dates" {
  for
    bad in [
      "2010-11-13Z", "2010-11-13 ", "2010-11-13T01:36:57ZZ", "2010-11-13T01:36:57Zx",
    ] {
    let r = parse_warc_date(bad, 0L)
    match r {
      Ok(_) => fail("expected an invalid-date error for: " + bad)
      Err(e) => assert_eq(e.kind.kind_name(), "invalid-date")
    }
  }
}

///|
test "parse_warc_date rejects malformed shapes" {
  for
    bad in [
      "", "201", "201a", "abcd", "2010-1", "2010-11-1", "2010-11-13T1Z", "2010/11/13",
      "2010-11-13t01:36:57Z",
    ] {
    let r = parse_warc_date(bad, 0L)
    match r {
      Ok(_) => fail("expected an invalid-date error for: " + bad)
      Err(e) => assert_eq(e.kind.kind_name(), "invalid-date")
    }
  }
}

///|
test "parse_warc_date errors carry stage and record index" {
  let r = parse_warc_date("2010-13", 7L)
  match r {
    Ok(_) => fail("expected an invalid-date error")
    Err(e) => {
      assert_eq(e.stage, stage_of_code("date").unwrap())
      assert_eq(e.record_index, 7L)
    }
  }
}
