// Tests for CRLF line scanning (scanner.mbt).

///|
test "scan_line returns the line span excluding CRLF" {
  let b = @utf8.encode("Content-Length: 5\r\nrest")
  let r = scan_line(b, 0, 0L)
  match r {
    Ok((ls, le)) => {
      assert_eq(ls, 0)
      assert_eq(le, 17)
    }
    Err(e) => fail("expected the line span, got " + e.to_string())
  }
}

///|
test "scan_line accepts an empty line" {
  let b = @utf8.encode("\r\n")
  let r = scan_line(b, 0, 0L)
  match r {
    Ok((ls, le)) => {
      assert_eq(ls, 0)
      assert_eq(le, 0)
    }
    Err(e) => fail("expected an empty line, got " + e.to_string())
  }
}

///|
test "scan_line starts at the given offset" {
  let b = @utf8.encode("ab\r\ncd\r\n")
  let r = scan_line(b, 4, 3L)
  match r {
    Ok((ls, le)) => {
      assert_eq(ls, 4)
      assert_eq(le, 6)
    }
    Err(e) => fail("expected the second line, got " + e.to_string())
  }
}

///|
test "scan_line rejects a bare CR inside the line" {
  let b = @utf8.encode("abc\rX")
  let r = scan_line(b, 0, 0L)
  match r {
    Ok(_) => fail("expected a separator error")
    Err(e) => {
      assert_eq(e.kind.kind_name(), "invalid-separator")
      assert_eq(e.stage, stage_of_code("separator").unwrap())
      assert_eq(e.byte_offset, 3L)
    }
  }
}

///|
test "scan_line rejects a trailing bare CR at end of input" {
  let b = @utf8.encode("abc\r")
  let r = scan_line(b, 0, 0L)
  match r {
    Ok(_) => fail("expected a separator error")
    Err(e) => {
      assert_eq(e.kind.kind_name(), "invalid-separator")
      assert_eq(e.byte_offset, 3L)
    }
  }
}

///|
test "scan_line rejects a bare LF" {
  let b = @utf8.encode("abc\nX")
  let r = scan_line(b, 0, 0L)
  match r {
    Ok(_) => fail("expected a separator error")
    Err(e) => {
      assert_eq(e.kind.kind_name(), "invalid-separator")
      assert_eq(e.byte_offset, 3L)
    }
  }
}

///|
test "scan_line reports unterminated input as EOF" {
  let b = @utf8.encode("abc")
  let r = scan_line(b, 0, 0L)
  match r {
    Ok(_) => fail("expected an EOF error")
    Err(e) => {
      assert_eq(e.kind.kind_name(), "unexpected-eof")
      assert_eq(e.byte_offset, 3L)
    }
  }
}

///|
test "scan_line tolerates HT and SP inside the line" {
  let b = @utf8.encode("a\t b\r\n")
  let r = scan_line(b, 0, 0L)
  match r {
    Ok((ls, le)) => {
      assert_eq(ls, 0)
      assert_eq(le, 4)
    }
    Err(e) => fail("expected the line span, got " + e.to_string())
  }
}
