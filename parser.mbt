///|
fn words(text : String) -> Array[String] {
  text.split(" ").filter(x => !x.is_empty()).map(x => x.to_owned()).collect()
}

///|
/// Parse Linux's space-indented, preorder /proc/locks output.
/// max_chars limits UTF-16 units before tokenization; limits must be positive.
pub fn parse(
  text : String,
  max_chars~ : Int32 = 4194304,
  max_records~ : Int32 = 10000,
  max_depth~ : Int32 = 64,
) -> Snapshot raise LockError {
  if max_chars <= 0 || max_records <= 0 || max_depth <= 0 {
    invalid(0, "limits must be positive")
  }
  if text.length() > max_chars {
    invalid(0, "input character budget exceeded")
  }
  let records : Array[Entry] = []
  let parents : Array[Int32?] = []
  let stack : Array[Int32] = []
  let roots : Map[Int64, Bool] = Map([])
  let mut line_no = 0
  for raw in text.split("\n") {
    line_no += 1
    let line = raw.trim_end(chars="\r").to_owned()
    if line.is_empty() {
      continue
    }
    if records.length() >= max_records {
      invalid(line_no, "record budget exceeded")
    }
    if line.contains("\t") {
      invalid(line_no, "tabs cannot encode kernel wait depth")
    }
    guard line.find(":") is Some(colon) else {
      invalid(line_no, "missing ordinal colon")
      continue
    }
    let ordinal = nonnegative(line[:colon].to_owned(), line_no)
    if ordinal == 0L {
      invalid(line_no, "ordinal must be positive")
    }
    let tail = line[colon + 1:].to_owned()
    let mut spaces = 0
    for c in tail {
      if c != ' ' {
        break
      }
      spaces += 1
    }
    if spaces == 0 {
      invalid(line_no, "missing space after ordinal")
    }
    let body = tail[spaces:].to_owned()
    let blocked = body.has_prefix("-> ")
    let depth = if blocked { spaces } else { 0 }
    if depth > max_depth {
      invalid(line_no, "wait depth budget exceeded")
    }
    let fields = words(if blocked { body[3:].to_owned() } else { body })
    guard fields is [kind_text, state, mode_text, pid, file, start, end] else {
      invalid(line_no, "expected seven lock fields after ordinal/arrow")
      continue
    }
    let kind = match kind_text {
      "POSIX" => Posix
      "FLOCK" => Flock
      "OFDLCK" => Ofd
      "LEASE" => Lease
      _ => Other(kind_text)
    }
    let mode = match mode_text {
      "READ" => Read
      "WRITE" => Write
      "UNLCK" => Unlock
      _ => Other(mode_text)
    }
    let owner = if pid == "-1" {
      OpenDescription
    } else {
      let n = unsigned(pid, 10UL, 2147483647UL, line_no).to_int()
      if n == 0 {
        NotVisible
      } else {
        Process(n)
      }
    }
    let parent = if blocked {
      if depth > stack.length() {
        invalid(line_no, "orphan waiter or skipped wait depth")
      }
      let index = stack[depth - 1]
      if records[index].ordinal != ordinal {
        invalid(line_no, "waiter ordinal differs from its tree")
      }
      Some(index)
    } else {
      if roots.contains(ordinal) {
        invalid(line_no, "duplicate root ordinal")
      }
      roots[ordinal] = true
      None
    }
    let entry : Entry = {
      line: line_no,
      ordinal,
      depth,
      kind,
      state,
      mode,
      owner,
      file: parse_file(file, line_no),
      range: range_at(start, end, line_no),
      parent_line: parent.map(i => records[i].line),
    }
    // The next sibling replaces this stack slot; ancestors remain intact.
    while stack.length() > depth {
      ignore(stack.pop())
    }
    stack.push(records.length())
    records.push(entry)
    parents.push(parent)
  }
  { records, parents, }
}
