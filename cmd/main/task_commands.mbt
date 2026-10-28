///|
fn task_command(options : Options) -> Int32 raise {
  if options.pid is Some(_) ||
    options.key is Some(_) ||
    options.file is Some(_) ||
    options.waiting {
    raise Usage(
      "task commands take a root PID; inspect/live filters are not available",
    )
  }
  let capture = match options.args {
    ["report", path] => {
      if options.samples is Some(_) ||
        options.interval is Some(_) ||
        options.output is Some(_) {
        raise Usage(
          "report accepts only format and --fail-on-wait; redirect stdout to save a report",
        )
      }
      let r = read_task_text(path)
      if r[0] != "ok" {
        raise HostError(r[1])
      }
      @locks.parse_task_capture(r[1])
    }
    ["diagnose", pid] | ["watch", pid] => {
      let watching = options.args[0] == "watch"
      if !watching &&
        (
          options.samples is Some(_) ||
          options.interval is Some(_) ||
          options.output is Some(_)
        ) {
        raise Usage(
          "diagnose samples once; use watch to save a sampling session",
        )
      }
      if watching && options.output is None {
        raise Usage("watch requires --output NEW_CAPTURE.json")
      }
      let count = if watching { options.samples.unwrap_or(10) } else { 1 }
      let interval = options.interval.unwrap_or(500)
      if count < 1 || count > 60 || interval < 100 || interval > 5000 {
        raise Usage(
          "samples must be 1..60; interval must be 100..5000 milliseconds",
        )
      }
      let root = positive_number(pid)
      if !is_linux() {
        raise HostError(
          "diagnose/watch require Linux; report works with saved captures",
        )
      }
      let c = @locks.task_capture(root)
      let base = monotonic_ms()
      for i in 0..<count {
        if i > 0 {
          pause_ms(interval)
        }
        let raw = collect_task(root, base)
        if raw[0] != "ok" {
          raise HostError(raw[1])
        }
        c.record(raw[1])
        if watching && !options.json {
          task_progress("Collected sample \{i + 1}/\{count}")
        }
      }
      if options.output is Some(path) {
        let error = save_new(path, c.to_json().stringify())
        if error != "" {
          raise HostError(error)
        }
      }
      c
    }
    _ =>
      raise Usage(
        "usage: diagnose PID | watch PID --samples N --interval MS --output FILE | report FILE",
      )
  }
  let report = capture.report()
  if options.json {
    let payload : Json = {
      "schema": "moonlocklens-report/1",
      "report": Json(report),
    }
    println(payload.stringify())
  } else if options.markdown {
    println(report.to_markdown())
  } else {
    println(
      "MoonLockLens task PID \{report.root_pid}/\{report.root_start_ticks} | \{report.sample_count} samples | observed span \{report.observed_span_ms} ms",
    )
    println(
      "Max consecutive file-lock-wait samples: \{report.max_consecutive_wait_samples}; sampled span \{report.max_sampled_wait_span_ms} ms (gaps between samples are unobserved)",
    )
    for frame in report.frames {
      println("Sample +\{frame.elapsed_ms} ms | root \{frame.root_state}")
      for p in frame.processes {
        println(
          "  PID \{p.info.pid} parent=\{p.info.parent_pid} \{safe(p.info.name)} state=\{safe(p.info.state)}: \{p.finding}; wchan=\{safe(p.info.wchan)} (\{p.info.wchan_status})",
        )
        if !p.requests.is_empty() {
          render_rows(p.requests, p.waiting_lines, tree=false)
        }
        if !p.blockers.is_empty() {
          render_rows(p.blockers, [], tree=false)
        }
      }
      for issue in frame.issues {
        println("  Evidence gap: \{safe(issue)}")
      }
      for p in frame.blocker_processes {
        println(
          "  External blocker PID \{p.pid}/\{p.start_ticks}: \{safe(p.name)}",
        )
      }
    }
    println("Observed transitions:")
    for t in report.transitions {
      println(
        "  +\{t.at_ms} ms PID \{t.pid}/\{t.start_ticks}: \{t.change} \{safe(t.before)} -> \{safe(t.after)}",
      )
    }
    for advice in report.next_steps {
      println("Next check: \{advice}")
    }
    if options.output is Some(path) {
      println("Saved task capture: \{safe(path)}")
    }
  }
  if options.fail_on_wait && report.max_consecutive_wait_samples > 0 {
    3
  } else {
    0
  }
}
