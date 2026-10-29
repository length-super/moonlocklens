///|
pub(all) struct WaitAssessment {
  status : String
  threshold_samples : Int32
  sample_count : Int32
  observed_streak : Int32
  evidence_gaps : Int32
  reason : String
} derive(ToJson)

///|
pub extend WaitAssessment with ToJson::{to_json}

///|
fn assess_wait(
  samples : Int32,
  streak : Int32,
  gaps : Int32,
  threshold : Int32,
) -> WaitAssessment raise LockError {
  if threshold < 1 || threshold > 60 {
    invalid(0, "wait sample threshold must be 1..60")
  }
  let (status, reason) = if streak >= threshold {
    (
      "fail", "Confirmed lock waits reached the consecutive-sample threshold; gaps elsewhere do not erase observed evidence.",
    )
  } else if gaps > 0 || samples < threshold {
    (
      "inconclusive", "Visibility gaps or insufficient samples prevent a passing assessment.",
    )
  } else {
    (
      "pass", "No consecutive lock-wait streak reached the threshold in this observation window; this does not prove business completion.",
    )
  }
  {
    status,
    reason,
    threshold_samples: threshold,
    sample_count: samples,
    observed_streak: streak,
    evidence_gaps: gaps,
  }
}

///|
/// Task streaks require the same PID/starttime in consecutive observations.
pub fn TaskCapture::assess(
  self : TaskCapture,
  wait_samples~ : Int32 = 2,
) -> WaitAssessment raise LockError {
  let r = self.report()
  let gaps = r.frames
    .filter(f => f.root_state != "present" || !f.issues.is_empty())
    .length()
  assess_wait(
    r.sample_count,
    r.max_consecutive_wait_samples,
    gaps,
    wait_samples,
  )
}

///|
/// File streaks mean at least one waiter for the original file in each sample.
pub fn FileCapture::assess(
  self : FileCapture,
  wait_samples~ : Int32 = 2,
) -> WaitAssessment raise LockError {
  let r = self.report()
  let gaps = r.frames
    .filter(f => f.path_state != "present" || !f.issues.is_empty())
    .length()
  assess_wait(
    r.sample_count,
    r.max_consecutive_wait_samples,
    gaps,
    wait_samples,
  )
}

///|
pub fn assess_capture(
  text : String,
  wait_samples~ : Int32 = 2,
) -> WaitAssessment raise LockError {
  let schema = match task_json(text) {
    Json::Object(fields) => fields.get("schema")
    _ => None
  }
  match schema {
    Some(Json::String("moonlocklens-task/1")) =>
      parse_task_capture(text).assess(wait_samples~)
    Some(Json::String("moonlocklens-file/1")) =>
      parse_file_capture(text).assess(wait_samples~)
    _ => {
      invalid(
        0, "gate requires a task or file capture, not a rendered report or raw locks",
      )
      abort("unreachable")
    }
  }
}
