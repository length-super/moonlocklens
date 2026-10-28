///|
test "capture sample and task tree budgets reject excess without appending" {
  let c = @moonlocklens.task_capture(100)
  for i in 0..<60 {
    c.record(frame([proc_wire(100, 1, "1000")], "", i.to_string()))
  }
  assert_eq(c.sample_count(), 60)
  assert_eq(
    error_line(() => c.record(frame([proc_wire(100, 1, "1000")], "", "60"))),
    0,
  )
  assert_eq(c.sample_count(), 60)
  let processes : Array[Json] = [proc_wire(100, 1, "1000")]
  for i in 101..<=356 {
    processes.push(proc_wire(i, 100, "2000"))
  }
  let large = @moonlocklens.task_capture(100)
  assert_eq(error_line(() => large.record(frame(processes, "", "0"))), 0)
  assert_eq(large.sample_count(), 0)
}
