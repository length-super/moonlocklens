///|
/// Combine process, device+inode and waiter filters. Unknown owners never match a PID.
pub fn Snapshot::matching(
  self : Snapshot,
  pid? : Int32,
  file? : FileKey,
  waiting_only~ : Bool = false,
) -> Array[Entry] raise LockError {
  if pid is Some(n) && n <= 0 {
    invalid(0, "PID must be positive")
  }
  self.records.filter(e => {
    (pid is None || (pid is Some(n) && e.owner == Process(n))) &&
    (file is None || e.file == file) &&
    (!waiting_only || e.depth > 0)
  })
}

///|
/// Selected lines plus all their actual blockers, deduplicated in snapshot order.
pub fn Snapshot::with_blockers(
  self : Snapshot,
  lines : ArrayView[Int32],
) -> Array[Entry] raise LockError {
  let wanted : Map[Int32, Bool] = Map([])
  for line in lines {
    wanted[line] = true
  }
  let keep = Array::make(self.records.length(), false)
  for i, e in self.records {
    if wanted.contains(e.line) {
      keep[i] = true
      wanted.remove(e.line)
    }
  }
  for line, _ in wanted {
    invalid(line, "no lock record at this source line")
  }
  for i = self.records.length() - 1; i >= 0; i = i - 1 {
    if keep[i] && self.parents[i] is Some(parent) {
      keep[parent] = true
    }
  }
  let result : Array[Entry] = []
  for i, e in self.records {
    if keep[i] {
      result.push(e)
    }
  }
  result
}
