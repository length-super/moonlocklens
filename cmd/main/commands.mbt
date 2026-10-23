///|
fn run(options : Options) -> Int32 raise {
  let filtered = options.pid is Some(_) ||
    options.key is Some(_) ||
    options.file is Some(_) ||
    options.waiting
  match options.args {
    [] => {
      if filtered || options.fail_on_wait {
        raise Usage("a command is required; run moonlocklens --help")
      }
      help()
      return 0
    }
    ["help"] | ["--help"] => {
      help()
      return 0
    }
    ["--version"] => {
      println("MoonLockLens 0.2.0")
      return 0
    }
    ["inspect", path] => {
      if options.file is Some(_) {
        raise Usage("--file is for live input; use --key for a capture")
      }
      return inspect(@locks.parse(read_input(path)), options, options.key)
    }
    ["live"] => {
      if !is_linux() {
        fail("live requires Linux; use inspect for saved captures")
      }
      let key = match options.file {
        None => options.key
        Some(path) => {
          let result = path_key(path)
          if result[0] != "ok" {
            fail(result[1])
          }
          Some(@locks.file_key(result[1]))
        }
      }
      return inspect(@locks.parse(read_input("/proc/locks")), options, key)
    }
    ["capture", path] => {
      if filtered || options.fail_on_wait {
        raise Usage("capture accepts only output format options")
      }
      if !is_linux() {
        fail("capture requires Linux")
      }
      let raw = read_input("/proc/locks")
      let s = @locks.parse(raw)
      let error = save_new(path, raw)
      if error != "" {
        fail(error)
      }
      if options.json {
        let payload : Json = {
          "schema": "moonlocklens-capture/1",
          "path": path,
          "records": s.length(),
        }
        println(payload.stringify())
      } else {
        println(
          "Saved \{s.length()} records to \{safe(path)}. Replay: moonlocklens inspect FILE",
        )
      }
      return 0
    }
    ["chain", path, line] => {
      if filtered {
        raise Usage("filters are available for inspect/live")
      }
      let rows = @locks.parse(read_input(path)).wait_chain(
        positive_number(line),
      )
      if options.json {
        println(Json(rows).stringify())
      } else {
        println("Request -> immediate blocker -> root (source line numbers)")
        render_rows(rows, rows.map(e => e.line), tree=false)
      }
      return wait_exit(rows, options.fail_on_wait)
    }
    ["range", path, key, start, end] => {
      if filtered {
        raise Usage("filters are available for inspect/live")
      }
      let s = @locks.parse(read_input(path))
      let rows = s.query_range(cli_key(key), cli_range(start, end))
      if options.json {
        println(Json(rows).stringify())
      } else {
        println(
          "Inclusive byte-range intersections (not a lock-grant prediction)",
        )
        render_rows(rows, rows.map(e => e.line), tree=false)
      }
      return wait_exit(rows, options.fail_on_wait)
    }
    _ => raise Usage("invalid command or arguments; run moonlocklens --help")
  }
}

///|
fn wait_exit(rows : ArrayView[@locks.Entry], enabled : Bool) -> Int32 {
  if enabled && rows.any(e => e.depth > 0) {
    3
  } else {
    0
  }
}

///|
fn inspect(
  s : @locks.Snapshot,
  options : Options,
  file : @locks.FileKey?,
) -> Int32 raise {
  let matches = s.matching(
    pid?=options.pid,
    file?,
    waiting_only=options.waiting,
  )
  let lines = matches.map(e => e.line)
  let rows = s.with_blockers(lines)
  let visible : Map[Int32, Bool] = Map([])
  for e in rows {
    visible[e.line] = true
  }
  let bottlenecks = s.bottlenecks().filter(b => visible.contains(b.holder_line))
  if options.json {
    let payload : Json = {
      "schema": "moonlocklens/2",
      "observed_records": s.length(),
      "matching_records": matches.length(),
      "matched_lines": Json(lines),
      "entries": Json(rows),
      "bottlenecks": Json(bottlenecks),
    }
    println(payload.stringify())
  } else {
    println(
      "MoonLockLens | observed \{s.length()} | matched \{matches.length()} | shown with blockers \{rows.length()}",
    )
    render_rows(rows, lines, tree=true)
    for b in bottlenecks {
      println(
        "Root L\{b.holder_line}: \{b.direct_waiters} direct / \{b.total_waiters} total snapshot waiters",
      )
    }
    if !matches.is_empty() {
      println("* matching row; unmarked rows are blocker context")
    }
  }
  wait_exit(matches, options.fail_on_wait)
}
