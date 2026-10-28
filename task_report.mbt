///|
fn frame_report(
  capture : TaskCapture,
  frame : FrameWire,
) -> TaskFrameReport raise LockError {
  let catalog = process_map(frame)
  let root = catalog.get(capture.root_pid)
  let root_state = match root {
    None => "not_observed"
    Some(p) =>
      if p.start_ticks != capture.start_ticks {
        "identity_changed"
      } else if frame.root_error != "" {
        "unavailable"
      } else {
        "present"
      }
  }
  let issues : Array[String] = []
  if !frame.catalog_complete {
    issues.push(
      "Process catalog was incomplete; descendant discovery may be partial.",
    )
  }
  if frame.root_error != "" {
    issues.push("Root read status: " + frame.root_error)
  }
  if frame.locks_error != "" {
    issues.push("Lock evidence unavailable: " + frame.locks_error)
  }
  let locks = parse(frame.locks)
  let processes : Array[TaskProcess] = []
  let members : Map[Int32, Bool] = Map([])
  let blocker_pids : Map[Int32, Bool] = Map([])
  if root_state == "present" {
    for p in task_members(catalog, capture.root_pid) {
      members[p.pid] = true
      let owned = locks.matching(pid=p.pid)
      let waiting = owned.filter(e => e.depth > 0)
      let context = locks.with_blockers(waiting.map(e => e.line))
      let blockers = context.filter(e => !waiting.any(w => w.line == e.line))
      let blocker_identities : Array[String] = []
      for e in blockers {
        if e.owner is Process(pid) {
          let id = match catalog.get(pid) {
            Some(owner) => process_identity(owner)
            None => "unobserved:\{pid}"
          }
          if !blocker_identities.contains(id) {
            blocker_identities.push(id)
          }
        }
      }
      blocker_identities.sort()
      for e in blockers {
        if e.owner is Process(pid) {
          blocker_pids[pid] = true
        }
      }
      let files : Array[FileKey] = []
      for e in owned {
        if e.file is Some(key) && !files.contains(key) {
          files.push(key)
        }
      }
      let finding = if !waiting.is_empty() {
        "confirmed_file_lock_wait"
      } else if frame.locks_error != "" {
        "lock_evidence_unavailable"
      } else if p.state == "Z" {
        "zombie"
      } else if p.state == "T" || p.state == "t" {
        "stopped_or_traced"
      } else if p.state == "S" || p.state == "D" || p.state == "I" {
        if p.wchan_status == "available" {
          "sleeping_wait_channel_hint"
        } else {
          "sleeping_reason_unknown"
        }
      } else if p.state == "R" {
        "runnable_progress_unknown"
      } else {
        "unclassified_process_state"
      }
      processes.push({
        info: p,
        finding,
        waiting_lines: waiting.map(e => e.line),
        requests: waiting,
        blockers,
        blocker_identities,
        files,
      })
    }
  }
  let blocker_processes : Array[ProcessInfo] = []
  for pid, _ in blocker_pids {
    if !members.contains(pid) {
      match catalog.get(pid) {
        Some(p) => blocker_processes.push(p)
        None =>
          issues.push(
            "Blocker PID \{pid} was not observable in the process catalog.",
          )
      }
    }
  }
  blocker_processes.sort_by((a, b) => a.pid.compare(b.pid))
  {
    elapsed_ms: nonnegative(frame.elapsed_ms, 0),
    root_state,
    processes,
    blocker_processes,
    issues,
  }
}

///|
fn process_identity(p : ProcessInfo) -> String {
  "\{p.pid}:\{p.start_ticks}"
}

///|
/// Source lines and ordinal IDs deliberately do not participate in continuity.
fn blocker_signature(process : TaskProcess) -> String {
  let parts = process.blockers.map(e => {
    let json : Json = {
      "kind": Json(e.kind),
      "owner": Json(e.owner),
      "file": Json(e.file),
      "range": Json(e.range),
      "mode": Json(e.mode),
      "state": e.state,
    }
    json.stringify()
  })
  parts.sort()
  process.blocker_identities.join(",") + ":" + parts.join("|")
}

///|
pub fn TaskCapture::report(self : TaskCapture) -> TaskReport raise LockError {
  if self.frames.is_empty() {
    invalid(0, "cannot report an empty task capture")
  }
  let frames = self.frames.map(frame => frame_report(self, frame))
  let transitions : Array[TaskTransition] = []
  let mut previous : Map[String, TaskProcess] = Map([])
  let mut streaks : Map[String, (Int32, Int64)] = Map([])
  let mut max_count = 0
  let mut max_span = 0L
  let next_steps : Array[String] = []
  for frame in frames {
    let current : Map[String, TaskProcess] = Map([])
    let next_streaks : Map[String, (Int32, Int64)] = Map([])
    for p in frame.processes {
      let identity = process_identity(p.info)
      current[identity] = p
      let prior = previous.get(identity)
      if prior is None {
        transitions.push({
          at_ms: frame.elapsed_ms,
          pid: p.info.pid,
          start_ticks: p.info.start_ticks,
          change: "first_observed",
          before: "",
          after: p.finding,
        })
      } else if prior is Some(old) && old.finding != p.finding {
        transitions.push({
          at_ms: frame.elapsed_ms,
          pid: p.info.pid,
          start_ticks: p.info.start_ticks,
          change: "finding_changed",
          before: old.finding,
          after: p.finding,
        })
      } else if prior is Some(old) &&
        blocker_signature(old) != blocker_signature(p) {
        transitions.push({
          at_ms: frame.elapsed_ms,
          pid: p.info.pid,
          start_ticks: p.info.start_ticks,
          change: "blocker_evidence_changed",
          before: old.finding,
          after: p.finding,
        })
      } else if prior is Some(old) &&
        (
          old.info.state != p.info.state ||
          old.info.wchan != p.info.wchan ||
          old.info.wchan_status != p.info.wchan_status
        ) {
        transitions.push({
          at_ms: frame.elapsed_ms,
          pid: p.info.pid,
          start_ticks: p.info.start_ticks,
          change: "wait_hint_changed",
          before: old.info.state + ":" + old.info.wchan,
          after: p.info.state + ":" + p.info.wchan,
        })
      }
      if p.finding == "confirmed_file_lock_wait" {
        let (count, start) = match streaks.get(identity) {
          Some((count, start)) => (count + 1, start)
          None => (1, frame.elapsed_ms)
        }
        next_streaks[identity] = (count, start)
        max_count = Int32::max(max_count, count)
        max_span = Int64::max(max_span, frame.elapsed_ms - start)
        let advice = "Inspect the recorded blocker PID and device/inode/range; verify the owner before taking action."
        if !next_steps.contains(advice) {
          next_steps.push(advice)
        }
      } else if p.finding == "sleeping_wait_channel_hint" ||
        p.finding == "sleeping_reason_unknown" {
        let advice = "A sleeping leader and wchan are clues only; inspect application progress, thread states and I/O evidence."
        if !next_steps.contains(advice) {
          next_steps.push(advice)
        }
      } else if p.finding == "zombie" || p.finding == "stopped_or_traced" {
        let advice = "Inspect the parent process and job-control/debugger state for zombie or stopped processes."
        if !next_steps.contains(advice) {
          next_steps.push(advice)
        }
      }
    }
    for identity, old in previous {
      if !current.contains(identity) {
        transitions.push({
          at_ms: frame.elapsed_ms,
          pid: old.info.pid,
          start_ticks: old.info.start_ticks,
          change: "not_observed",
          before: old.finding,
          after: "not_observed",
        })
      }
    }
    if frame.root_state != "present" || !frame.issues.is_empty() {
      let advice = "Review visibility/read errors and process identity; missing observations do not prove successful completion."
      if !next_steps.contains(advice) {
        next_steps.push(advice)
      }
    }
    previous = current
    streaks = next_streaks
  }
  if next_steps.is_empty() {
    next_steps.push(
      "No file-lock wait was confirmed in these samples; check application progress and logs.",
    )
  }
  {
    root_pid: self.root_pid,
    root_start_ticks: self.start_ticks,
    started_at: self.frames[0].captured_at,
    sample_count: frames.length(),
    observed_span_ms: frames.last().unwrap().elapsed_ms - frames[0].elapsed_ms,
    max_consecutive_wait_samples: max_count,
    max_sampled_wait_span_ms: max_span,
    frames,
    transitions,
    next_steps,
  }
}
