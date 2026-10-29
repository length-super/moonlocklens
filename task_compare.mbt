///|
pub(all) struct TaskChange {
  pid : Int32
  start_ticks : String
  change : String
  before : String
  after : String
} derive(ToJson)

///|
pub(all) struct TaskComparison {
  root_pid : Int32
  root_start_ticks : String
  evidence_complete : Bool
  before_waiters : Int32
  after_waiters : Int32
  resolved_lock_waits : Int32
  new_lock_waits : Int32
  changes : Array[TaskChange]
  issues : Array[String]
} derive(ToJson)

///|
pub extend TaskChange with ToJson::{to_json}

///|
pub extend TaskComparison with ToJson::{to_json}

///|
/// Compare the final observations of the same task in two saved sessions.
/// Missing identities are observations, never proof of successful completion.
pub fn TaskCapture::compare(
  self : TaskCapture,
  after : TaskCapture,
) -> TaskComparison raise LockError {
  if self.frames.is_empty() || after.frames.is_empty() {
    invalid(0, "comparison requires two nonempty task captures")
  }
  if self.boot_id != after.boot_id ||
    self.pid_namespace != after.pid_namespace ||
    self.root_pid != after.root_pid ||
    self.start_ticks != after.start_ticks {
    invalid(
      0, "comparison requires the same boot, procfs scope and root PID/starttime",
    )
  }
  let before = self.report().frames.last().unwrap()
  let latest = after.report().frames.last().unwrap()
  let complete = before.root_state == "present" &&
    latest.root_state == "present" &&
    before.issues.is_empty() &&
    latest.issues.is_empty()
  let issues = before.issues.map(s => "Before: " + s)
  for issue in latest.issues {
    issues.push("After: " + issue)
  }
  if before.root_state != "present" || latest.root_state != "present" {
    issues.push(
      "Root observations are incomplete; disappearance does not prove completion.",
    )
  }
  let prior : Map[String, TaskProcess] = Map([])
  let current : Map[String, Bool] = Map([])
  for p in before.processes {
    prior[process_identity(p.info)] = p
  }
  let changes : Array[TaskChange] = []
  let mut resolved = 0
  let mut new_waits = 0
  for p in latest.processes {
    let id = process_identity(p.info)
    current[id] = true
    let old = prior.get(id)
    let change = match old {
      None => "newly_observed"
      Some(old) =>
        if old.finding != p.finding {
          "finding_changed"
        } else if blocker_signature(old) != blocker_signature(p) {
          "blocker_evidence_changed"
        } else if old.info.state != p.info.state ||
          old.info.wchan != p.info.wchan ||
          old.info.wchan_status != p.info.wchan_status {
          "wait_hint_changed"
        } else {
          ""
        }
    }
    if complete && old is Some(old) {
      if old.finding == "confirmed_file_lock_wait" &&
        p.finding != "confirmed_file_lock_wait" {
        resolved += 1
      }
      if old.finding != "confirmed_file_lock_wait" &&
        p.finding == "confirmed_file_lock_wait" {
        new_waits += 1
      }
    }
    if change != "" {
      changes.push({
        pid: p.info.pid,
        start_ticks: p.info.start_ticks,
        change,
        before: old.map(v => v.finding).unwrap_or("not_observed"),
        after: p.finding,
      })
    }
  }
  for p in before.processes {
    if !current.contains(process_identity(p.info)) {
      changes.push({
        pid: p.info.pid,
        start_ticks: p.info.start_ticks,
        change: "not_observed",
        before: p.finding,
        after: "not_observed",
      })
    }
  }
  {
    root_pid: self.root_pid,
    root_start_ticks: self.start_ticks,
    evidence_complete: complete,
    before_waiters: before.processes
    .filter(p => p.finding == "confirmed_file_lock_wait")
    .length(),
    after_waiters: latest.processes
    .filter(p => p.finding == "confirmed_file_lock_wait")
    .length(),
    resolved_lock_waits: resolved,
    new_lock_waits: new_waits,
    changes,
    issues,
  }
}

///|
pub fn TaskComparison::to_markdown(self : TaskComparison) -> String {
  let mut out = "# Task observation comparison\n\nRoot PID \{self.root_pid}/\{self.root_start_ticks}. Final observed waiters: \{self.before_waiters} -> \{self.after_waiters}.\n\nSame-identity lock waits no longer observed: \{self.resolved_lock_waits}; newly observed waits in previously seen processes: \{self.new_lock_waits}. Evidence complete: \{self.evidence_complete}.\n\n| PID / start | Change | Before | After |\n|---|---|---|---|\n"
  for c in self.changes {
    out += "| \{c.pid}/\{c.start_ticks} | \{c.change} | \{c.before} | \{c.after} |\n"
  }
  for issue in self.issues {
    out += "\n- \{md(issue)}\n"
  }
  out +
  "\nComparison uses each session's final sample, not whole-window maxima. Labels before/after follow argument order, not a claim about wall-clock ordering. Missing processes do not prove completion; intervals between samples remain unobserved.\n"
}
