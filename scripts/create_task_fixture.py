"""Author-owned synthetic process/lock session; no host capture is read."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def stat(pid, parent, start, name, state="S"):
    return f"{pid} ({name}) {state} {parent} " + " ".join(["0"] * 17 + [str(start)])


def frame(elapsed, waiting):
    rows = [(100, 1, 1000, "demo-builder", "S", "do_wait"),
            (200, 100, 2000, "cache-worker", "S" if waiting else "R", "locks_lock_inode_wait" if waiting else "0"),
            (900, 1, 900, "cache-holder", "S", "hrtimer_nanosleep")]
    return {"elapsed_ms": str(elapsed), "boot_id": "synthetic-boot", "pid_namespace": "synthetic-pidns",
            "captured_at": "2026-10-28T00:00:00Z", "catalog_complete": True, "root_error": "",
            "root_after": stat(100, 1, 1000, "demo-builder"),
            "processes": [{"stat": stat(pid, ppid, start, name, state), "wchan": channel, "wchan_error": ""} for pid, ppid, start, name, state, channel in rows],
            "locks": "1: POSIX ADVISORY WRITE 900 08:01:42 0 EOF\n1: -> POSIX ADVISORY WRITE 200 08:01:42 0 EOF" if waiting else "",
            "locks_error": ""}


if __name__ == "__main__":
    capture = {"schema": "moonlocklens-task/1", "root_pid": 100, "frames": [frame(0, True), frame(500, True), frame(1000, False)]}
    (ROOT / "fixtures/task-session.json").write_text(json.dumps(capture, indent=2) + "\n", encoding="utf8")
