///|
fn invalid(line : Int32, reason : String) -> Unit raise LockError {
  raise Invalid(line~, reason~)
}

///|
/// Checked digit accumulation, including the full unsigned inode domain.
fn unsigned(
  text : String,
  base : UInt64,
  cap : UInt64,
  line : Int32,
) -> UInt64 raise LockError {
  if text.is_empty() {
    invalid(line, "empty integer")
  }
  let mut value = 0UL
  for c in text {
    let digit = match c {
      '0'..<='9' => (c.to_int() - 48).to_uint64()
      'a'..<='f' => (c.to_int() - 87).to_uint64()
      'A'..<='F' => (c.to_int() - 55).to_uint64()
      _ => {
        invalid(line, "invalid integer digit")
        0UL
      }
    }
    if digit >= base || digit > cap || value > (cap - digit) / base {
      invalid(line, "integer outside supported range")
    }
    value = value * base + digit
  }
  value
}

///|
fn nonnegative(text : String, line : Int32) -> Int64 raise LockError {
  unsigned(text, 10UL, 9223372036854775807UL, line).reinterpret_as_int64()
}

///|
fn parse_file(text : String, line : Int32) -> FileKey? raise LockError {
  if text == "<none>:0" {
    return None
  }
  let parts = text.split(":").map(x => x.to_owned()).collect()
  guard parts is [major, minor, inode] else {
    invalid(line, "expected hex-major:hex-minor:decimal-inode")
    return None
  }
  Some({
    major: unsigned(major, 16UL, 4294967295UL, line).to_uint(),
    minor: unsigned(minor, 16UL, 4294967295UL, line).to_uint(),
    inode: unsigned(inode, 10UL, 18446744073709551615UL, line),
  })
}

///|
pub fn file_key(text : String) -> FileKey raise LockError {
  match parse_file(text, 0) {
    Some(key) => key
    None => {
      invalid(0, "a concrete file identity is required")
      abort("unreachable")
    }
  }
}

///|
pub fn byte_range(start : String, end : String) -> ByteRange raise LockError {
  range_at(start, end, 0)
}

///|
fn range_at(
  start : String,
  end : String,
  line : Int32,
) -> ByteRange raise LockError {
  let first = nonnegative(start, line)
  let last = if end == "EOF" { None } else { Some(nonnegative(end, line)) }
  if last is Some(n) && n < first {
    invalid(line, "range end precedes start")
  }
  { start: first, end: last, }
}
