///|
fn tree() -> @moonlocklens.Snapshot raise {
  let text =
    #|9: POSIX ADVISORY WRITE 10 08:01:42 0 99
    #|9: -> POSIX ADVISORY WRITE 20 08:01:42 0 99
    #|9:  -> POSIX ADVISORY READ 30 08:01:42 0 99
    #|9: -> POSIX ADVISORY WRITE 40 08:01:42 50 EOF
    #|2: OFDLCK ADVISORY WRITE -1 08:01:99 128 EOF
    #|2: -> OFDLCK ADVISORY WRITE -1 08:01:99 128 EOF
    #|7: FLOCK ADVISORY READ 70 08:01:100 0 EOF
  @moonlocklens.parse(text)
}

///|
test "nested immediate blockers and siblings" {
  let s = tree()
  assert_eq(s.wait_chain(3).map(e => e.line), [3, 2, 1])
  assert_eq(s.wait_chain(4).map(e => e.line), [4, 1])
  assert_eq(s.wait_chain(7).map(e => e.line), [7])
  assert_eq(s.children(1).map(e => e.line), [2, 4])
  assert_eq(s.entry(3).parent_line, Some(2))
}

///|
test "bottlenecks count all descendants once and preserve OFD ownership" {
  let b = tree().bottlenecks()
  assert_eq(b.length(), 2)
  assert_eq(b[0].holder_line, 1)
  assert_eq(b[0].direct_waiters, 2)
  assert_eq(b[0].total_waiters, 3)
  assert_eq(b[1].owner, @moonlocklens.OpenDescription)
  assert_eq(b[1].total_waiters, 1)
}

///|
test "root IDs need not be sorted and equal impact uses input order" {
  let s = @moonlocklens.parse(
    "8: FLOCK ADVISORY WRITE 1 00:01:1 0 EOF\n8: -> FLOCK ADVISORY WRITE 2 00:01:1 0 EOF\n2: FLOCK ADVISORY WRITE 3 00:01:2 0 EOF\n2: -> FLOCK ADVISORY WRITE 4 00:01:2 0 EOF",
  )
  assert_eq(s.bottlenecks().map(b => b.holder_line), [1, 3])
}

///|
test "range endpoints are inclusive and EOF never overflows" {
  assert_true(
    @moonlocklens.byte_range("0", "99").overlaps(
      @moonlocklens.byte_range("99", "100"),
    ),
  )
  assert_false(
    @moonlocklens.byte_range("0", "99").overlaps(
      @moonlocklens.byte_range("100", "EOF"),
    ),
  )
  assert_true(
    @moonlocklens.byte_range("9223372036854775807", "EOF").overlaps(
      @moonlocklens.byte_range("9223372036854775807", "9223372036854775807"),
    ),
  )
  let s = tree()
  let key = @moonlocklens.file_key("08:01:42")
  assert_eq(
    s.query_range(key, @moonlocklens.byte_range("99", "99")).map(e => e.line),
    [1, 2, 3, 4],
  )
  assert_eq(
    s.query_range(key, @moonlocklens.byte_range("100", "EOF")).map(e => e.line),
    [4],
  )
  assert_eq(
    s
    .query_range(
      key,
      @moonlocklens.byte_range("0", "EOF"),
      include_waiters=false,
    )
    .map(e => e.line),
    [1],
  )
  assert_eq(
    s
    .query_range(
      @moonlocklens.file_key("08:02:42"),
      @moonlocklens.byte_range("0", "EOF"),
    )
    .length(),
    0,
  )
}

///|
test "mutating returned arrays cannot change snapshot" {
  let s = tree()
  let records = s.entries()
  records.clear()
  let children = s.children(1)
  children.clear()
  assert_eq(s.length(), 7)
  assert_eq(s.wait_chain(3).length(), 3)
  assert_eq(s.children(1).length(), 2)
}

///|
test "unknown source lines and invalid public ranges report typed errors" {
  let s = tree()
  let bad : @moonlocklens.ByteRange = { start: 5L, end: Some(4L), }
  let key = @moonlocklens.file_key("00:01:1")
  let a = error_line(() => ignore(s.query_range(key, bad)))
  assert_eq(a, 0)
  let b = error_line(() => ignore(s.entry(999)))
  assert_eq(b, 999)
}

///|
test "JSON preserves unsigned inode and signed offset precision as strings" {
  let s = @moonlocklens.parse(
    "1: POSIX ADVISORY READ 1 ff:02:18446744073709551615 9223372036854775807 EOF",
  )
  let text = s.to_json().stringify()
  assert_true(text.contains("\"18446744073709551615\""))
  assert_true(text.contains("\"9223372036854775807\""))
}

///|
test "depth budget accepts exact limit and long chains terminate" {
  let mut text = "1: POSIX ADVISORY WRITE 1 00:01:1 0 EOF"
  for d in 1..<=64 {
    text += "\n1:" +
      String::make(d, ' ') +
      "-> POSIX ADVISORY WRITE 2 00:01:1 0 EOF"
  }
  let s = @moonlocklens.parse(text)
  assert_eq(s.wait_chain(65).length(), 65)
  assert_eq(s.bottlenecks()[0].total_waiters, 64)
}
