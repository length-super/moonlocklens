///|
fn main {
  let args = Array::from_iter(arguments().iter())
  let json_errors = wants_json(args)
  let code = run(parse_options(args)) catch {
    Usage(message) => {
      report_error(message, None, json_errors)
      set_exit(2)
      return
    }
    @locks.LockError::Invalid(line~, reason~) => {
      report_error(reason, Some(line), json_errors)
      set_exit(1)
      return
    }
    HostError(message) => {
      report_error(message, None, json_errors)
      set_exit(1)
      return
    }
    e => {
      report_error(e.to_string(), None, json_errors)
      set_exit(1)
      return
    }
  }
  set_exit(code)
}
