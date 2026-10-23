///|
test "combined filters preserve unknown owners and distinguish no matches" {
  let s = tree()
  assert_eq(s.matching(pid=20).map(e => e.line), [2])
  assert_eq(
    s
    .matching(file=@moonlocklens.file_key("08:01:42"), waiting_only=true)
    .map(e => e.line),
    [2, 3, 4],
  )
  assert_eq(
    s.matching(pid=20, file=@moonlocklens.file_key("08:01:99")).length(),
    0,
  )
  assert_eq(s.matching(pid=999).length(), 0)
  assert_eq(s.matching(waiting_only=true).map(e => e.line), [2, 3, 4, 6])
  assert_eq(error_line(() => ignore(s.matching(pid=0))), 0)
  assert_eq(error_line(() => ignore(s.matching(pid=-1))), 0)
}

///|
test "context union deduplicates and includes only actual blockers" {
  let s = tree()
  assert_eq(s.with_blockers([3, 4, 3]).map(e => e.line), [1, 2, 3, 4])
  assert_eq(s.with_blockers([6]).map(e => e.line), [5, 6])
  assert_eq(s.with_blockers([1]).map(e => e.line), [1])
  assert_eq(s.with_blockers([]).length(), 0)
  assert_eq(error_line(() => ignore(s.with_blockers([3, 999]))), 999)
  s.with_blockers([3]).clear()
  assert_eq(s.wait_chain(3).map(e => e.line), [3, 2, 1])
}
