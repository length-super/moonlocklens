#!/usr/bin/env python3
"""Portable offline checks. Use MOON_HOME/PATH to select one coherent toolchain."""
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def run(*args):
    subprocess.run(args, cwd=ROOT, check=True)


def main():
    run("moon", "version", "--all")
    run("moon", "fmt", "--check")
    for target in ("wasm-gc", "js"):
        for action in ("check", "build", "test"):
            run("moon", action, "--target", target, "--deny-warn")
        run("moon", "run", "examples/demo", "--target", target)
    run("moon", "info", "--target", "wasm-gc")
    for args in (("inspect", "fixtures/contention.locks"), ("chain", "fixtures/contention.locks", "3"),
                 ("range", "fixtures/contention.locks", "08:01:42", "99", "99")):
        run("moon", "run", "cmd/main", "--target", "js", "--", *args)
    run(sys.executable, "scripts/verify_cli.py")
    run(sys.executable, "scripts/verify_task_cli.py")
    run(sys.executable, "scripts/verify_file_cli.py")


if __name__ == "__main__":
    main()
