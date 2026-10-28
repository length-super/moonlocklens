"""Cross-platform replay/incident report contract, using synthetic source data."""
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
CLI = ROOT / "_build/js/debug/build/cmd/main/main.js"
FIXTURE = ROOT / "fixtures/task-session.json"


def run(*args, code=0, data=None):
    p = subprocess.run(["node", str(CLI), *map(str, args)], input=data, capture_output=True, timeout=15)
    assert p.returncode == code, (args, p.returncode, p.stderr.decode(errors="replace"))
    return p


def main():
    result = run("report", FIXTURE, "--json")
    payload = json.loads(result.stdout)
    assert not result.stderr and payload["schema"] == "moonlocklens-report/1"
    r = payload["report"]
    assert r["sample_count"] == 3 and int(r["observed_span_ms"]) == 1000
    assert r["max_consecutive_wait_samples"] == 2 and int(r["max_sampled_wait_span_ms"]) == 500
    assert r["frames"][0]["processes"][1]["finding"] == "confirmed_file_lock_wait"
    assert r["frames"][2]["processes"][1]["finding"] == "runnable_progress_unknown"
    assert any(t["pid"] == 200 and t["change"] == "finding_changed" for t in r["transitions"])
    assert json.loads(run("report", "-", "--json", data=FIXTURE.read_bytes()).stdout) == payload
    text = run("report", FIXTURE).stdout.decode()
    assert "External blocker PID 900" in text and "finding_changed" in text
    md = run("report", FIXTURE, "--markdown").stdout.decode()
    assert "# MoonLockLens task incident" in md and "## Next checks" in md
    assert "\n| 200 /" in md and "does not prove an uninterrupted" in md
    run("report", FIXTURE, "--json", "--fail-on-wait", code=3)
    for args in (("report", FIXTURE, "--pid", "100"), ("report", FIXTURE, "--samples", "2"),
                 ("inspect", FIXTURE, "--markdown"), ("watch", "100"),
                 ("watch", "100", "--samples", "61", "--output", "unused.json"),
                 ("watch", "100", "--interval", "99", "--output", "unused.json"),
                 ("diagnose", "100", "--samples", "1"),
                 ("report", FIXTURE, "--markdown", "--json")):
        run(*args, code=2)
    with tempfile.TemporaryDirectory(dir=ROOT / "release-local", prefix="task-cli-") as tmp:
        path = Path(tmp) / "bad.json"
        bad = json.loads(FIXTURE.read_text())
        bad["frames"][1]["elapsed_ms"] = "0"
        path.write_text(json.dumps(bad))
        error = run("report", path, "--json", code=1)
        assert json.loads(error.stderr)["error"]["message"]
        run("report", "-", "--json", data=b"[]", code=1)
    print(json.dumps({"status": "passed", "coverage": "task replay, text/JSON/Markdown, timeline/recovery, stdin, errors and automation exit"}))


if __name__ == "__main__":
    main()
