///|
/// PID 0 (not visible) and -1 (OFD) are deliberately distinct from a process.
pub(all) enum Owner {
  Process(Int32)
  OpenDescription
  NotVisible
} derive(Debug, Eq, ToJson)

///|
pub(all) enum LockKind {
  Posix
  Flock
  Ofd
  Lease
  Other(String)
} derive(Debug, Eq, ToJson)

///|
pub(all) enum LockMode {
  Read
  Write
  Unlock
  Other(String)
} derive(Debug, Eq, ToJson)

///|
/// Device components are hexadecimal in procfs; inode is unsigned decimal.
pub(all) struct FileKey {
  major : UInt32
  minor : UInt32
  inode : UInt64
} derive(Debug, Eq)

///|
/// Inclusive endpoints; None is the unbounded EOF suffix, not an empty range.
pub(all) struct ByteRange {
  start : Int64
  end : Int64?
} derive(Debug, Eq)

///|
pub(all) struct Entry {
  line : Int32
  ordinal : Int64
  depth : Int32
  kind : LockKind
  state : String
  mode : LockMode
  owner : Owner
  file : FileKey?
  range : ByteRange
  parent_line : Int32?
} derive(Debug, Eq, ToJson)

///|
/// All collections are private. Accessors return independent arrays.
pub struct Snapshot {
  priv records : Array[Entry]
  priv parents : Array[Int32?]
} derive(Debug)

///|
pub(all) struct Bottleneck {
  holder_line : Int32
  owner : Owner
  direct_waiters : Int32
  total_waiters : Int32
} derive(Debug, Eq, ToJson)

///|
pub suberror LockError {
  Invalid(line~ : Int32, reason~ : String)
} derive(Debug)

///|
/// Serialize full-width integer values as strings to avoid JS JSON precision loss.
pub impl ToJson for FileKey with fn to_json(self) {
  {
    "major": self.major.to_string(),
    "minor": self.minor.to_string(),
    "inode": self.inode.to_string(),
  }
}

///|
pub impl ToJson for ByteRange with fn to_json(self) {
  let end : Json = match self.end {
    None => "EOF"
    Some(n) => Json(n.to_string())
  }
  { "start": self.start.to_string(), "end": end }
}

///|
pub extend Owner with @debug.Debug::{to_repr}

///|
pub extend Owner with Eq::{equal, not_equal}

///|
pub extend Owner with ToJson::{to_json}

///|
pub extend LockKind with @debug.Debug::{to_repr}

///|
pub extend LockKind with Eq::{equal, not_equal}

///|
pub extend LockKind with ToJson::{to_json}

///|
pub extend LockMode with @debug.Debug::{to_repr}

///|
pub extend LockMode with Eq::{equal, not_equal}

///|
pub extend LockMode with ToJson::{to_json}

///|
pub extend FileKey with @debug.Debug::{to_repr}

///|
pub extend FileKey with Eq::{equal, not_equal}

///|
pub extend FileKey with ToJson::{to_json}

///|
pub extend ByteRange with @debug.Debug::{to_repr}

///|
pub extend ByteRange with Eq::{equal, not_equal}

///|
pub extend ByteRange with ToJson::{to_json}

///|
pub extend Entry with @debug.Debug::{to_repr}

///|
pub extend Entry with Eq::{equal, not_equal}

///|
pub extend Entry with ToJson::{to_json}

///|
pub extend Snapshot with @debug.Debug::{to_repr}

///|
pub extend Bottleneck with @debug.Debug::{to_repr}

///|
pub extend Bottleneck with Eq::{equal, not_equal}

///|
pub extend Bottleneck with ToJson::{to_json}

///|
pub extend LockError with @debug.Debug::{to_repr}
