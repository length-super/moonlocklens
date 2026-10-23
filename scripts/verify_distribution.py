#!/usr/bin/env python3
"""Test the extracted standalone archive from an unrelated working directory."""
import json
import os
from pathlib import Path
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    archive = ROOT / "output/cli/moonlocklens-0.2.0.zip"
    parent = ROOT / "release-local/cli-validation"
    parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive) as z:
        assert len(z.namelist()) == 7
        z.extractall(parent)
    folder = parent / "moonlocklens-0.2.0"
    cli = folder / "lib/main.cjs"
    fixture = folder / "fixtures/contention.locks"
    p = subprocess.run(["node", str(cli), "inspect", str(fixture), "--pid", "300", "--json"], cwd=parent, capture_output=True, text=True, check=True)
    assert json.loads(p.stdout)["matched_lines"] == [3] and not p.stderr
    if os.name == "nt":
        p = subprocess.run([os.environ.get("COMSPEC", "cmd.exe"), "/d", "/c", r"moonlocklens-0.2.0\moonlocklens.cmd", "--version"], cwd=parent, capture_output=True, text=True, check=True)
    else:
        p = subprocess.run(["sh", str(folder / "moonlocklens"), "--version"], cwd=parent, capture_output=True, text=True, check=True)
    assert "0.2.0" in p.stdout
    result = {"status": "passed", "archive": archive.name, "files": 7, "node_only_consumer": "passed", "launcher": "passed"}
    (ROOT / "release-local/distribution-evidence.json").write_text(json.dumps(result, indent=2))
    print(json.dumps(result))


if __name__ == "__main__":
    main()
