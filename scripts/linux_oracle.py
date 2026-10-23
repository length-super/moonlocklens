#!/usr/bin/env python3
"""Real Linux lock contention; only disposable project-local files/processes."""
import fcntl
import json
import os
from pathlib import Path
import re
import select
import struct
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
CLI = Path(os.environ.get("MOONLOCKLENS_CLI", ROOT / "_build/js/debug/build/cmd/main/main.js"))
ROW = re.compile(r"^(\d+): ( *)(-> )?(\S+)\s+(\S+)\s+(\S+)\s+(-?\d+)\s+([0-9a-fA-F]+):([0-9a-fA-F]+):(\d+)\s+(\d+)\s+(EOF|\d+)$")

CHILD = r'''
import fcntl,os,struct,sys
path,kind=sys.argv[1:]
fd=os.open(path,os.O_RDWR)
print('ready',flush=True)
if kind=='POSIX': fcntl.lockf(fd,fcntl.LOCK_EX,64,64,os.SEEK_SET)
elif kind=='FLOCK': fcntl.flock(fd,fcntl.LOCK_EX)
else: fcntl.fcntl(fd,fcntl.F_OFD_SETLKW,struct.pack('hhqqi',fcntl.F_WRLCK,os.SEEK_SET,128,64,0))
print('acquired',flush=True)
'''


def cli(*args, ok=True, code=0):
    p = subprocess.run(["node", str(CLI), *map(str, args), "--json"], cwd=ROOT, text=True, capture_output=True, timeout=20)
    if ok:
        assert p.returncode == code, p.stderr
        return json.loads(p.stdout)
    assert p.returncode != 0 and p.stderr.strip(), p
    return p.stderr


def normalized(entry):
    key = entry["file"]
    return (int(key["major"]), int(key["minor"]), int(key["inode"]),
            entry["kind"], entry["mode"], entry["range"]["start"], entry["range"]["end"], entry["depth"] > 0)


def main():
    assert sys.platform == "linux", "Linux only"
    assert hasattr(fcntl, "F_OFD_SETLK"), "OFD locks required for this integration matrix"
    (ROOT / "release-local").mkdir(exist_ok=True)
    summary = {}
    scratch = Path(os.environ.get("MOONLOCKLENS_TEST_TMP", ROOT / "release-local")).resolve()
    assert scratch.is_relative_to((ROOT / "release-local").resolve()), "scratch must stay under project release-local"
    scratch.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="lock-oracle-", dir=scratch) as work:
        work = Path(work)
        fds, children, identities = [], [], {}
        try:
            for kind in ("POSIX", "FLOCK", "OFDLCK"):
                path = work / kind
                path.write_bytes(b"x" * 256)
                fd = os.open(path, os.O_RDWR)
                fds.append(fd)
                if kind == "POSIX":
                    fcntl.lockf(fd, fcntl.LOCK_EX, 64, 64, os.SEEK_SET)
                elif kind == "FLOCK":
                    fcntl.flock(fd, fcntl.LOCK_EX)
                else:
                    fcntl.fcntl(fd, fcntl.F_OFD_SETLK, struct.pack("hhqqi", fcntl.F_WRLCK, os.SEEK_SET, 128, 64, 0))
                st = os.fstat(fd)
                identities[st.st_ino] = (kind, os.major(st.st_dev), os.minor(st.st_dev))
                child = subprocess.Popen([sys.executable, "-u", "-c", CHILD, str(path), kind], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
                children.append(child)
                assert select.select([child.stdout], [], [], 5)[0], "child readiness timeout"
                assert child.stdout.readline().strip() == "ready"

            deadline = time.monotonic() + 8
            while True:
                raw = Path("/proc/locks").read_text()
                selected = [line for line in raw.splitlines() if (m := ROW.match(line)) and int(m[10]) in identities]
                if len(selected) == 6 and sum("->" in line for line in selected) == 3:
                    break
                assert time.monotonic() < deadline, "kernel did not expose all three blocked locks"
                assert all(p.poll() is None for p in children), "waiter exited before capture"
                time.sleep(0.05)

            # The host snapshot is private; it is deleted with the temporary directory.
            capture = work / "capture.locks"
            capture.write_text(raw)
            report = cli("inspect", capture)
            entries = [e for e in report["entries"] if e.get("file") and int(e["file"]["inode"]) in identities]
            assert len(entries) == 6
            python_rows = []
            for line in selected:
                m = ROW.match(line)
                kind, major, minor = identities[int(m[10])]
                assert kind == m[4], ("filesystem changed lock family", kind, m[4])
                assert (major, minor) == (int(m[8], 16), int(m[9], 16))
                python_rows.append((major, minor, int(m[10]), {"POSIX": "Posix", "FLOCK": "Flock", "OFDLCK": "Ofd"}[m[4]],
                                    m[6].title(), m[11], m[12], bool(m[3])))
            assert sorted(map(normalized, entries)) == sorted(python_rows), "independent field decoding differs"

            for inode, (kind, major, minor) in identities.items():
                group = [e for e in entries if int(e["file"]["inode"]) == inode]
                holder = next(e for e in group if e["depth"] == 0)
                waiter = next(e for e in group if e["depth"] > 0)
                assert waiter["parent_line"] == holder["line"]
                chain = cli("chain", capture, waiter["line"])
                assert [e["line"] for e in chain] == [waiter["line"], holder["line"]]
                if kind == "OFDLCK":
                    assert holder["owner"] == waiter["owner"] == "OpenDescription"
                else:
                    assert holder["owner"] == ["Process", os.getpid()]
                    assert waiter["owner"][1] in [p.pid for p in children]
                impact = next(b for b in report["bottlenecks"] if b["holder_line"] == holder["line"])
                assert impact["direct_waiters"] == impact["total_waiters"] == 1
                expected = ("64", "127") if kind == "POSIX" else (("128", "191") if kind == "OFDLCK" else ("0", "EOF"))
                assert (holder["range"]["start"], holder["range"]["end"]) == expected
                hits = cli("range", capture, f"{major:x}:{minor:x}:{inode}", *expected)
                assert len(hits) == 2
                path = work / kind
                by_path = cli("live", "--file", path, "--waiting", "--fail-on-wait", code=3)
                assert by_path["matching_records"] == 1
                assert len(by_path["entries"]) == 2
                assert all(int(e["file"]["inode"]) == inode for e in by_path["entries"])
                assert all(int(e["file"]["major"]) == major and int(e["file"]["minor"]) == minor for e in by_path["entries"])
                if kind != "OFDLCK":
                    by_pid = cli("live", "--pid", waiter["owner"][1], "--waiting")
                    assert by_pid["matching_records"] == 1 and len(by_pid["entries"]) == 2
                summary[kind] = {"holders": 1, "waiters": 1, "chain": "matched", "range": "matched"}
                summary[kind]["path_filter"] = "matched"

            ls = subprocess.run(["lslocks", "--json", "--output", "PID,TYPE,MODE,START,END,INODE,BLOCKER"], capture_output=True, text=True, check=True, timeout=10)
            oracle = json.loads(ls.stdout)["locks"]
            for inode, (kind, _, _) in identities.items():
                rows = [r for r in oracle if int(r.get("inode") or -1) == inode and r["type"] == kind]
                assert len(rows) == 2, (kind, rows)
                assert sum("*" in r["mode"] for r in rows) == 1
                for r in rows:
                    expected = (64, 127) if kind == "POSIX" else ((128, 191) if kind == "OFDLCK" else (0, 0))
                    assert (int(r["start"]), int(r["end"])) == expected
                summary[kind]["lslocks"] = "matched"

            live = cli("live")
            assert len([e for e in live["entries"] if e.get("file") and int(e["file"]["inode"]) in identities]) == 6
            cli("inspect", work / "missing", ok=False)
            bad = work / "invalid.locks"
            bad.write_text("1:  -> POSIX ADVISORY WRITE 1 00:01:1 0 EOF\n")
            assert "orphan" in cli("inspect", bad, ok=False)
            summary["live_cli"] = "passed"
            summary["error_cli"] = "passed"
            saved = work / "incident.locks"
            cli("capture", saved)
            before = saved.read_bytes()
            replay = cli("inspect", saved)
            captured_rows = [e for e in replay["entries"] if e.get("file") and int(e["file"]["inode"]) in identities]
            assert sorted(map(normalized, captured_rows)) == sorted(map(normalized, entries))
            cli("capture", saved, ok=False)
            assert saved.read_bytes() == before, "capture replaced an existing file"
            assert saved.stat().st_mode & 0o777 == 0o600
            summary["capture_replay_no_clobber"] = "passed"
        finally:
            for p in children:
                if p.poll() is None:
                    p.terminate()
                try:
                    p.communicate(timeout=5)
                except subprocess.TimeoutExpired:
                    p.kill()
                    p.communicate(timeout=5)
            for fd in fds:
                os.close(fd)
    print(json.dumps({"schema": 1, "status": "passed", "checks": summary}, indent=2))


if __name__ == "__main__":
    main()
