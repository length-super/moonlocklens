#!/usr/bin/env python3
"""Consume the actual moon package ZIP, never the working tree dependency."""
import json
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def run(*args, cwd=ROOT):
    p = subprocess.run(args, cwd=cwd, text=True, capture_output=True)
    if p.returncode:
        raise RuntimeError(p.stdout + p.stderr)
    return p


def main():
    run("moon", "package")
    archive = ROOT / "_build/publish/length-super-moonlocklens-0.4.0.zip"
    local = ROOT / "release-local/package-consumption"
    # Refuse replacing an unrelated directory. Reuse only the exact task-local path.
    assert local.resolve().parent == (ROOT / "release-local").resolve()
    if local.exists():
        shutil.rmtree(local)
    local.mkdir(parents=True)
    dependency = local / "dependency"
    with zipfile.ZipFile(archive) as z:
        names = z.namelist()
        banned = {"research", "release-local", "_build", "target", ".git", ".github", "output", "__pycache__"}
        for name in names:
            path = PurePosixPath(name.replace("\\", "/"))
            assert not path.is_absolute() and ".." not in path.parts
            assert not any(p in banned for p in path.parts), name
        for required in ("moon.mod", "moon.pkg", "types.mbt", "parser.mbt", "queries.mbt", "task_types.mbt", "process.mbt", "task_capture.mbt", "task_report.mbt", "pkg.generated.mbti", "README.md", "LICENSE", "THIRD_PARTY.md", "fixtures/contention.locks", "fixtures/task-session.json"):
            assert required in [n.replace("\\", "/") for n in names], required
        for required in ("file_capture.mbt", "task_compare.mbt", "fixtures/file-session.json"):
            assert required in [n.replace("\\", "/") for n in names], required
        z.extractall(dependency)
    # Run the packaged executable before creating the isolated workspace.
    standalone = run("moon", "run", "cmd/main", "--target", "js", "--", "inspect", "fixtures/contention.locks", "--json", cwd=dependency)
    assert len(json.loads(standalone.stdout)["entries"]) == 6
    task = run("moon", "run", "cmd/main", "--target", "js", "--", "report", "fixtures/task-session.json", "--json", cwd=dependency)
    assert json.loads(task.stdout)["report"]["sample_count"] == 3
    consumer = local / "consumer"
    consumer.mkdir()
    (local / "moon.work").write_text('members = ["dependency", "consumer"]\n')
    (consumer / "moon.mod").write_text('name = "local/locklens-consumer"\nversion = "0.0.1"\nimport { "length-super/moonlocklens@0.4.0" }\n')
    (consumer / "moon.pkg").write_text('import { "length-super/moonlocklens" @locks } for "test"\n')
    (consumer / "consumer_test.mbt").write_text('''///|
test "archive consumer sees public constructors and methods" {
  let s = @locks.parse("1: POSIX ADVISORY WRITE 1 08:01:42 0 EOF\\n1: -> POSIX ADVISORY WRITE 2 08:01:42 10 20")
  assert_eq(s.wait_chain(2).map(e => e.line), [2, 1])
  assert_eq(s.bottlenecks()[0].total_waiters, 1)
  let key : @locks.FileKey = { major: 8U, minor: 1U, inode: 42UL }
  assert_eq(s.query_range(key, @locks.byte_range("20", "20")).length(), 2)
  assert_eq(s.entry(1).owner, @locks.Process(1))
  assert_eq(s.matching(pid=2).map(e => e.line), [2])
  assert_eq(s.with_blockers([2]).map(e => e.line), [1, 2])
}
''')
    wire = json.dumps((dependency / "fixtures/task-session.json").read_text(encoding="utf8"))
    with (consumer / "consumer_test.mbt").open("a", encoding="utf8") as stream:
        stream.write('\n///|\ntest "archive task report API" {\n  let c = @locks.parse_task_capture(' + wire + ')\n  assert_eq(c.report().max_consecutive_wait_samples, 2)\n  assert_true(c.report().to_markdown().contains("Observed transitions"))\n}\n')
    results = {}
    file_wire = json.dumps((dependency / "fixtures/file-session.json").read_text(encoding="utf8"))
    with (consumer / "consumer_test.mbt").open("a", encoding="utf8") as stream:
        stream.write('\n///|\ntest "archive file capture API" {\n  let r = @locks.parse_file_capture(' + file_wire + ').report()\n  assert_eq(r.peak_waiting_records, 1)\n  assert_eq(r.frames[0].entries[1].owner, @locks.OpenDescription)\n  assert_true(r.to_markdown().contains("owner -1 remains unknown"))\n}\n')
    for target in ("wasm-gc", "js"):
        output = run("moon", "test", "--package", "local/locklens-consumer", "--target", target, "--deny-warn", cwd=consumer)
        results[target] = (output.stdout + output.stderr).strip()
    evidence = {"schema": 1, "archive": archive.name, "actual_files": len(names), "consumer": results, "extracted_cli": "passed", "source": "actual ZIP extraction; isolated workspace contains only extracted dependency and consumer"}
    (ROOT / "release-local/package-files.json").write_text(json.dumps(names, indent=2))
    (ROOT / "release-local/package-evidence.json").write_text(json.dumps(evidence, indent=2))
    print(json.dumps(evidence, indent=2))


if __name__ == "__main__":
    main()
