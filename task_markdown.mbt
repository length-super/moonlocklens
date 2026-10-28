///|
fn md(text : String) -> String {
  let mut result = ""
  for c in text {
    if c.to_int() < 32 || c.to_int() == 127 {
      result += " "
    } else {
      match c {
        '<' => result += "&lt;"
        '>' => result += "&gt;"
        '&' => result += "&amp;"
        '|' | '`' | '[' | ']' | '*' | '_' | '\\' =>
          result += "\\" + c.to_string()
        _ => result += c.to_string()
      }
    }
  }
  result
}

///|
pub fn TaskReport::to_markdown(self : TaskReport) -> String {
  let mut out = "# MoonLockLens task incident\n\nRoot PID: \{self.root_pid}; start ticks: \{self.root_start_ticks}.\n\nCaptured at: \{md(self.started_at)}. Samples: \{self.sample_count}; observed span: \{self.observed_span_ms} ms.\n\nMaximum consecutive samples with a confirmed file-lock wait: \{self.max_consecutive_wait_samples}; sampled span: \{self.max_sampled_wait_span_ms} ms. This does not prove an uninterrupted wait between samples.\n\n"
  for frame in self.frames {
    out += "## Sample +\{frame.elapsed_ms} ms - \{frame.root_state}\n\n"
    out += "| PID / start | Parent | Name | Leader state | Finding | Wait channel |\n|---|---|---|---|---|---|\n"
    for p in frame.processes {
      out += "| \{p.info.pid} / \{p.info.start_ticks} | \{p.info.parent_pid} | \{md(p.info.name)} | \{md(p.info.state)} | \{p.finding} | \{md(p.info.wchan)} (\{p.info.wchan_status}) |\n"
    }
    out += "\n"
    for p in frame.processes {
      for request in p.requests {
        let parent = match request.parent_line {
          Some(line) => "L\{line}"
          None => "unavailable"
        }
        out += "- Process \{p.info.pid}: request L\{request.line}, direct blocker \{parent}.\n"
      }
      for b in p.blockers {
        let key = match b.file {
          Some(k) =>
            "\{k.major.to_string(radix=16)}:\{k.minor.to_string(radix=16)}:\{k.inode}"
          None => "no inode"
        }
        let end = match b.range.end {
          Some(n) => n.to_string()
          None => "EOF"
        }
        let owner = match b.owner {
          Process(pid) => "PID \{pid}"
          OpenDescription => "OFD owner unknown"
          NotVisible => "PID not visible"
        }
        let parent = match b.parent_line {
          Some(line) => "waits for L\{line}"
          None => "root blocker"
        }
        out += "\n- Process \{p.info.pid}: blocker context L\{b.line}, \{owner}, file \{key}, bytes \{b.range.start}..\{end}, \{parent}.\n"
      }
    }
    out += "\n"
    for p in frame.blocker_processes {
      out += "- External blocker process: PID \{p.pid}, \{md(p.name)}, start \{p.start_ticks}.\n"
    }
    for issue in frame.issues {
      out += "- Evidence gap: \{md(issue)}\n"
    }
    out += "\n"
  }
  out += "## Observed transitions\n\n"
  for t in self.transitions {
    out += "- +\{t.at_ms} ms: PID \{t.pid}/\{t.start_ticks}, \{t.change}: \{md(t.before)} -> \{md(t.after)}.\n"
  }
  out += "\n## Next checks\n\n"
  for advice in self.next_steps {
    out += "- \{advice}\n"
  }
  out +
  "\nScope: visible procfs, process leaders and current descendants. No thread-wide root-cause or deadlock claim; snapshot collection is not atomic.\n"
}
