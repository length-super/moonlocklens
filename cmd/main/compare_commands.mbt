///|
fn load_task(path : String) -> @locks.TaskCapture raise {
  let raw = read_task_text(path)
  if raw[0] != "ok" {
    raise HostError(raw[1])
  }
  @locks.parse_task_capture(raw[1])
}

///|
fn compare_command(options : Options) -> Int32 raise {
  if options.pid is Some(_) ||
    options.key is Some(_) ||
    options.file is Some(_) ||
    options.waiting ||
    options.fail_on_wait ||
    options.samples is Some(_) ||
    options.interval is Some(_) ||
    options.output is Some(_) {
    raise Usage("compare accepts two task captures and a format option")
  }
  guard options.args is ["compare", before, after] else {
    raise Usage("usage: compare BEFORE.json AFTER.json [--json | --markdown]")
  }
  if before == "-" && after == "-" {
    raise Usage("only one comparison input may use stdin")
  }
  let result = load_task(before).compare(load_task(after))
  if options.json {
    let payload : Json = {
      "schema": "moonlocklens-compare/1",
      "comparison": Json(result),
    }
    println(payload.stringify())
  } else {
    println(result.to_markdown())
  }
  0
}
