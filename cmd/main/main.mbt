///|
extern "js" fn arguments() -> FixedArray[String] =
  #|() => process.argv.slice(2)

///|
/// Bounded, fatal UTF-8 decoding. Host glue contains no lock analysis.
extern "js" fn read_text(path : String) -> FixedArray[String] =
  #|(path) => {try {const fs=require('node:fs'), fd=fs.openSync(path,'r'); try {const chunks=[];let total=0;for(;;){const b=Buffer.alloc(65536),n=fs.readSync(fd,b,0,b.length,null);if(!n)break;total+=n;if(total>4194304)throw Error('input exceeds 4 MiB');chunks.push(b.subarray(0,n))}return ['ok',new TextDecoder('utf-8',{fatal:true}).decode(Buffer.concat(chunks))]}finally{fs.closeSync(fd)}}catch(e){return ['error',String(e.message)]}}

///|
extern "js" fn is_linux() -> Bool =
  #|() => process.platform === 'linux'

///|
extern "js" fn failure(message : String) -> Unit =
  #|(message) => {console.error(message); process.exitCode=1}

///|
fn read(path : String) -> @locks.Snapshot raise {
  let r = read_text(path)
  if r[0] != "ok" {
    fail(r[1])
  }
  @locks.parse(r[1])
}

///|
fn run(args : Array[String]) -> Unit raise {
  match args {
    ["inspect", file] => println(read(file).to_json().stringify())
    ["chain", file, line] => {
      let snapshot = read(file)
      println(Json(snapshot.wait_chain(@string.parse_int(line))).stringify())
    }
    ["range", file, key, start, end] => {
      let snapshot = read(file)
      let key = @locks.file_key(key)
      let range = @locks.byte_range(start, end)
      println(Json(snapshot.query_range(key, range)).stringify())
    }
    ["live"] => {
      if !is_linux() {
        fail("live requires Linux")
      }
      println(read("/proc/locks").to_json().stringify())
    }
    ["--help"] =>
      println(
        "MoonLockLens: inspect FILE | chain FILE LINE | range FILE HEX_MAJOR:HEX_MINOR:INODE START END_OR_EOF | live",
      )
    _ =>
      fail(
        "usage: inspect FILE | chain FILE LINE | range FILE HEX_MAJOR:HEX_MINOR:INODE START END_OR_EOF | live",
      )
  }
}

///|
fn main {
  run(Array::from_iter(arguments().iter())) catch {
    @locks.LockError::Invalid(line~, reason~) =>
      failure("locks line \{line}: \{reason}")
    e => failure(e.to_string())
  }
}
