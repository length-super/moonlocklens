///|
extern "js" fn arguments() -> FixedArray[String] =
  #|() => process.argv.slice(2)

///|
/// A '-' input borrows stdin; real file descriptors are always closed.
extern "js" fn read_text(path : String) -> FixedArray[String] =
  #|(path) => {try {const fs=require('node:fs'), fd=path==='-'?0:fs.openSync(path,'r');try{const chunks=[];let total=0;for(;;){const b=Buffer.alloc(65536),n=fs.readSync(fd,b,0,b.length,null);if(!n)break;total+=n;if(total>4194304)throw Error('input exceeds 4 MiB');chunks.push(b.subarray(0,n))}return ['ok',new TextDecoder('utf-8',{fatal:true}).decode(Buffer.concat(chunks))]}finally{if(path!=='-')fs.closeSync(fd)}}catch(e){return ['error',String(e.message)]}}

///|
/// Exclusive creation: existing captures, links and files are never replaced.
extern "js" fn save_new(path : String, text : String) -> String =
  #|(path,text) => {const fs=require('node:fs');let fd;try{fd=fs.openSync(path,'wx',0o600);fs.writeFileSync(fd,text,'utf8');return ''}catch(e){return String(e.message)}finally{if(fd!==undefined)fs.closeSync(fd)}}

///|
/// Linux dev_t splitting, with BigInt stat to retain the exact inode.
extern "js" fn path_key(path : String) -> FixedArray[String] =
  #|(path) => {try{if(process.platform!=='linux')throw Error('--file requires Linux; use --key for a saved capture');const s=require('node:fs').statSync(path,{bigint:true}),d=s.dev;const major=((d>>8n)&0xfffn)|((d>>32n)&0xfffff000n),minor=(d&0xffn)|((d>>12n)&0xffffff00n);return ['ok',major.toString(16)+':'+minor.toString(16)+':'+s.ino.toString()]}catch(e){return ['error',String(e.message)]}}

///|
extern "js" fn is_linux() -> Bool =
  #|() => process.platform === 'linux'

///|
extern "js" fn set_exit(code : Int32) -> Unit =
  #|(code) => {process.exitCode=code}

///|
extern "js" fn stderr(text : String) -> Unit =
  #|(text) => {console.error(text)}

///|
fn read_input(path : String) -> String raise {
  let r = read_text(path)
  if r[0] != "ok" {
    raise HostError(r[1])
  }
  match r[1].strip_prefix("\u{FEFF}") {
    Some(s) => s.to_owned()
    None => r[1]
  }
}
