///|
extern "js" fn monotonic_ms() -> String =
  #|() => (process.hrtime.bigint()/1000000n).toString()

///|
extern "js" fn pause_ms(ms : Int32) -> Unit =
  #|(ms) => {Atomics.wait(new Int32Array(new SharedArrayBuffer(4)),0,0,ms)}

///|
extern "js" fn task_progress(text : String) -> Unit =
  #|(text) => {require('node:fs').writeSync(2,text+'\n')}

///|
/// Read-only procfs adapter. All tree selection, lock correlation and diagnosis
/// run in MoonBit. Bounded stat/wchan reads; no cmdline, environment or fd scans.
extern "js" fn collect_task(pid : Int32, base : String) -> FixedArray[String] =
  #|(pid,base) => {
  #| try {
  #|  if(process.platform!=='linux')throw Error('task collection requires Linux');
  #|  const fs=require('node:fs');
  #|  function read(path,cap){const fd=fs.openSync(path,'r');try{let total=0;const chunks=[];for(;;){const b=Buffer.alloc(Math.min(65536,cap+1)),n=fs.readSync(fd,b,0,b.length,null);if(!n)break;total+=n;if(total>cap)throw Error('read budget exceeded');chunks.push(b.subarray(0,n))}return new TextDecoder('utf-8',{fatal:true}).decode(Buffer.concat(chunks))}finally{fs.closeSync(fd)}}
  #|  function scope(){const p=fs.statSync('/proc',{bigint:true});return fs.readlinkSync('/proc/self/ns/pid')+'@'+p.dev+':'+p.ino}
  #|  const token=scope(),boot=read('/proc/sys/kernel/random/boot_id',128).trim();
  #|  const all=fs.readdirSync('/proc').filter(n=>/^[0-9]+$/.test(n)).map(Number).sort((a,b)=>a-b);
  #|  const ids=[pid,...all.filter(n=>n!==pid)].slice(0,4096),processes=[];
  #|  let catalog_complete=all.length<=4096,root_error='',total=0;
  #|  for(const id of ids){try{const stat=read('/proc/'+id+'/stat',8192);let wchan='',wchan_error='';try{wchan=read('/proc/'+id+'/wchan',256)}catch(e){wchan_error=String(e.code||'read_failed')}total+=stat.length+wchan.length;if(total>8000000){catalog_complete=false;break}processes.push({stat,wchan,wchan_error})}catch(e){catalog_complete=false;if(id===pid)root_error=String(e.code||'read_failed')}}
  #|  let locks='',locks_error='';try{locks=read('/proc/locks',4194304)}catch(e){locks_error=String(e.code||'read_failed')}
  #|  let root_after='';try{root_after=read('/proc/'+pid+'/stat',8192)}catch(e){root_error=String(e.code||'read_failed')}
  #|  if(scope()!==token||read('/proc/sys/kernel/random/boot_id',128).trim()!==boot)throw Error('procfs scope changed during collection');
  #|  return ['ok',JSON.stringify({elapsed_ms:(process.hrtime.bigint()/1000000n-BigInt(base)).toString(),boot_id:boot,pid_namespace:token,captured_at:new Date().toISOString(),catalog_complete,root_error,root_after,processes,locks,locks_error})];
  #| }catch(e){return ['error',String(e.message)]}
  #|}

///|
extern "js" fn read_task_text(path : String) -> FixedArray[String] =
  #|(path) => {try{const fs=require('node:fs'),fd=path==='-'?0:fs.openSync(path,'r');try{let total=0;const chunks=[];for(;;){const b=Buffer.alloc(65536),n=fs.readSync(fd,b,0,b.length,null);if(!n)break;total+=n;if(total>16777216)throw Error('task capture exceeds 16 MiB');chunks.push(b.subarray(0,n))}return ['ok',new TextDecoder('utf-8',{fatal:true}).decode(Buffer.concat(chunks))]}finally{if(path!=='-')fs.closeSync(fd)}}catch(e){return ['error',String(e.message)]}}
