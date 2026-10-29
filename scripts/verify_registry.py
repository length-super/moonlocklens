#!/usr/bin/env python3
"""Install the exact published version without a local workspace override."""
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
MODULE = "length-super/moonlocklens"
VERSION = "0.3.0"


def main():
    consumer = ROOT / "release-local/registry-consumer-0.3.0"
    consumer.mkdir(parents=True, exist_ok=True)
    for parent in (consumer, *consumer.parents):
        assert not (parent / "moon.work").exists(), "registry check must not inherit a workspace"
    (consumer / "moon.mod").write_text('name = "local/registry-consumer"\nversion = "0.0.1"\n', encoding="utf8")
    (consumer / "moon.pkg").write_text('import { "length-super/moonlocklens" @locks } for "test"\n', encoding="utf8")

    def run(*args):
        result = subprocess.run(args, cwd=consumer, text=True, capture_output=True)
        if result.returncode:
            raise RuntimeError(result.stdout + result.stderr)
        return (result.stdout + result.stderr).strip()

    run("moon", "add", MODULE + "@" + VERSION)
    manifest = (consumer / "moon.mod").read_text(encoding="utf8")
    assert MODULE + "@" + VERSION in manifest, manifest
    tree = run("moon", "tree")
    assert MODULE in tree and VERSION in tree, tree
    wire = json.dumps((ROOT / "fixtures/task-session.json").read_text(encoding="utf8"))
    tests = '''///|
test "registry lock API" {
  let s = @locks.parse("1: POSIX ADVISORY WRITE 1 08:01:42 0 EOF\\n1: -> POSIX ADVISORY WRITE 2 08:01:42 10 20")
  assert_eq(s.wait_chain(2).map(e => e.line), [2, 1])
  assert_eq(s.bottlenecks()[0].total_waiters, 1)
  assert_eq(s.query_range(@locks.file_key("08:01:42"), @locks.byte_range("20", "20")).length(), 2)
  assert_eq(s.with_blockers(s.matching(pid=2).map(e => e.line)).map(e => e.line), [1, 2])
}
'''
    tests += '\n///|\ntest "registry task report API" {\n  let c = @locks.parse_task_capture(' + wire + ')\n  let r = c.report()\n  assert_eq(r.sample_count, 3)\n  assert_eq(r.max_consecutive_wait_samples, 2)\n  assert_eq(r.frames[0].processes[1].requests[0].parent_line, Some(1))\n  assert_true(r.to_markdown().contains("Observed transitions"))\n}\n'
    (consumer / "consumer_test.mbt").write_text(tests, encoding="utf8")
    results = {target: run("moon", "test", "--target", target, "--deny-warn") for target in ("wasm-gc", "js")}
    evidence = {"module": MODULE, "version": VERSION, "source": "public registry, no moon.work override", "dependency_tree": tree, "consumer": results}
    (ROOT / "release-local/registry-evidence.json").write_text(json.dumps(evidence, indent=2), encoding="utf8")
    print(json.dumps(evidence, indent=2))


if __name__ == "__main__":
    main()
