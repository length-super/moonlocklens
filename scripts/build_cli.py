#!/usr/bin/env python3
"""Build an offline CLI distribution that needs Node.js only."""
from datetime import datetime
from pathlib import Path
import shutil
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
VERSION = "0.4.0"


def main():
    subprocess.run(["moon", "build", "--target", "js", "--deny-warn"], cwd=ROOT, check=True)
    folder = ROOT / "output/cli" / ("moonlocklens-" + VERSION)
    (folder / "lib").mkdir(parents=True, exist_ok=True)
    source = (ROOT / "_build/js/debug/build/cmd/main/main.js").read_text(encoding="utf8")
    (folder / "lib/main.cjs").write_text("\n".join(line for line in source.splitlines() if not line.startswith("//# sourceMappingURL="))+"\n", encoding="utf8", newline="\n")
    (folder / "moonlocklens.cmd").write_text('@echo off\r\nnode "%~dp0lib\\main.cjs" %*\r\n', encoding="utf8", newline="")
    (folder / "moonlocklens").write_text('#!/bin/sh\nset -eu\nbase=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)\nexec node "$base/lib/main.cjs" "$@"\n', encoding="utf8", newline="\n")
    for name in ("LICENSE", "THIRD_PARTY.md"):
        shutil.copy2(ROOT / name, folder / name)
    shutil.copy2(ROOT / "docs/cli-guide.md", folder / "README.md")
    (folder / "fixtures").mkdir(exist_ok=True)
    shutil.copy2(ROOT / "fixtures/contention.locks", folder / "fixtures/contention.locks")
    shutil.copy2(ROOT / "fixtures/task-session.json", folder / "fixtures/task-session.json")
    shutil.copy2(ROOT / "fixtures/file-session.json", folder / "fixtures/file-session.json")
    archive = folder.parent / (folder.name + ".zip")
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as z:
        for file in sorted(folder.rglob("*")):
            if file.is_file():
                entry = zipfile.ZipInfo(folder.name + "/" + file.relative_to(folder).as_posix(), datetime.now().timetuple()[:6])
                entry.create_system = 3
                entry.external_attr = (0o100755 if file.name == "moonlocklens" else 0o100644) << 16
                entry.compress_type = zipfile.ZIP_DEFLATED
                z.writestr(entry, file.read_bytes())
    print(archive)


if __name__ == "__main__":
    main()
