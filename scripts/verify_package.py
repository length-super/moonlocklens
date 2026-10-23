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
    archive = ROOT / "_build/publish/local-moonlocklens-0.1.0.zip"
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
        for required in ("moon.mod", "moon.pkg", "types.mbt", "parser.mbt", "queries.mbt", "pkg.generated.mbti", "README.md", "LICENSE", "THIRD_PARTY.md", "fixtures/contention.locks"):
            assert required in [n.replace("\\", "/") for n in names], required
        z.extractall(dependency)
    # Run the packaged executable before creating the isolated workspace.
    standalone = run("moon", "run", "cmd/main", "--target", "js", "--", "inspect", "fixtures/contention.locks", cwd=dependency)
    assert len(json.loads(standalone.stdout)["entries"]) == 6
    consumer = local / "consumer"
    consumer.mkdir()
    (local / "moon.work").write_text('members = ["dependency", "consumer"]\n')
    (consumer / "moon.mod").write_text('name = "local/locklens-consumer"\nversion = "0.0.1"\nimport { "local/moonlocklens@0.1.0" }\n')
    (consumer / "moon.pkg").write_text('import { "local/moonlocklens" @locks } for "test"\n')
    (consumer / "consumer_test.mbt").write_text('''///|
test "archive consumer sees public constructors and methods" {
  let s = @locks.parse("1: POSIX ADVISORY WRITE 1 08:01:42 0 EOF\\n1: -> POSIX ADVISORY WRITE 2 08:01:42 10 20")
  assert_eq(s.wait_chain(2).map(e => e.line), [2, 1])
  assert_eq(s.bottlenecks()[0].total_waiters, 1)
  let key : @locks.FileKey = { major: 8U, minor: 1U, inode: 42UL }
  assert_eq(s.query_range(key, @locks.byte_range("20", "20")).length(), 2)
  assert_eq(s.entry(1).owner, @locks.Process(1))
}
''')
    results = {}
    for target in ("wasm-gc", "js"):
        output = run("moon", "test", "--package", "local/locklens-consumer", "--target", target, "--deny-warn", cwd=consumer)
        results[target] = (output.stdout + output.stderr).strip()
    evidence = {"schema": 1, "archive": archive.name, "actual_files": len(names), "consumer": results, "extracted_cli": "passed", "source": "actual ZIP extraction; isolated workspace contains only extracted dependency and consumer"}
    (ROOT / "release-local/package-files.json").write_text(json.dumps(names, indent=2))
    (ROOT / "release-local/package-evidence.json").write_text(json.dumps(evidence, indent=2))
    print(json.dumps(evidence, indent=2))


if __name__ == "__main__":
    main()
