"""Cross-platform file session replay, OFD ownership and replacement contracts."""
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
CLI = ROOT / "_build/js/debug/build/cmd/main/main.js"


def run(*args, code=0, data=None):
    p = subprocess.run(["node", str(CLI), *map(str, args)], input=data, capture_output=True, timeout=20)
    assert p.returncode == code, (args, p.returncode, p.stderr.decode(errors="replace"))
    return p


def main():
    fixture = ROOT / "fixtures/file-session.json"
    payload = json.loads(run("file-report", fixture, "--json").stdout)
    assert payload["schema"] == "moonlocklens-file-report/1"
    report = payload["report"]
    assert report["sample_count"] == 3 and report["peak_waiting_records"] == 1
    assert report["max_consecutive_wait_samples"] == 2
    assert report["frames"][0]["entries"][1]["owner"] == "OpenDescription"
    assert report["frames"][-1]["waiting_records"] == 0
    assert json.loads(run("file-report", "-", "--json", data=fixture.read_bytes()).stdout) == payload
    assert "owner -1 remains unknown" in run("file-report", fixture, "--markdown").stdout.decode()
    run("file-report", fixture, "--fail-on-wait", code=3)
    for args in (("watch-file", "file"), ("watch-file", "file", "--samples", "61", "--output", "unused"),
                 ("file-report", fixture, "--samples", "1"), ("file-report", fixture, "--pid", "1")):
        run(*args, code=2)
    with tempfile.TemporaryDirectory(dir=ROOT / "release-local", prefix="file-cli-") as tmp:
        bad = json.loads(fixture.read_text())
        bad["frames"][1]["pid_namespace"] = "other-scope"
        path = Path(tmp) / "bad.json"
        path.write_text(json.dumps(bad))
        error = run("file-report", path, "--json", code=1)
        assert json.loads(error.stderr)["error"]["message"]
    print(json.dumps({"status": "passed", "coverage": "file replay, unknown OFD ownership, waiting window, stdin, schema and usage errors"}))


if __name__ == "__main__":
    main()
