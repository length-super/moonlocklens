///|
test "task gate distinguishes threshold evidence from a clear window or missing visibility" {
  let c = @moonlocklens.task_capture(100)
  c.record(frame(task_processes(), task_locks(), "0"))
  assert_eq(c.assess().status, "inconclusive")
  c.record(frame(task_processes(), task_locks(), "100"))
  assert_eq(c.assess().status, "fail")
  c.record(frame(task_processes(), "", "200"))
  assert_eq(c.assess(wait_samples=3).status, "pass")
  assert_eq(c.assess().status, "fail")
  assert_eq(
    @moonlocklens.assess_capture(c.to_json().stringify()).observed_streak,
    2,
  )
  c.record(frame(task_processes(), "", "300", locks_error="EACCES"))
  assert_eq(c.assess(wait_samples=3).status, "inconclusive")
  assert_eq(c.assess().status, "fail")
  assert_eq(error_line(() => ignore(c.assess(wait_samples=0))), 0)
  assert_eq(error_line(() => ignore(c.assess(wait_samples=61))), 0)
  let reused = @moonlocklens.task_capture(100)
  reused.record(frame(task_processes(), task_locks(), "0"))
  reused.record(
    frame(
      [proc_wire(100, 1, "1000"), proc_wire(200, 100, "9000")],
      task_locks(),
      "100",
    ),
  )
  assert_eq(reused.assess().observed_streak, 1)
}

///|
test "file gate checks scope and sampling gaps without inventing PID owners" {
  let c = @moonlocklens.file_capture()
  let locks = "1: OFDLCK ADVISORY WRITE -1 08:01:42 0 EOF\n1: -> OFDLCK ADVISORY WRITE -1 08:01:42 0 EOF"
  c.record(file_frame(locks, "0"))
  c.record(file_frame(locks, "100"))
  assert_eq(c.assess().status, "fail")
  c.record(file_frame("", "200"))
  assert_eq(c.assess(wait_samples=3).status, "pass")
  c.record(file_frame("", "300", key="8:1:777"))
  assert_eq(c.assess(wait_samples=3).status, "inconclusive")
  assert_eq(c.assess(wait_samples=3).evidence_gaps, 1)
  assert_eq(
    @moonlocklens.assess_capture(c.to_json().stringify()).status,
    "fail",
  )
  assert_eq(error_line(() => ignore(@moonlocklens.assess_capture("{}"))), 0)
}
