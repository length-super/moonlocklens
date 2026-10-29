///|
fn file_frame(
  locks : String,
  elapsed : String,
  key~ : String = "8:1:42",
  file_error~ : String = "",
  locks_error~ : String = "",
  scope~ : String = "synthetic-proc",
) -> String {
  let value : Json = {
    "elapsed_ms": elapsed,
    "boot_id": "synthetic-boot",
    "pid_namespace": scope,
    "captured_at": "synthetic",
    "file_key": key,
    "file_error": file_error,
    "locks": locks,
    "locks_error": locks_error,
  }
  value.stringify()
}

///|
test "file sessions retain OFD and related waits without a PID or unrelated data" {
  let c = @moonlocklens.file_capture()
  let locks = "1: OFDLCK ADVISORY WRITE -1 08:01:42 0 EOF\n1: -> OFDLCK ADVISORY WRITE -1 08:01:42 0 EOF\n2: POSIX ADVISORY WRITE 999 08:01:777 0 EOF"
  c.record(file_frame(locks, "0"))
  c.record(file_frame(locks, "100"))
  c.record(file_frame("", "200"))
  let r = c.report()
  assert_eq(r.peak_waiting_records, 1)
  assert_eq(r.max_consecutive_wait_samples, 2)
  assert_eq(r.frames[0].entries[0].owner, @moonlocklens.OpenDescription)
  assert_eq(r.frames[0].entries[1].parent_line, Some(1))
  assert_eq(r.frames[2].waiting_records, 0)
  assert_false(c.to_json().stringify().contains("777"))
  assert_eq(
    @moonlocklens.parse_file_capture(c.to_json().stringify()).report().sample_count,
    3,
  )
  assert_true(r.to_markdown().contains("owner -1 remains unknown"))
}

///|
test "file sessions preserve original inode through replacement and expose visibility gaps" {
  let c = @moonlocklens.file_capture()
  c.record(file_frame("", "0"))
  c.record(
    file_frame(
      "1: FLOCK ADVISORY WRITE 5 08:01:777 0 EOF",
      "100",
      key="8:1:777",
    ),
  )
  c.record(
    file_frame("", "200", key="", file_error="ENOENT", locks_error="EACCES"),
  )
  assert_eq(c.report().file.inode, 42UL)
  assert_eq(c.report().frames[1].path_state, "identity_changed")
  assert_eq(c.report().frames[1].entries.length(), 0)
  assert_eq(c.report().frames[2].path_state, "unavailable")
  assert_eq(c.report().frames[2].issues.length(), 2)
  assert_eq(error_line(() => c.record(file_frame("", "200"))), 0)
  assert_eq(error_line(() => c.record(file_frame("", "300", scope="other"))), 0)
  assert_eq(c.report().sample_count, 3)
  let empty = @moonlocklens.file_capture()
  assert_eq(
    error_line(() => {
      empty.record(file_frame("", "0", key="", file_error="ENOENT"))
    }),
    0,
  )
  assert_eq(error_line(() => ignore(empty.report())), 0)
  for i in 0..<60 {
    empty.record(file_frame("", i.to_string()))
  }
  assert_eq(error_line(() => empty.record(file_frame("", "60"))), 0)
}
