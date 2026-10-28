///|
fn proc_stat(
  pid : Int32,
  parent : Int32,
  start : String,
  name~ : String = "worker",
  state~ : String = "S",
) -> String {
  let mut text = "\{pid} (\{name}) \{state} \{parent}"
  for _ in 0..<17 {
    text += " 0"
  }
  text + " " + start
}

///|
fn proc_wire(
  pid : Int32,
  parent : Int32,
  start : String,
  name~ : String = "worker",
  state~ : String = "S",
  wchan~ : String = "do_wait",
  error~ : String = "",
) -> Json {
  {
    "stat": proc_stat(pid, parent, start, name~, state~),
    "wchan": wchan,
    "wchan_error": error,
  }
}

///|
fn frame(
  processes : Array[Json],
  locks : String,
  elapsed : String,
  root_start~ : String = "1000",
  root_error~ : String = "",
  locks_error~ : String = "",
  scope~ : String = "synthetic-pidns",
  complete~ : Bool = true,
) -> String {
  let json : Json = {
    "elapsed_ms": elapsed,
    "boot_id": "synthetic-boot",
    "pid_namespace": scope,
    "captured_at": "2026-10-28T00:00:00Z",
    "catalog_complete": complete,
    "root_error": root_error,
    "root_after": if root_error == "" {
      proc_stat(100, 1, root_start)
    } else {
      ""
    },
    "processes": Json(processes),
    "locks": locks,
    "locks_error": locks_error,
  }
  json.stringify()
}

///|
fn task_processes() -> Array[Json] {
  [
    proc_wire(100, 1, "1000", name="builder"),
    proc_wire(200, 100, "2000", wchan="locks_lock_inode_wait"),
    proc_wire(300, 200, "3000", state="R", wchan="0"),
    proc_wire(900, 1, "900", name="external-owner"),
    proc_wire(999, 1, "999", name="unrelated-secret-name"),
  ]
}

///|
fn task_locks() -> String {
  "1: POSIX ADVISORY WRITE 900 08:01:42 0 EOF\n1: -> POSIX ADVISORY WRITE 200 08:01:42 0 EOF\n2: FLOCK ADVISORY READ 999 08:01:999 0 EOF"
}

///|
test "proc stat parses comm parentheses/newlines and exact unsigned starttime" {
  let p = @moonlocklens.parse_process(
    proc_stat(7, 1, "18446744073709551615", name="a) b (\nx"),
    wchan="0",
  )
  assert_eq(p.name, "a) b (\nx")
  assert_eq(p.parent_pid, 1)
  assert_eq(p.start_ticks, "18446744073709551615")
  assert_eq(p.wchan_status, "hidden_or_not_sleeping")
  assert_eq(
    error_line(() => ignore(@moonlocklens.parse_process("7 (broken) S 1"))),
    0,
  )
  assert_eq(
    error_line(() => ignore(@moonlocklens.parse_process(proc_stat(7, 1, "-1")))),
    0,
  )
}

///|
test "task tree correlates external blockers and retains only task evidence" {
  let c = @moonlocklens.task_capture(100)
  c.record(frame(task_processes(), task_locks(), "0"))
  let r = c.report()
  assert_eq(r.frames[0].processes.map(p => p.info.pid), [100, 200, 300])
  assert_eq(r.frames[0].processes[1].finding, "confirmed_file_lock_wait")
  assert_eq(r.frames[0].processes[2].finding, "runnable_progress_unknown")
  assert_eq(r.frames[0].blocker_processes[0].pid, 900)
  assert_eq(r.frames[0].processes[1].files[0].inode, 42UL)
  assert_false(c.to_json().stringify().contains("unrelated-secret-name"))
  assert_false(c.to_json().stringify().contains("08:01:999"))
  let roundtrip = @moonlocklens.parse_task_capture(c.to_json().stringify()).report()
  assert_eq(roundtrip.frames[0].processes[1].blocker_identities, ["900:900"])
}

///|
test "sampled wait span and recovery do not depend on lock ordinal or line" {
  let c = @moonlocklens.task_capture(100)
  c.record(frame(task_processes(), task_locks(), "10"))
  c.record(
    frame(
      task_processes(),
      "77: POSIX ADVISORY WRITE 900 08:01:42 0 EOF\n77: -> POSIX ADVISORY WRITE 200 08:01:42 0 EOF",
      "110",
    ),
  )
  c.record(frame(task_processes(), "", "210"))
  let r = c.report()
  assert_eq(r.max_consecutive_wait_samples, 2)
  assert_eq(r.max_sampled_wait_span_ms, 100L)
  assert_eq(r.observed_span_ms, 200L)
  assert_eq(
    r.transitions.filter(t => t.change == "blocker_evidence_changed").length(),
    0,
  )
  assert_eq(
    r.transitions
    .filter(t => t.pid == 200 && t.change == "finding_changed")
    .length(),
    1,
  )
}

///|
test "root PID reuse is reported without attaching to a new task" {
  let c = @moonlocklens.task_capture(100)
  c.record(frame(task_processes(), task_locks(), "0"))
  c.record(frame([proc_wire(100, 1, "8000")], "", "100", root_start="8000"))
  let r = @moonlocklens.parse_task_capture(c.to_json().stringify()).report()
  assert_eq(r.root_start_ticks, "1000")
  assert_eq(r.frames[1].root_state, "identity_changed")
  assert_eq(r.frames[1].processes.length(), 0)
}

///|
test "lost roots, unavailable lock evidence and unreadable wait channels stay explicit" {
  let c = @moonlocklens.task_capture(100)
  c.record(
    frame(
      [proc_wire(100, 1, "1000", wchan="", error="EACCES")],
      "",
      "0",
      locks_error="EACCES",
      complete=false,
    ),
  )
  assert_eq(
    c.report().frames[0].processes[0].finding,
    "lock_evidence_unavailable",
  )
  assert_eq(c.report().frames[0].processes[0].info.wchan_status, "unavailable")
  c.record(frame([], "", "100", root_error="ENOENT"))
  assert_eq(c.report().frames[1].root_state, "not_observed")
  assert_true(c.report().next_steps.any(s => s.contains("do not prove")))
}

///|
test "child PID reuse and blocker identity changes generate separate observations" {
  let c = @moonlocklens.task_capture(100)
  c.record(frame(task_processes(), task_locks(), "0"))
  c.record(
    frame(
      [
        proc_wire(100, 1, "1000"),
        proc_wire(200, 100, "2000"),
        proc_wire(900, 1, "9001"),
      ],
      task_locks(),
      "100",
    ),
  )
  assert_eq(
    c.report().transitions
    .filter(t => t.pid == 200 && t.change == "blocker_evidence_changed")
    .length(),
    1,
  )
  c.record(
    frame([proc_wire(100, 1, "1000"), proc_wire(200, 100, "9000")], "", "200"),
  )
  assert_eq(
    c.report().transitions
    .filter(t => {
      t.pid == 200 && t.start_ticks == "9000" && t.change == "first_observed"
    })
    .length(),
    1,
  )
  assert_eq(
    c.report().transitions
    .filter(t => {
      t.pid == 200 && t.start_ticks == "2000" && t.change == "not_observed"
    })
    .length(),
    1,
  )
}

///|
test "capture rejects invalid clocks scope schema root races and oversized catalogs" {
  let c = @moonlocklens.task_capture(100)
  c.record(frame(task_processes(), task_locks(), "1"))
  assert_eq(error_line(() => c.record(frame(task_processes(), "", "1"))), 0)
  assert_eq(
    error_line(() => {
      c.record(frame(task_processes(), "", "2", scope="other-ns"))
    }),
    0,
  )
  assert_eq(
    error_line(() => {
      c.record(frame(task_processes(), "", "2", root_start="9000"))
    }),
    0,
  )
  assert_eq(c.sample_count(), 1)
  assert_eq(error_line(() => ignore(@moonlocklens.parse_task_capture("{}"))), 0)
  assert_eq(error_line(() => ignore(@moonlocklens.task_capture(0))), 0)
  assert_eq(
    error_line(() => {
      c.record(frame(Array::make(4097, proc_wire(100, 1, "1000")), "", "2"))
    }),
    0,
  )
  let looped = [proc_wire(100, 200, "1000"), proc_wire(200, 100, "2000")]
  assert_eq(error_line(() => c.record(frame(looped, "", "2"))), 0)
}

///|
test "Markdown report escapes untrusted names and explains sampled observations" {
  let c = @moonlocklens.task_capture(100)
  c.record(
    frame([proc_wire(100, 1, "1000", name="<x>|[evil]", state="T")], "", "0"),
  )
  let text = c.report().to_markdown()
  assert_true(text.contains("&lt;x&gt;\\|\\[evil\\]"))
  assert_true(text.contains("stopped_or_traced"))
  assert_true(text.contains("does not prove an uninterrupted wait"))
}
