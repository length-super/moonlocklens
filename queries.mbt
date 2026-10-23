///|
pub fn Snapshot::entries(self : Snapshot) -> Array[Entry] {
  self.records.copy()
}

///|
pub fn Snapshot::length(self : Snapshot) -> Int32 {
  self.records.length()
}

///|
fn Snapshot::index(self : Snapshot, line : Int32) -> Int32 raise LockError {
  for i, e in self.records {
    if e.line == line {
      return i
    }
  }
  invalid(line, "no lock record at this source line")
  -1
}

///|
pub fn Snapshot::entry(self : Snapshot, line : Int32) -> Entry raise LockError {
  self.records[self.index(line)]
}

///|
/// Requested record first, then immediate blocker, ending at the granted root.
pub fn Snapshot::wait_chain(
  self : Snapshot,
  line : Int32,
) -> Array[Entry] raise LockError {
  let result : Array[Entry] = []
  let mut current = Some(self.index(line))
  while current is Some(i) {
    result.push(self.records[i])
    current = self.parents[i]
  }
  result
}

///|
pub fn Snapshot::children(
  self : Snapshot,
  line : Int32,
) -> Array[Entry] raise LockError {
  let target = self.index(line)
  let result : Array[Entry] = []
  for i, e in self.records {
    if self.parents[i] == Some(target) {
      result.push(e)
    }
  }
  result
}

///|
/// Only roots with observed waiters. Rank by total descendants, then source line.
pub fn Snapshot::bottlenecks(self : Snapshot) -> Array[Bottleneck] {
  let n = self.records.length()
  let direct = Array::make(n, 0)
  let total = Array::make(n, 0)
  for i = n - 1; i >= 0; i = i - 1 {
    if self.parents[i] is Some(parent) {
      direct[parent] += 1
      total[parent] += 1 + total[i]
    }
  }
  let result : Array[Bottleneck] = []
  for i, e in self.records {
    if e.depth == 0 && total[i] > 0 {
      result.push({
        holder_line: e.line,
        owner: e.owner,
        direct_waiters: direct[i],
        total_waiters: total[i],
      })
    }
  }
  result.sort_by((a, b) => {
    if a.total_waiters == b.total_waiters {
      a.holder_line.compare(b.holder_line)
    } else {
      b.total_waiters.compare(a.total_waiters)
    }
  })
  result
}

///|
pub fn ByteRange::overlaps(
  self : ByteRange,
  other : ByteRange,
) -> Bool raise LockError {
  self.validate()
  other.validate()
  !(self.end is Some(e) && e < other.start) &&
  !(other.end is Some(e) && e < self.start)
}

///|
fn ByteRange::validate(self : ByteRange) -> Unit raise LockError {
  if self.start < 0L || (self.end is Some(e) && e < self.start) {
    invalid(0, "invalid inclusive byte range")
  }
}

///|
/// Overlap evidence only: does not predict lock granting or cross-filesystem behavior.
pub fn Snapshot::query_range(
  self : Snapshot,
  key : FileKey,
  range : ByteRange,
  include_waiters~ : Bool = true,
) -> Array[Entry] raise LockError {
  range.validate()
  let result : Array[Entry] = []
  for e in self.records {
    if e.file == Some(key) &&
      (include_waiters || e.depth == 0) &&
      e.range.overlaps(range) {
      result.push(e)
    }
  }
  result
}

///|
pub fn Snapshot::to_json(self : Snapshot) -> Json {
  {
    "schema": "moonlocklens/1",
    "entries": Json(self.records),
    "bottlenecks": Json(self.bottlenecks()),
  }
}
