// Tests for the structured error model (error.mbt).

///|
test "every stage code resolves and round-trips through its name" {
  let codes = all_stage_codes()
  assert_eq(codes.length(), 16)
  for i = 0; i < codes.length(); i = i + 1 {
    let code = codes[i]
    let s = stage_of_code(code)
    match s {
      None => fail("stage code not resolvable: \{code}")
      Some(st) => assert_eq(st.stage_name(), code)
    }
  }
}

///|
test "every kind code resolves and round-trips through its name" {
  let codes = all_kind_codes()
  assert_eq(codes.length(), 18)
  for i = 0; i < codes.length(); i = i + 1 {
    let code = codes[i]
    let k = kind_of_code(code)
    match k {
      None => fail("kind code not resolvable: \{code}")
      Some(kd) => assert_eq(kd.kind_name(), code)
    }
  }
}

///|
test "unknown codes resolve to None" {
  assert_eq(stage_of_code("nope"), None)
  assert_eq(kind_of_code("nope"), None)
  assert_eq(stage_of_code(""), None)
  assert_eq(kind_of_code(""), None)
}

///|
test "WarcError::new stores all fields" {
  let stage = stage_of_code("content-length").unwrap()
  let kind = kind_of_code("integer-overflow").unwrap()
  let e = WarcError::new(stage, kind, 123L, 4L, "Content-Length: too long")
  assert_eq(e.byte_offset, 123L)
  assert_eq(e.record_index, 4L)
  assert_eq(e.context, "Content-Length: too long")
  assert_eq(e.stage.stage_name(), "content-length")
  assert_eq(e.kind.kind_name(), "integer-overflow")
}

///|
test "to_string renders stage kind offset record and context" {
  let stage = stage_of_code("block").unwrap()
  let kind = kind_of_code("unexpected-eof").unwrap()
  let e = WarcError::new(stage, kind, 9L, 0L, "truncated block")
  let s = e.to_string()
  assert_true(s.contains("[block]"))
  assert_true(s.contains("unexpected-eof"))
  assert_true(s.contains("byte 9"))
  assert_true(s.contains("record 0"))
  assert_true(s.contains("truncated block"))
}

///|
test "stage and kind codes are stable in declaration order" {
  assert_eq(all_stage_codes()[0], "input")
  assert_eq(all_stage_codes()[15], "builder")
  assert_eq(all_kind_codes()[0], "unexpected-eof")
  assert_eq(all_kind_codes()[16], "limit-exceeded")
}
