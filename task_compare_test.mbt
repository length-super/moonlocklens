///|
test "compare witnesses recovery without treating missing or reused PID as resolved" {
  let before = @moonlocklens.task_capture(100)
  before.record(frame(task_processes(), task_locks(), "0"))
  let after = @moonlocklens.task_capture(100)
  after.record(frame(task_processes(), "", "0"))
  let r = before.compare(after)
  assert_true(r.evidence_complete)
  assert_eq(r.before_waiters, 1)
  assert_eq(r.after_waiters, 0)
  assert_eq(r.resolved_lock_waits, 1)
  assert_true(r.to_markdown().contains("final sample"))
  let missing = @moonlocklens.task_capture(100)
  missing.record(frame([proc_wire(100, 1, "1000")], "", "0"))
  assert_eq(before.compare(missing).resolved_lock_waits, 0)
  assert_true(
    before.compare(missing).changes.any(c => {
      c.pid == 200 && c.change == "not_observed"
    }),
  )
  let reused = @moonlocklens.task_capture(100)
  reused.record(
    frame([proc_wire(100, 1, "1000"), proc_wire(200, 100, "9999")], "", "0"),
  )
  assert_eq(before.compare(reused).resolved_lock_waits, 0)
  assert_true(
    before.compare(reused).changes.any(c => {
      c.pid == 200 && c.change == "newly_observed"
    }),
  )
}

///|
test "compare refuses incompatible scope and keeps incomplete evidence explicit" {
  let before = @moonlocklens.task_capture(100)
  before.record(frame(task_processes(), task_locks(), "0"))
  let unknown = @moonlocklens.task_capture(100)
  unknown.record(frame(task_processes(), "", "0", locks_error="EACCES"))
  assert_false(before.compare(unknown).evidence_complete)
  assert_eq(before.compare(unknown).resolved_lock_waits, 0)
  let other = @moonlocklens.task_capture(100)
  other.record(frame(task_processes(), "", "0", scope="different"))
  assert_eq(error_line(() => ignore(before.compare(other))), 0)
  let reordered = @moonlocklens.task_capture(100)
  reordered.record(
    frame(
      task_processes(),
      "45: POSIX ADVISORY WRITE 900 08:01:42 0 EOF\n45: -> POSIX ADVISORY WRITE 200 08:01:42 0 EOF",
      "0",
    ),
  )
  assert_eq(before.compare(reordered).changes.length(), 0)
}
