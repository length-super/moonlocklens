"""Real parent/worker task: block on flock, observe, release after sample 2."""
import fcntl
import json
import os
from pathlib import Path
import select
import signal
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
CLI = Path(os.environ.get("MOONLOCKLENS_CLI", ROOT / "_build/js/debug/build/cmd/main/main.js"))

WORKER = r'''
import fcntl,os,sys
open('/proc/self/comm','w').write('cache-worker')
fd=os.open(sys.argv[1],os.O_RDWR)
print('ready',flush=True)
fcntl.flock(fd,fcntl.LOCK_EX)
sys.stdin.readline()
'''

JOB = r'''
import json,os,subprocess,sys
open('/proc/self/comm','w').write('build-job')
p=subprocess.Popen([sys.executable,'-u','-c',sys.argv[2],sys.argv[1]],stdout=subprocess.PIPE,text=True)
assert p.stdout.readline().strip()=='ready'
print(json.dumps({'root':os.getpid(),'worker':p.pid}),flush=True)
sys.exit(p.wait())
'''


def call(*args, code=0):
    p = subprocess.run(["node", str(CLI), *map(str, args), "--json"], cwd=ROOT, capture_output=True, text=True, timeout=20)
    assert p.returncode == code, (args, p.returncode, p.stderr)
    if code:
        return p
    assert not p.stderr
    return json.loads(p.stdout)


def main():
    scratch = Path(os.environ.get("MOONLOCKLENS_TEST_TMP", ROOT / "release-local")).resolve()
    assert scratch.is_relative_to((ROOT / "release-local").resolve())
    scratch.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=scratch, prefix="task-oracle-") as temp:
        temp = Path(temp)
        path = temp / "cache.lock"
        path.touch()
        fd = os.open(path, os.O_RDWR)
        job = None
        watch = None
        try:
            fcntl.flock(fd, fcntl.LOCK_EX)
            job = subprocess.Popen([sys.executable, "-u", "-c", JOB, str(path), WORKER], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, start_new_session=True)
            assert select.select([job.stdout], [], [], 5)[0], "job readiness timeout"
            pids = json.loads(job.stdout.readline())
            # Poll only our controlled worker until its real blocked lock is exposed.
            import time
            end = time.monotonic() + 5
            while True:
                rows = Path("/proc/locks").read_text()
                if any("->" in line and str(pids["worker"]) in line.split() for line in rows.splitlines()):
                    break
                assert time.monotonic() < end
                time.sleep(.02)
            result = call("diagnose", pids["root"])["report"]
            info = {p["info"]["pid"]: p for p in result["frames"][0]["processes"]}
            assert set(info) == {pids["root"], pids["worker"]}
            worker = info[pids["worker"]]
            assert worker["finding"] == "confirmed_file_lock_wait"
            assert worker["requests"][0]["parent_line"] in [e["line"] for e in worker["blockers"]]
            assert worker["info"]["parent_pid"] == pids["root"]
            stat = Path(f'/proc/{pids["worker"]}/stat').read_text()
            start_ticks = stat[stat.rfind(") ")+2:].split()[19]
            assert worker["info"]["start_ticks"] == start_ticks
            channel = Path(f'/proc/{pids["worker"]}/wchan').read_text().strip()
            assert worker["info"]["wchan"] == channel
            assert any(p["pid"] == os.getpid() for p in result["frames"][0]["blocker_processes"])
            st = os.fstat(fd)
            key = worker["files"][0]
            assert (int(key["major"]), int(key["minor"]), int(key["inode"])) == (os.major(st.st_dev), os.minor(st.st_dev), st.st_ino)
            capture = temp / "incident.json"
            watch = subprocess.Popen(["node", str(CLI), "watch", str(pids["root"]), "--samples", "5", "--interval", "150", "--output", str(capture)], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            progress = []
            while not any("sample 2/5" in line for line in progress):
                assert select.select([watch.stderr], [], [], 10)[0], "sampling progress timeout"
                line = watch.stderr.readline()
                assert line, "watch exited before sample 2"
                progress.append(line)
            fcntl.flock(fd, fcntl.LOCK_UN)
            output, errors = watch.communicate(timeout=20)
            assert watch.returncode == 0, (output, errors)
            assert "sample 5/5" in errors
            report = call("report", capture)["report"]
            assert report["sample_count"] == 5 and report["max_consecutive_wait_samples"] >= 2
            findings = [next(p["finding"] for p in f["processes"] if p["info"]["pid"] == pids["worker"]) for f in report["frames"]]
            assert findings[0] == "confirmed_file_lock_wait" and findings[-1] != "confirmed_file_lock_wait", findings
            assert any(t["pid"] == pids["worker"] and t["change"] == "finding_changed" for t in report["transitions"])
            assert capture.stat().st_mode & 0o777 == 0o600
            original = capture.read_bytes()
            call("watch", pids["root"], "--samples", "1", "--output", capture, code=1)
            assert capture.read_bytes() == original
            markdown = subprocess.run(["node", str(CLI), "report", str(capture), "--markdown"], capture_output=True, text=True, check=True)
            assert "build-job" in markdown.stdout and "## Observed transitions" in markdown.stdout
            call("diagnose", "2147483647", code=1)
            print(json.dumps({"status": "passed", "task_tree": "matched", "process_identity_and_wchan": "matched", "external_blocker_and_file": "matched", "five_sample_watch_and_release": "matched", "capture_replay_no_clobber": "passed", "markdown_report": "passed"}))
        finally:
            if watch and watch.poll() is None:
                watch.terminate()
                watch.communicate(timeout=5)
            if job:
                if job.stdin:
                    job.stdin.close()
                    job.stdin = None
                try:
                    job.communicate(timeout=3)
                except subprocess.TimeoutExpired:
                    os.killpg(job.pid, signal.SIGTERM)
                    job.communicate(timeout=5)
            os.close(fd)


if __name__ == "__main__":
    main()
