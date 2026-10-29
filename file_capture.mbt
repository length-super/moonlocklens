///|
priv struct FileFrameWire {
  elapsed_ms : String
  boot_id : String
  pid_namespace : String
  captured_at : String
  file_key : String
  file_error : String
  locks : String
  locks_error : String
} derive(@json.FromJson, ToJson)

///|
priv struct FileCaptureWire {
  schema : String
  frames : Array[FileFrameWire]
} derive(@json.FromJson, ToJson)

///|
pub struct FileCapture {
  priv frames : Array[FileFrameWire]
  priv mut stored_chars : Int32
}

///|
pub(all) struct FileFrameReport {
  elapsed_ms : Int64
  path_state : String
  waiting_records : Int32
  entries : Array[Entry]
  issues : Array[String]
} derive(ToJson)

///|
pub(all) struct FileReport {
  file : FileKey
  sample_count : Int32
  observed_span_ms : Int64
  peak_waiting_records : Int32
  max_consecutive_wait_samples : Int32
  frames : Array[FileFrameReport]
} derive(ToJson)

///|
pub extend FileFrameReport with ToJson::{to_json}

///|
pub extend FileReport with ToJson::{to_json}

///|
pub fn file_capture() -> FileCapture {
  { frames: [], stored_chars: 0, }
}

///|
pub fn FileCapture::record(
  self : FileCapture,
  raw : String,
) -> Unit raise LockError {
  let frame : FileFrameWire = @json.from_json(task_json(raw)) catch {
    _ => {
      invalid(0, "invalid file capture frame")
      abort("unreachable")
    }
  }
  self.add_file_frame(frame)
}

///|
fn FileCapture::add_file_frame(
  self : FileCapture,
  frame : FileFrameWire,
) -> Unit raise LockError {
  if self.frames.length() >= 60 {
    invalid(0, "file capture exceeds 60 samples")
  }
  if frame.boot_id.is_empty() ||
    frame.boot_id.length() > 128 ||
    frame.pid_namespace.is_empty() ||
    frame.pid_namespace.length() > 128 ||
    frame.captured_at.length() > 64 ||
    frame.file_error.length() > 256 ||
    frame.locks_error.length() > 256 {
    invalid(0, "invalid file capture scope or metadata")
  }
  let elapsed = nonnegative(frame.elapsed_ms, 0)
  if self.frames.last() is Some(previous) {
    if elapsed <= nonnegative(previous.elapsed_ms, 0) {
      invalid(0, "sample elapsed times must strictly increase")
    }
    if frame.boot_id != previous.boot_id ||
      frame.pid_namespace != previous.pid_namespace {
      invalid(0, "boot/procfs scope changed within file capture")
    }
  }
  let current = if frame.file_key == "" {
    None
  } else {
    Some(file_key(frame.file_key))
  }
  if current is None && frame.file_error == "" {
    invalid(0, "missing file identity without read status")
  }
  if self.frames.is_empty() && (current is None || frame.file_error != "") {
    invalid(0, "file must be observable in the first sample")
  }
  let key = match self.frames.get(0) {
    Some(first) => file_key(first.file_key)
    None => current.unwrap()
  }
  let snapshot = if frame.locks_error == "" {
    parse(frame.locks)
  } else {
    parse("")
  }
  let matched = snapshot.matching(file=key)
  let saved = {
    ..frame,
    locks: snapshot
    .with_blockers(matched.map(e => e.line))
    .map(proc_line)
    .join("\n"),
  }
  let size = Json(saved).stringify().length()
  if self.stored_chars > 16000000 - size {
    invalid(0, "file capture storage budget exceeded")
  }
  self.frames.push(saved)
  self.stored_chars += size
}

///|
pub fn FileCapture::to_json(self : FileCapture) -> Json {
  Json(FileCaptureWire::{ schema: "moonlocklens-file/1", frames: self.frames, })
}

///|
pub fn parse_file_capture(text : String) -> FileCapture raise LockError {
  let wire : FileCaptureWire = @json.from_json(task_json(text)) catch {
    _ => {
      invalid(0, "invalid file capture schema")
      abort("unreachable")
    }
  }
  if wire.schema != "moonlocklens-file/1" || wire.frames.is_empty() {
    invalid(0, "unsupported or empty file capture")
  }
  let capture = file_capture()
  for frame in wire.frames {
    capture.add_file_frame(frame)
  }
  capture
}

///|
pub fn FileCapture::report(self : FileCapture) -> FileReport raise LockError {
  guard self.frames.get(0) is Some(first) else {
    invalid(0, "cannot report an empty file capture")
    abort("unreachable")
  }
  let key = file_key(first.file_key)
  let mut peak = 0
  let mut streak = 0
  let mut max_streak = 0
  let frames = self.frames.map(frame => {
    let entries = parse(frame.locks).entries()
    let waiting = entries
      .filter(e => e.file == Some(key) && e.depth > 0)
      .length()
    peak = Int32::max(peak, waiting)
    streak = if waiting > 0 { streak + 1 } else { 0 }
    max_streak = Int32::max(max_streak, streak)
    let path_state = if frame.file_key != "" && file_key(frame.file_key) != key {
      "identity_changed"
    } else if frame.file_error != "" {
      "unavailable"
    } else {
      "present"
    }
    let issues : Array[String] = []
    if path_state == "identity_changed" {
      issues.push(
        "Path now names a different device/inode; this report continues to track the original file identity.",
      )
    }
    if frame.file_error != "" {
      issues.push("Path read status: " + frame.file_error)
    }
    if frame.locks_error != "" {
      issues.push("Lock evidence unavailable: " + frame.locks_error)
    }
    FileFrameReport::{
      elapsed_ms: nonnegative(frame.elapsed_ms, 0),
      path_state,
      waiting_records: waiting,
      entries,
      issues,
    }
  })
  {
    file: key,
    sample_count: frames.length(),
    observed_span_ms: frames.last().unwrap().elapsed_ms - frames[0].elapsed_ms,
    peak_waiting_records: peak,
    max_consecutive_wait_samples: max_streak,
    frames,
  }
}

///|
pub fn FileReport::to_markdown(self : FileReport) -> String {
  let mut out = "# File contention observations\n\nFile \{self.file.major.to_string(radix=16)}:\{self.file.minor.to_string(radix=16)}:\{self.file.inode}. Samples: \{self.sample_count}; observed span: \{self.observed_span_ms} ms. Peak waiting records: \{self.peak_waiting_records}; consecutive wait samples: \{self.max_consecutive_wait_samples}.\n\n"
  for frame in self.frames {
    out += "## Sample +\{frame.elapsed_ms} ms - \{frame.path_state}\n\n"
    for e in frame.entries {
      let parent = match e.parent_line {
        Some(line) => "; waits for L\{line}"
        None => "; root record"
      }
      out += "- L\{e.line}: \{md(proc_line(e))}\{parent}\n"
    }
    if frame.entries.is_empty() {
      out += "No lock records observed for the original file.\n"
    }
    for issue in frame.issues {
      out += "\nEvidence gap: \{md(issue)}\n"
    }
    out += "\n"
  }
  out +
  "OFD owner -1 remains unknown; records are not unique process counts. Sampling gaps and absence of lock records do not prove application completion.\n"
}
