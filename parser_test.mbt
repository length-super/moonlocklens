///|
fn rejected(text : String, line : Int32) -> Unit raise {
  let error = @moonlocklens.parse(text) catch {
    @moonlocklens.LockError::Invalid(line=l, reason=_) => {
      assert_eq(l, line)
      return
    }
  }
  fail("unexpectedly parsed \{error.length()} rows")
}

///|
fn error_line(f : () -> Unit raise @moonlocklens.LockError) -> Int32 {
  f() catch {
    @moonlocklens.LockError::Invalid(line~, reason=_) => return line
  }
  -100
}

///|
test "parse all lock families and preserve kernel metadata" {
  let text =
    #|1: POSIX ADVISORY READ 12 08:Af:18446744073709551615 0 0
    #|2: FLOCK ADVISORY WRITE 13 00:01:4 0 EOF
    #|3: OFDLCK ADVISORY WRITE -1 00:01:5 7 EOF
    #|4: LEASE BREAKING UNLCK 14 00:01:6 0 EOF
    #|5: ACCESS *NOINODE* READ 0 <none>:0 10 20
    #|6: FUTURE UNKNOWN CUSTOM 15 00:02:7 0 EOF
  let s = @moonlocklens.parse(text)
  assert_eq(s.length(), 6)
  assert_eq(
    s.entry(1).file,
    Some(@moonlocklens.file_key("8:af:18446744073709551615")),
  )
  assert_eq(s.entry(3).owner, @moonlocklens.OpenDescription)
  assert_eq(s.entry(4).state, "BREAKING")
  assert_eq(s.entry(4).mode, @moonlocklens.Unlock)
  assert_eq(s.entry(5).file, None)
  assert_eq(s.entry(5).owner, @moonlocklens.NotVisible)
  assert_eq(s.entry(6).kind, @moonlocklens.LockKind::Other("FUTURE"))
  assert_eq(s.entry(6).mode, @moonlocklens.LockMode::Other("CUSTOM"))
}

///|
test "empty input, CRLF, blank line and missing final newline" {
  assert_eq(@moonlocklens.parse("").length(), 0)
  let s = @moonlocklens.parse(
    "\r\n1: POSIX ADVISORY READ 1 00:01:1 0 EOF\r\n\n2: FLOCK ADVISORY WRITE 2 00:01:2 0 EOF",
  )
  assert_eq(s.length(), 2)
  assert_eq(s.entry(2).line, 2)
  assert_eq(s.entry(4).line, 4)
}

///|
test "integer and field errors have source lines" {
  for
    text in [
      "0: POSIX ADVISORY READ 1 00:01:1 0 EOF", "-1: POSIX ADVISORY READ 1 00:01:1 0 EOF",
      "1: POSIX ADVISORY READ -2 00:01:1 0 EOF", "1: POSIX ADVISORY READ 2147483648 00:01:1 0 EOF",
      "1: POSIX ADVISORY READ 1 100000000:01:1 0 EOF", "1: POSIX ADVISORY READ 1 00:01:18446744073709551616 0 EOF",
      "1: POSIX ADVISORY READ 1 00:01:1 9223372036854775808 EOF", "1: POSIX ADVISORY READ 1 00:01:1 9 8",
      "1: POSIX ADVISORY READ 1 00:01:1 -1 EOF", "1: POSIX ADVISORY READ 1 00:01:1 EOF EOF",
      "1: POSIX ADVISORY READ 1 00:01:1 0 EOF extra", "1: POSIX ADVISORY READ 1 00:01 0 EOF",
      "1: POSIX ADVISORY READ 1 00:gg:1 0 EOF", "1: POSIX ADVISORY READ 1 00:01: 0 EOF",
      "1:POSIX ADVISORY READ 1 00:01:1 0 EOF", "1:\tPOSIX ADVISORY READ 1 00:01:1 0 EOF",
      "garbage", "🦀: POSIX ADVISORY READ 1 00:01:1 0 EOF",
    ] {
    rejected(text, 1)
  }
}

///|
test "bad tree shape is rejected rather than flattened" {
  rejected("1: -> POSIX ADVISORY WRITE 2 00:01:1 0 EOF", 1)
  let root = "1: POSIX ADVISORY WRITE 1 00:01:1 0 EOF\n"
  rejected(root + "1:  -> POSIX ADVISORY WRITE 2 00:01:1 0 EOF", 2)
  rejected(root + "2: -> POSIX ADVISORY WRITE 2 00:01:1 0 EOF", 2)
  rejected(root + "1: POSIX ADVISORY WRITE 2 00:01:1 0 EOF", 2)
  rejected(root + "1: ->-> POSIX ADVISORY WRITE 2 00:01:1 0 EOF", 2)
}

///|
test "limits are enforced before accepting input" {
  let row = "1: POSIX ADVISORY WRITE 1 00:01:1 0 EOF"
  let a = error_line(() => ignore(@moonlocklens.parse(row, max_chars=1)))
  assert_eq(a, 0)
  let b = error_line(() => {
    ignore(
      @moonlocklens.parse(
        row + "\n2: FLOCK ADVISORY READ 2 00:01:2 0 EOF",
        max_records=1,
      ),
    )
  })
  assert_eq(b, 2)
  let c = error_line(() => ignore(@moonlocklens.parse(row, max_depth=0)))
  assert_eq(c, 0)
  let d = error_line(() => {
    ignore(
      @moonlocklens.parse(
        row +
        "\n1: -> POSIX ADVISORY WRITE 2 00:01:1 0 EOF\n1:  -> POSIX ADVISORY WRITE 3 00:01:1 0 EOF",
        max_depth=1,
      ),
    )
  })
  assert_eq(d, 3)
}
