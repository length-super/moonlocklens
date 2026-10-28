///|
/// Linux /proc/PID/stat: comm may contain spaces, parentheses and newlines.
/// Only leader state is represented; a sleeping leader says nothing about all threads.
pub fn parse_process(
  stat : String,
  wchan~ : String = "",
  wchan_error~ : String = "",
) -> ProcessInfo raise LockError {
  if stat.length() > 8192 || wchan.length() > 256 || wchan_error.length() > 256 {
    invalid(0, "process field budget exceeded")
  }
  guard stat.find(" (") is Some(open) &&
    stat.rev_find(") ") is Some(close) &&
    close > open else {
    invalid(0, "malformed proc stat comm boundary")
    abort("unreachable")
  }
  let pid = unsigned(stat[:open].to_owned(), 10UL, 2147483647UL, 0).to_int()
  if pid <= 0 {
    invalid(0, "process PID must be positive")
  }
  let fields = words(stat[close + 2:].trim().to_owned())
  if fields.length() < 20 || fields[0].length() != 1 {
    invalid(0, "proc stat needs state through starttime")
  }
  let parent_pid = unsigned(fields[1], 10UL, 2147483647UL, 0).to_int()
  let start = unsigned(fields[19], 10UL, 18446744073709551615UL, 0).to_string()
  let channel = wchan.trim().to_owned()
  let status = if wchan_error != "" {
    "unavailable"
  } else if channel == "" || channel == "0" {
    "hidden_or_not_sleeping"
  } else {
    "available"
  }
  {
    pid,
    parent_pid,
    name: stat[open + 2:close].to_owned(),
    state: fields[0],
    start_ticks: start,
    wchan: channel,
    wchan_status: status,
  }
}

///|
fn process_map(frame : FrameWire) -> Map[Int32, ProcessInfo] raise LockError {
  if frame.processes.length() > 4096 {
    invalid(0, "process catalog exceeds 4096 entries")
  }
  let result : Map[Int32, ProcessInfo] = Map([])
  for p in frame.processes {
    let info = parse_process(p.stat, wchan=p.wchan, wchan_error=p.wchan_error)
    if result.contains(info.pid) {
      invalid(0, "duplicate PID in process catalog")
    }
    result[info.pid] = info
  }
  result
}

///|
fn task_members(
  catalog : Map[Int32, ProcessInfo],
  root : Int32,
) -> Array[ProcessInfo] raise LockError {
  let children : Map[Int32, Array[Int32]] = Map([])
  for pid, info in catalog {
    match children.get(info.parent_pid) {
      Some(list) => list.push(pid)
      None => children[info.parent_pid] = [pid]
    }
  }
  let queue = [root]
  let seen : Map[Int32, Bool] = Map([(root, true)])
  let result : Array[ProcessInfo] = []
  for i = 0; i < queue.length(); i = i + 1 {
    let pid = queue[i]
    if catalog.get(pid) is Some(info) {
      result.push(info)
    }
    if children.get(pid) is Some(list) {
      list.sort()
      for child in list {
        if seen.contains(child) {
          invalid(0, "cycle in task parent graph")
        }
        seen[child] = true
        queue.push(child)
        if queue.length() > 256 {
          invalid(0, "task tree exceeds 256 processes")
        }
      }
    }
  }
  result
}
