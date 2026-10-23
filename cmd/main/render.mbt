///|
fn safe(text : String) -> String {
  String::from_iter(
    text
    .iter()
    .map(c => if c.to_int() < 32 || c.to_int() == 127 { '?' } else { c }),
  )
}

///|
fn owner_text(owner : @locks.Owner) -> String {
  match owner {
    Process(pid) => "PID \{pid}"
    OpenDescription => "OFD owner unknown"
    NotVisible => "PID not visible"
  }
}

///|
fn kind_text(kind : @locks.LockKind) -> String {
  match kind {
    Posix => "POSIX"
    Flock => "FLOCK"
    Ofd => "OFDLCK"
    Lease => "LEASE"
    Other(name) => safe(name)
  }
}

///|
fn mode_text(mode : @locks.LockMode) -> String {
  match mode {
    Read => "READ"
    Write => "WRITE"
    Unlock => "UNLCK"
    Other(name) => safe(name)
  }
}

///|
fn entry_text(e : @locks.Entry) -> String {
  let file = match e.file {
    Some(k) =>
      "\{k.major.to_string(radix=16)}:\{k.minor.to_string(radix=16)}:\{k.inode}"
    None => "<no inode>"
  }
  let end = match e.range.end {
    Some(n) => n.to_string()
    None => "EOF"
  }
  let parent = match e.parent_line {
    Some(line) => "waits for L\{line}"
    None => "root"
  }
  "L\{e.line} \{kind_text(e.kind)} \{mode_text(e.mode)} \{owner_text(e.owner)} file=\{file} bytes=\{e.range.start}..\{end} \{safe(e.state)} (\{parent})"
}

///|
fn render_rows(
  rows : ArrayView[@locks.Entry],
  matches : ArrayView[Int32],
  tree~ : Bool,
) -> Unit {
  if rows.is_empty() {
    println("No matching locks.")
    return
  }
  let selected : Map[Int32, Bool] = Map([])
  for line in matches {
    selected[line] = true
  }
  for e in rows {
    let mark = if selected.contains(e.line) { "*" } else { " " }
    let indent = if tree { String::make(e.depth * 2, ' ') } else { "" }
    println("\{mark} \{indent}\{entry_text(e)}")
  }
}

///|
fn report_error(message : String, line : Int32?, json : Bool) -> Unit {
  if json {
    let number : Json = match line {
      Some(n) => Json(n)
      None => Json::null()
    }
    let payload : Json = { "error": { "message": message, "line": number } }
    stderr(payload.stringify())
  } else {
    let prefix = match line {
      Some(n) => "locks line \{n}: "
      None => "moonlocklens: "
    }
    stderr(prefix + safe(message))
  }
}
