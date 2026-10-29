///|
extern "js" fn collect_file(path : String, base : String) -> FixedArray[String] =
  #|(path,base) => {
  #| try {
  #|  const fs=require('node:fs');
  #|  function read(p,cap){const fd=fs.openSync(p,'r');try{const chunks=[];let size=0;for(;;){const b=Buffer.alloc(65536),n=fs.readSync(fd,b,0,b.length,null);if(!n)break;size+=n;if(size>cap)throw Error('read budget exceeded');chunks.push(b.subarray(0,n))}return new TextDecoder('utf-8',{fatal:true}).decode(Buffer.concat(chunks))}finally{fs.closeSync(fd)}}
  #|  function key(){const s=fs.statSync(path,{bigint:true}),d=s.dev;return (((d>>8n)&0xfffn)|((d>>32n)&0xfffff000n)).toString(16)+':'+((d&0xffn)|((d>>12n)&0xffffff00n)).toString(16)+':'+s.ino}
  #|  function scope(){const s=fs.statSync('/proc',{bigint:true});return fs.readlinkSync('/proc/self/ns/pid')+'@'+s.dev+':'+s.ino}
  #|  const token=scope(),boot=read('/proc/sys/kernel/random/boot_id',128).trim();
  #|  let file_key='',file_error='',locks='',locks_error='';
  #|  try{file_key=key()}catch(e){file_error=String(e.code||'read_failed')}
  #|  try{locks=read('/proc/locks',4194304)}catch(e){locks_error=String(e.code||'read_failed')}
  #|  try{if(file_key!==key())file_error='identity_changed_during_collection'}catch(e){file_error=String(e.code||'read_failed')}
  #|  if(token!==scope()||boot!==read('/proc/sys/kernel/random/boot_id',128).trim())throw Error('procfs scope changed during collection');
  #|  return ['ok',JSON.stringify({elapsed_ms:(process.hrtime.bigint()/1000000n-BigInt(base)).toString(),boot_id:boot,pid_namespace:token,captured_at:new Date().toISOString(),file_key,file_error,locks,locks_error})];
  #| }catch(e){return ['error',String(e.message)]}
  #|}

///|
fn load_file(path : String) -> @locks.FileCapture raise {
  let raw = read_task_text(path)
  if raw[0] != "ok" {
    raise HostError(raw[1])
  }
  @locks.parse_file_capture(raw[1])
}

///|
fn file_command(options : Options) -> Int32 raise {
  if options.pid is Some(_) ||
    options.key is Some(_) ||
    options.file is Some(_) ||
    options.waiting {
    raise Usage(
      "file commands take a path; inspect/live filters are not available",
    )
  }
  let capture = match options.args {
    ["file-report", path] => {
      if options.samples is Some(_) ||
        options.interval is Some(_) ||
        options.output is Some(_) {
        raise Usage("file-report accepts format and --fail-on-wait only")
      }
      load_file(path)
    }
    ["watch-file", path] => {
      guard options.output is Some(output) else {
        raise Usage("watch-file requires --output NEW_CAPTURE.json")
      }
      let count = options.samples.unwrap_or(10)
      let interval = options.interval.unwrap_or(500)
      if count < 1 || count > 60 || interval < 100 || interval > 5000 {
        raise Usage(
          "samples must be 1..60; interval must be 100..5000 milliseconds",
        )
      }
      if !is_linux() {
        raise HostError(
          "watch-file requires Linux; file-report replays saved captures",
        )
      }
      let c = @locks.file_capture()
      let base = monotonic_ms()
      for i in 0..<count {
        if i > 0 {
          pause_ms(interval)
        }
        let raw = collect_file(path, base)
        if raw[0] != "ok" {
          raise HostError(raw[1])
        }
        c.record(raw[1])
        if !options.json {
          task_progress("Collected sample \{i + 1}/\{count}")
        }
      }
      let error = save_new(output, c.to_json().stringify())
      if error != "" {
        raise HostError(error)
      }
      c
    }
    _ => raise Usage("usage: watch-file PATH --output FILE | file-report FILE")
  }
  let report = capture.report()
  if options.json {
    let payload : Json = {
      "schema": "moonlocklens-file-report/1",
      "report": Json(report),
    }
    println(payload.stringify())
  } else {
    println(report.to_markdown())
  }
  if options.fail_on_wait && report.peak_waiting_records > 0 {
    3
  } else {
    0
  }
}
