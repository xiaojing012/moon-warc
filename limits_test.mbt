// Tests for resource limit presets (limits.mbt).

///|
test "default preset has the documented 1 GB archive target" {
  let l = Limits::default()
  assert_eq(l.max_archive_bytes, 1_000_000_000L)
  assert_eq(l.max_block_bytes, 536_870_912L)
  assert_eq(l.max_header_count, 1000)
  assert_eq(l.max_content_length_digits, 19)
}

///|
test "strict preset is tighter than default" {
  let s = Limits::strict()
  let d = Limits::default()
  assert_true(s.max_archive_bytes < d.max_archive_bytes)
  assert_true(s.max_record_bytes < d.max_record_bytes)
  assert_true(s.max_header_bytes < d.max_header_bytes)
  assert_true(s.max_header_count < d.max_header_count)
  assert_true(s.max_field_name_bytes < d.max_field_name_bytes)
  assert_true(s.max_field_value_bytes < d.max_field_value_bytes)
  assert_true(s.max_block_bytes < d.max_block_bytes)
  assert_true(s.max_records < d.max_records)
}

///|
test "permissive preset is wider than default" {
  let p = Limits::permissive()
  let d = Limits::default()
  assert_true(p.max_archive_bytes > d.max_archive_bytes)
  assert_true(p.max_record_bytes > d.max_record_bytes)
  assert_true(p.max_header_bytes > d.max_header_bytes)
  assert_true(p.max_header_count > d.max_header_count)
  assert_true(p.max_field_name_bytes > d.max_field_name_bytes)
  assert_true(p.max_field_value_bytes > d.max_field_value_bytes)
  assert_true(p.max_block_bytes > d.max_block_bytes)
  assert_true(p.max_records > d.max_records)
}

///|
test "presets keep digit limits within Int64 range" {
  let p = Limits::permissive()
  assert_true(p.max_content_length_digits <= 19)
  let s = Limits::strict()
  assert_true(s.max_content_length_digits <= 19)
}
