///|
fn main raise {
  // Synthetic rows follow Linux's preorder indentation (depth 1 then 2 then 1).
  let text =
    #|1: POSIX ADVISORY WRITE 100 08:01:42 0 99
    #|1: -> POSIX ADVISORY WRITE 200 08:01:42 0 99
    #|1:  -> POSIX ADVISORY READ 300 08:01:42 0 99
    #|1: -> POSIX ADVISORY WRITE 400 08:01:42 50 EOF
    #|2: OFDLCK ADVISORY WRITE -1 08:01:99 128 EOF
  let s = @locks.parse(text)
  println("Synthetic Linux lock wait tree")
  println(s.to_json().stringify())
  println("Immediate-to-root chain for source line 3:")
  println(Json(s.wait_chain(3)).stringify())
  println("Entries intersecting inode 42 at the inclusive byte 99:")
  println(
    Json(
      s.query_range(@locks.file_key("08:01:42"), @locks.byte_range("99", "99")),
    ).stringify(),
  )
}
