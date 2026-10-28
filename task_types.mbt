///|
pub(all) struct ProcessInfo {
  pid : Int32
  parent_pid : Int32
  name : String
  state : String
  start_ticks : String
  wchan : String
  wchan_status : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct TaskProcess {
  info : ProcessInfo
  finding : String
  waiting_lines : Array[Int32]
  requests : Array[Entry]
  blockers : Array[Entry]
  blocker_identities : Array[String]
  files : Array[FileKey]
} derive(Debug, ToJson)

///|
pub(all) struct TaskFrameReport {
  elapsed_ms : Int64
  root_state : String
  processes : Array[TaskProcess]
  blocker_processes : Array[ProcessInfo]
  issues : Array[String]
} derive(Debug, ToJson)

///|
pub(all) struct TaskTransition {
  at_ms : Int64
  pid : Int32
  start_ticks : String
  change : String
  before : String
  after : String
} derive(Debug, ToJson)

///|
pub(all) struct TaskReport {
  root_pid : Int32
  root_start_ticks : String
  started_at : String
  sample_count : Int32
  observed_span_ms : Int64
  max_consecutive_wait_samples : Int32
  max_sampled_wait_span_ms : Int64
  frames : Array[TaskFrameReport]
  transitions : Array[TaskTransition]
  next_steps : Array[String]
} derive(Debug, ToJson)

///|
priv struct ProcWire {
  stat : String
  wchan : String
  wchan_error : String
} derive(@json.FromJson, ToJson)

///|
priv struct FrameWire {
  elapsed_ms : String
  boot_id : String
  pid_namespace : String
  captured_at : String
  catalog_complete : Bool
  root_error : String
  root_after : String
  processes : Array[ProcWire]
  locks : String
  locks_error : String
} derive(@json.FromJson, ToJson)

///|
priv struct CaptureWire {
  schema : String
  root_pid : Int32
  frames : Array[FrameWire]
} derive(@json.FromJson, ToJson)

///|
/// Private normalized samples; record() validates identity, scope and budgets.
pub struct TaskCapture {
  priv root_pid : Int32
  priv mut start_ticks : String
  priv mut boot_id : String
  priv mut pid_namespace : String
  priv frames : Array[FrameWire]
  priv mut stored_chars : Int32
}

///|
pub extend ProcessInfo with @debug.Debug::{to_repr}

///|
pub extend ProcessInfo with Eq::{equal, not_equal}

///|
pub extend ProcessInfo with ToJson::{to_json}

///|
pub extend TaskProcess with @debug.Debug::{to_repr}

///|
pub extend TaskProcess with ToJson::{to_json}

///|
pub extend TaskFrameReport with @debug.Debug::{to_repr}

///|
pub extend TaskFrameReport with ToJson::{to_json}

///|
pub extend TaskTransition with @debug.Debug::{to_repr}

///|
pub extend TaskTransition with ToJson::{to_json}

///|
pub extend TaskReport with @debug.Debug::{to_repr}

///|
pub extend TaskReport with ToJson::{to_json}
