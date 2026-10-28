///|
pub fn task_capture(pid : Int32) -> TaskCapture raise LockError {
  if pid <= 0 {
    invalid(0, "root PID must be positive")
  }
  {
    root_pid: pid,
    start_ticks: "",
    boot_id: "",
    pid_namespace: "",
    frames: [],
    stored_chars: 0,
  }
}

///|
fn read_frame(value : Json) -> FrameWire raise LockError {
  @json.from_json(value) catch {
    _ => {
      invalid(0, "invalid task frame schema")
      abort("unreachable")
    }
  }
}

///|
fn task_json(text : String) -> Json raise LockError {
  if text.length() > 16777216 {
    invalid(0, "task input exceeds 16 MiB character budget")
  }
  @json.parse(text) catch {
    _ => {
      invalid(0, "invalid task JSON")
      abort("unreachable")
    }
  }
}

///|
fn proc_line(e : Entry) -> String {
  let kind = match e.kind {
    Posix => "POSIX"
    Flock => "FLOCK"
    Ofd => "OFDLCK"
    Lease => "LEASE"
    Other(s) => s
  }
  let mode = match e.mode {
    Read => "READ"
    Write => "WRITE"
    Unlock => "UNLCK"
    Other(s) => s
  }
  let pid = match e.owner {
    Process(p) => p.to_string()
    OpenDescription => "-1"
    NotVisible => "0"
  }
  let file = match e.file {
    Some(k) =>
      "\{k.major.to_string(radix=16)}:\{k.minor.to_string(radix=16)}:\{k.inode}"
    None => "<none>:0"
  }
  let end = match e.range.end {
    Some(n) => n.to_string()
    None => "EOF"
  }
  let prefix = if e.depth == 0 {
    " "
  } else {
    String::make(e.depth, ' ') + "-> "
  }
  "\{e.ordinal}:\{prefix}\{kind} \{e.state} \{mode} \{pid} \{file} \{e.range.start} \{end}"
}

///|
/// A frame is normalized to the selected task and its observed lock blockers.
/// No unrelated process catalog or unrelated lock tree is retained in the capture.
pub fn TaskCapture::record(
  self : TaskCapture,
  raw : String,
) -> Unit raise LockError {
  let frame = read_frame(task_json(raw))
  self.add_frame(frame)
}

///|
fn TaskCapture::add_frame(
  self : TaskCapture,
  frame : FrameWire,
) -> Unit raise LockError {
  if self.frames.length() >= 60 {
    invalid(0, "task capture exceeds 60 samples")
  }
  if frame.boot_id.is_empty() ||
    frame.boot_id.length() > 128 ||
    frame.pid_namespace.is_empty() ||
    frame.pid_namespace.length() > 128 ||
    frame.captured_at.length() > 64 ||
    frame.root_error.length() > 256 ||
    frame.locks_error.length() > 256 {
    invalid(0, "invalid capture scope or metadata")
  }
  let elapsed = nonnegative(frame.elapsed_ms, 0)
  if self.frames.last() is Some(previous) &&
    elapsed <= nonnegative(previous.elapsed_ms, 0) {
    invalid(0, "sample elapsed times must strictly increase")
  }
  let catalog = process_map(frame)
  let root = catalog.get(self.root_pid)
  if frame.root_error == "" {
    guard root is Some(before) else {
      invalid(0, "root is absent without a read status")
      return
    }
    let after = parse_process(frame.root_after)
    if after.pid != before.pid || after.start_ticks != before.start_ticks {
      invalid(0, "root identity changed during sample collection")
    }
  }
  if self.frames.is_empty() {
    guard root is Some(info) else {
      invalid(0, "root process is not observable in first sample")
      return
    }
    if frame.root_error != "" {
      invalid(0, "root process changed or could not be read")
    }
    self.start_ticks = info.start_ticks
    self.boot_id = frame.boot_id
    self.pid_namespace = frame.pid_namespace
  }
  if frame.boot_id != self.boot_id || frame.pid_namespace != self.pid_namespace {
    invalid(0, "boot/PID namespace changed within task capture")
  }
  let keep : Map[Int32, Bool] = Map([])
  let valid_root = root is Some(info) &&
    info.start_ticks == self.start_ticks &&
    frame.root_error == ""
  if valid_root {
    for info in task_members(catalog, self.root_pid) {
      keep[info.pid] = true
    }
  } else if root is Some(_) {
    keep[self.root_pid] = true
  }
  let snapshot = if frame.locks_error == "" {
    parse(frame.locks)
  } else {
    parse("")
  }
  let lines : Array[Int32] = []
  for e in snapshot.entries() {
    if e.owner is Process(p) && keep.contains(p) && valid_root && e.depth > 0 {
      lines.push(e.line)
    }
  }
  // Include task-held locks as evidence as well as requests and their blockers.
  for e in snapshot.entries() {
    if e.owner is Process(p) && keep.contains(p) && valid_root {
      lines.push(e.line)
    }
  }
  let relevant = snapshot.with_blockers(lines)
  for e in relevant {
    if e.owner is Process(p) {
      keep[p] = true
    }
  }
  let normalized : Array[ProcWire] = []
  for p in frame.processes {
    if keep.contains(parse_process(p.stat).pid) {
      normalized.push(p)
    }
  }
  let locks = relevant.map(proc_line).join("\n")
  let saved = { ..frame, processes: normalized, locks, }
  let size = Json(saved).stringify().length()
  if self.stored_chars > 16000000 - size {
    invalid(0, "task capture storage budget exceeded")
  }
  self.frames.push(saved)
  self.stored_chars += size
}

///|
pub fn TaskCapture::sample_count(self : TaskCapture) -> Int32 {
  self.frames.length()
}

///|
pub fn TaskCapture::to_json(self : TaskCapture) -> Json {
  Json(CaptureWire::{
    schema: "moonlocklens-task/1",
    root_pid: self.root_pid,
    frames: self.frames,
  })
}

///|
pub fn parse_task_capture(text : String) -> TaskCapture raise LockError {
  let wire : CaptureWire = @json.from_json(task_json(text)) catch {
    _ => {
      invalid(0, "invalid task capture schema")
      abort("unreachable")
    }
  }
  if wire.schema != "moonlocklens-task/1" || wire.frames.is_empty() {
    invalid(0, "unsupported or empty task capture")
  }
  let result = task_capture(wire.root_pid)
  for frame in wire.frames {
    result.add_frame(frame)
  }
  result
}
