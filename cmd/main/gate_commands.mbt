///|
fn gate_command(options : Options) -> Int32 raise {
  if options.pid is Some(_) ||
    options.key is Some(_) ||
    options.file is Some(_) ||
    options.waiting ||
    options.fail_on_wait ||
    options.samples is Some(_) ||
    options.interval is Some(_) ||
    options.output is Some(_) {
    raise Usage("gate accepts a capture, --wait-samples and a format option")
  }
  guard options.args is ["gate", path] else {
    raise Usage("usage: gate CAPTURE.json [--wait-samples 2] [--json]")
  }
  let threshold = options.wait_samples.unwrap_or(2)
  if threshold > 60 {
    raise Usage("--wait-samples must be 1..60")
  }
  let raw = read_task_text(path)
  if raw[0] != "ok" {
    raise HostError(raw[1])
  }
  let result = @locks.assess_capture(raw[1], wait_samples=threshold)
  if options.json {
    let payload : Json = {
      "schema": "moonlocklens-gate/1",
      "assessment": Json(result),
    }
    println(payload.stringify())
  } else {
    if options.markdown {
      println("# Lock-wait assessment\n")
    }
    println("Gate \{result.status}: \{result.reason}")
    println(
      "Consecutive wait samples \{result.observed_streak}; threshold \{result.threshold_samples}; samples \{result.sample_count}; frames with evidence gaps \{result.evidence_gaps}.",
    )
  }
  match result.status {
    "pass" => 0
    "fail" => 3
    _ => 4
  }
}
