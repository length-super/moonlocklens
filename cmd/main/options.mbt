///|
suberror Usage {
  Usage(String)
}

///|
suberror HostError {
  HostError(String)
}

///|
struct Options {
  args : Array[String]
  json : Bool
  markdown : Bool
  samples : Int32?
  interval : Int32?
  output : String?
  pid : Int32?
  key : @locks.FileKey?
  file : String?
  waiting : Bool
  fail_on_wait : Bool
}

///|
fn wants_json(args : ArrayView[String]) -> Bool {
  for arg in args {
    if arg == "--" {
      break
    }
    if arg == "--json" {
      return true
    }
  }
  false
}

///|
fn positive_number(text : String) -> Int32 raise {
  if text.is_empty() || !text.iter().all(c => c >= '0' && c <= '9') {
    raise Usage("expected a positive decimal integer: " + safe(text))
  }
  let n = @string.parse_int(text, base=10) catch {
    _ => raise Usage("decimal integer is too large")
  }
  if n <= 0 {
    raise Usage("integer must be positive")
  }
  n
}

///|
fn parse_options(input : ArrayView[String]) -> Options raise {
  let args : Array[String] = []
  let mut json = false
  let mut markdown = false
  let mut samples = None
  let mut interval = None
  let mut output = None
  let mut format_seen = false
  let mut pid = None
  let mut key = None
  let mut file = None
  let mut waiting = false
  let mut fail_on_wait = false
  let mut positional = false
  for i = 0; i < input.length(); {
    let arg = input[i]
    if positional {
      args.push(arg)
      continue i + 1
    }
    match arg {
      "--" => positional = true
      "--json" | "--text" | "--markdown" => {
        if format_seen {
          raise Usage("specify --json, --text or --markdown once")
        }
        json = arg == "--json"
        markdown = arg == "--markdown"
        format_seen = true
      }
      "--pid" | "--key" | "--file" => {
        if i + 1 >= input.length() {
          raise Usage("missing value for " + arg)
        }
        let value = input[i + 1]
        match arg {
          "--pid" => {
            if pid is Some(_) {
              raise Usage("duplicate --pid")
            }
            pid = Some(positive_number(value))
          }
          "--key" => {
            if key is Some(_) || file is Some(_) {
              raise Usage("use one --key or --file")
            }
            key = Some(cli_key(value))
          }
          _ => {
            if key is Some(_) || file is Some(_) {
              raise Usage("use one --key or --file")
            }
            file = Some(value)
          }
        }
        continue i + 2
      }
      "--waiting" => waiting = true
      "--samples" | "--interval" | "--output" => {
        if i + 1 >= input.length() {
          raise Usage("missing value for " + arg)
        }
        let value = input[i + 1]
        match arg {
          "--samples" => {
            if samples is Some(_) {
              raise Usage("duplicate --samples")
            }
            samples = Some(positive_number(value))
          }
          "--interval" => {
            if interval is Some(_) {
              raise Usage("duplicate --interval")
            }
            interval = Some(positive_number(value))
          }
          _ => {
            if output is Some(_) || value.is_empty() {
              raise Usage("invalid or duplicate --output")
            }
            output = Some(value)
          }
        }
        continue i + 2
      }
      "--fail-on-wait" => fail_on_wait = true
      _ => {
        if arg.has_prefix("--") && arg != "--help" && arg != "--version" {
          raise Usage("unknown option: " + safe(arg))
        }
        args.push(arg)
      }
    }
    continue i + 1
  }
  {
    args,
    json,
    markdown,
    samples,
    interval,
    output,
    pid,
    key,
    file,
    waiting,
    fail_on_wait,
  }
}

///|
fn help() -> Unit {
  let text =
    #|MoonLockLens 0.4.0 - Linux task wait and file-contention diagnostics
    #|
    #|  moonlocklens inspect FILE       Explain a saved /proc/locks capture
    #|  moonlocklens live               Inspect the current Linux procfs
    #|  moonlocklens capture OUTPUT     Save a new replay file (never overwrite)
    #|  moonlocklens chain FILE LINE    Trace one request to its root blocker
    #|  moonlocklens range FILE KEY START END_OR_EOF
    #|  moonlocklens diagnose PID       Inspect a task and current descendants
    #|  moonlocklens watch PID --samples 10 --interval 500 --output incident.json
    #|  moonlocklens report incident.json [--markdown | --json]
    #|  moonlocklens compare BEFORE.json AFTER.json [--json | --markdown]
    #|
    #|  FILE may be '-' for UTF-8 stdin; source LINE is 1-based.
    #|  KEY is hex-major:hex-minor:decimal-inode. Range endpoints are inclusive.
    #|  inspect/live filters: --pid PID, --key KEY, --waiting
    #|  live additionally accepts --file PATH (stat identity, follows symlinks).
    #|  Matching rows are marked '*'; their blockers are retained as context.
    #|  --json                    Machine-readable stdout (default is text)
    #|  --markdown                Markdown task incident report
    #|  --samples / --interval    watch: 1..60 samples, 100..5000 ms between collections
    #|  --fail-on-wait            Exit 3 if the selected records contain waiters
    #|  --                        End options, for filenames starting with '--'
    #|  Exit: 0 success / 1 input or I/O error / 2 usage / 3 observed waiters
    #|
    #|Examples:
    #|  moonlocklens inspect fixtures/contention.locks --pid 300
    #|  moonlocklens live --file /path/to/cache.lock --waiting
    #|  moonlocklens capture incident.locks
    #|  moonlocklens inspect incident.locks --json > report.json
  println(text)
}

///|
fn cli_key(text : String) -> @locks.FileKey raise {
  @locks.file_key(text) catch {
    @locks.LockError::Invalid(line=_, reason~) =>
      raise Usage("invalid file key: " + reason)
  }
}

///|
fn cli_range(start : String, end : String) -> @locks.ByteRange raise {
  @locks.byte_range(start, end) catch {
    @locks.LockError::Invalid(line=_, reason~) =>
      raise Usage("invalid byte range: " + reason)
  }
}
