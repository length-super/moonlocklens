#!/usr/bin/env python3
"""Exercise the usable CLI as a process, including input/output and exit status."""
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
CLI = ROOT / "_build/js/debug/build/cmd/main/main.js"
FIXTURE = ROOT / "fixtures/contention.locks"


def call(*args, data=None, code=0, cwd=ROOT):
    p = subprocess.run(["node", str(CLI), *map(str, args)], cwd=cwd,
                       input=data, capture_output=True, timeout=15)
    assert p.returncode == code, (args, p.returncode, p.stderr.decode(errors="replace"))
    if code in (0, 3):
        assert not p.stderr, p.stderr
    else:
        assert not p.stdout and p.stderr, (p.stdout, p.stderr)
    return p.stdout.decode(), p.stderr.decode()


def report(*args, **kwargs):
    return json.loads(call(*args, "--json", **kwargs)[0])


def main():
    assert "0.4.0" in call("--version")[0]
    assert "capture OUTPUT" in call("--help")[0]
    assert "observed 6 | matched 6" in call("inspect", FIXTURE)[0]
    all_rows = report("inspect", FIXTURE)
    assert all_rows["schema"] == "moonlocklens/2" and len(all_rows["entries"]) == 6
    focus = report("inspect", FIXTURE, "--pid", "300")
    assert focus["matched_lines"] == [3]
    assert [e["line"] for e in focus["entries"]] == [1, 2, 3]
    assert "*     L3" in call("inspect", FIXTURE, "--pid", "300")[0]
    assert report("inspect", FIXTURE, "--key", "08:01:99")["matched_lines"] == [5]
    assert report("inspect", FIXTURE, "--waiting")["matched_lines"] == [2, 3, 4]
    assert report("inspect", FIXTURE, "--pid", "300", "--key", "08:01:99")["matching_records"] == 0
    assert "No matching locks" in call("inspect", FIXTURE, "--pid", "999")[0]
    assert [e["line"] for e in report("chain", FIXTURE, "3")] == [3, 2, 1]
    assert [e["line"] for e in report("range", FIXTURE, "08:01:42", "100", "EOF")] == [4]
    report("inspect", FIXTURE, "--pid", "300", "--fail-on-wait", code=3)
    report("inspect", FIXTURE, "--pid", "100", "--fail-on-wait")
    raw = FIXTURE.read_bytes()
    assert report("inspect", "-", data=raw)["entries"] == all_rows["entries"]
    assert report("inspect", "-", data=b"\xef\xbb\xbf"+raw)["entries"] == all_rows["entries"]
    assert report("inspect", "-", data=b"")["observed_records"] == 0
    for args in (("inspect", FIXTURE, "--pid", "0"), ("inspect", FIXTURE, "--pid", "9999999999999"),
                 ("--pid", "1"),
                 ("inspect", FIXTURE, "--pid", "abc"), ("inspect", FIXTURE, "--pid"),
                 ("inspect", FIXTURE, "--key", "08:01:99", "--file", "a"),
                 ("inspect", FIXTURE, "--key", "bad"),
                 ("range", FIXTURE, "08:01:42", "20", "10"),
                 ("chain", FIXTURE, "3", "--waiting"), ("inspect", FIXTURE, "--file", "a"),
                 ("inspect", FIXTURE, "--unknown"), ("inspect", FIXTURE, "--json", "--text")):
        _, error = call(*args, "--json" if "--json" not in args else "--text", code=2)
        assert json.loads(error)["error"]["message"]
    _, invalid = call("inspect", "-", "--json", data=b"bad\n", code=1)
    assert json.loads(invalid)["error"]["line"] == 1
    call("inspect", "-", "--json", data=b"\xff", code=1)
    call("inspect", "-", "--json", data=b"x" * (4194304+1), code=1)
    unsafe = b"1: \x1b[31mFUTURE UNKNOWN CUSTOM 15 00:01:1 0 EOF\n"
    assert "\x1b" not in call("inspect", "-", data=unsafe)[0]
    (ROOT / "release-local").mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(dir=ROOT / "release-local", prefix="cli-") as tmp:
        tmp = Path(tmp)
        missing = tmp / "missing.locks"
        call("inspect", missing, "--json", code=1)
        unusual = tmp / "--input.locks"
        unusual.write_bytes(raw)
        unusual_report = json.loads(call("inspect", "--json", "--", "--input.locks", cwd=tmp)[0])
        assert unusual_report["entries"] == all_rows["entries"]
    print(json.dumps({"status": "passed", "coverage": "text/JSON, filters+blockers, stdin/BOM, range/chain, wait exit, errors+budgets"}))


if __name__ == "__main__":
    main()
