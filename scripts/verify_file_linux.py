"""Real file-first monitoring of POSIX/FLOCK/OFD contention and path replacement."""
import fcntl
import json
import os
from pathlib import Path
import select
import struct
import subprocess
import sys
import tempfile
import time
from linux_oracle import CHILD, ROW

ROOT = Path(__file__).resolve().parents[1]
CLI = Path(os.environ.get("MOONLOCKLENS_CLI", ROOT / "_build/js/debug/build/cmd/main/main.js"))


def lock(fd, kind, acquire):
    if kind == "POSIX":
        fcntl.lockf(fd, fcntl.LOCK_EX if acquire else fcntl.LOCK_UN, 64, 64, os.SEEK_SET)
    elif kind == "FLOCK":
        fcntl.flock(fd, fcntl.LOCK_EX if acquire else fcntl.LOCK_UN)
    else:
        fcntl.fcntl(fd, fcntl.F_OFD_SETLK, struct.pack("hhqqi", fcntl.F_WRLCK if acquire else fcntl.F_UNLCK, os.SEEK_SET, 128, 64, 0))


def progress(watch):
    while True:
        assert select.select([watch.stderr], [], [], 10)[0], "watch progress timeout"
        line = watch.stderr.readline()
        assert line, "watch ended before controlled change"
        if "sample 2/5" in line:
            return


def report(path):
    p = subprocess.run(["node", str(CLI), "file-report", str(path), "--json"], capture_output=True, text=True, timeout=20, check=True)
    return json.loads(p.stdout)["report"]


def main():
    scratch = Path(os.environ.get("MOONLOCKLENS_TEST_TMP", ROOT / "release-local")).resolve()
    assert scratch.is_relative_to((ROOT / "release-local").resolve())
    scratch.mkdir(parents=True, exist_ok=True)
    checked = []
    with tempfile.TemporaryDirectory(dir=scratch, prefix="file-oracle-") as tmp:
        tmp = Path(tmp)
        for kind in ("POSIX", "FLOCK", "OFDLCK"):
            path = tmp / kind
            path.write_bytes(b"x" * 256)
            fd = os.open(path, os.O_RDWR)
            child = watch = None
            try:
                lock(fd, kind, True)
                st = os.fstat(fd)
                child = subprocess.Popen([sys.executable, "-u", "-c", CHILD, str(path), kind], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
                assert select.select([child.stdout], [], [], 5)[0]
                assert child.stdout.readline().strip() == "ready"
                deadline = time.monotonic() + 5
                while True:
                    rows = [m for line in Path('/proc/locks').read_text().splitlines() if (m := ROW.match(line)) and int(m[10]) == st.st_ino and m[4] == kind]
                    if len(rows) == 2 and sum(bool(m[3]) for m in rows) == 1:
                        break
                    assert time.monotonic() < deadline
                    time.sleep(.02)
                capture = tmp / (kind + '.json')
                watch = subprocess.Popen(["node", str(CLI), "watch-file", str(path), "--samples", "5", "--interval", "150", "--output", str(capture)], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
                progress(watch)
                lock(fd, kind, False)
                out, err = watch.communicate(timeout=20)
                assert watch.returncode == 0, (out, err)
                child.communicate(timeout=5)
                r = report(capture)
                assert r['max_consecutive_wait_samples'] >= 2 and r['frames'][-1]['waiting_records'] == 0
                assert int(r['file']['inode']) == st.st_ino and int(r['file']['major']) == os.major(st.st_dev) and int(r['file']['minor']) == os.minor(st.st_dev)
                entries = r['frames'][0]['entries']
                assert len(entries) == 2 and entries[1]['parent_line'] == entries[0]['line']
                if kind == 'OFDLCK': assert all(e['owner'] == 'OpenDescription' for e in entries)
                assert capture.stat().st_mode & 0o777 == 0o600
                for threshold, code in ((2, 3), (5, 0)):
                    gate = subprocess.run(['node', str(CLI), 'gate', str(capture), '--wait-samples', str(threshold), '--json'], capture_output=True, text=True, timeout=20)
                    assert gate.returncode == code, (gate.stdout, gate.stderr)
                    assert json.loads(gate.stdout)['assessment']['sample_count'] == 5
                original = capture.read_bytes()
                p = subprocess.run(['node', str(CLI), 'watch-file', str(path), '--samples', '1', '--output', str(capture)], capture_output=True, timeout=20)
                assert p.returncode == 1 and capture.read_bytes() == original
                checked.append(kind)
            finally:
                for process in (watch, child):
                    if process and process.poll() is None:
                        process.terminate()
                        process.communicate(timeout=5)
                os.close(fd)
        path = tmp / 'replace.lock'
        path.touch()
        fd = os.open(path, os.O_RDWR)
        watch = None
        try:
            fcntl.flock(fd, fcntl.LOCK_EX)
            inode = os.fstat(fd).st_ino
            capture = tmp / 'replacement.json'
            watch = subprocess.Popen(['node', str(CLI), 'watch-file', str(path), '--samples', '5', '--interval', '150', '--output', str(capture)], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            progress(watch)
            replacement = tmp / 'new-file'
            replacement.touch()
            os.replace(replacement, path)
            out, err = watch.communicate(timeout=20)
            assert watch.returncode == 0, (out, err)
            r = report(capture)
            assert int(r['file']['inode']) == inode and r['frames'][-1]['path_state'] == 'identity_changed'
            assert all(int(e['file']['inode']) == inode for e in r['frames'][-1]['entries'])
            gate = subprocess.run(['node', str(CLI), 'gate', str(capture), '--json'], capture_output=True, text=True, timeout=20)
            assert gate.returncode == 4 and json.loads(gate.stdout)['assessment']['status'] == 'inconclusive'
        finally:
            if watch and watch.poll() is None:
                watch.terminate()
                watch.communicate(timeout=5)
            os.close(fd)
    print(json.dumps({'status':'passed', 'file_first_families':checked, 'controlled_release':'passed', 'OFD_unknown_owner':'passed', 'path_replacement':'passed', 'replay_permissions_no_clobber':'passed'}))


if __name__ == '__main__':
    main()
