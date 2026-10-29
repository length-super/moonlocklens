"""Operational gate: pass, observed violation, inconclusive and usage errors."""
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
CLI = ROOT / "_build/js/debug/build/cmd/main/main.js"


def call(path, threshold, code, data=None):
    p = subprocess.run(["node", str(CLI), "gate", str(path), "--wait-samples", str(threshold), "--json"], input=data, capture_output=True, timeout=20)
    assert p.returncode == code, (p.returncode, p.stdout, p.stderr)
    if code in (0, 3, 4):
        assert not p.stderr
        r = json.loads(p.stdout)
        assert r['schema'] == 'moonlocklens-gate/1'
        return r['assessment']
    assert json.loads(p.stderr)['error']['message']


def main():
    for fixture in ('task-session.json', 'file-session.json'):
        path = ROOT / 'fixtures' / fixture
        assert call(path, 2, 3)['status'] == 'fail'
        assert call(path, 3, 0)['status'] == 'pass'
        assert call(path, 4, 4)['status'] == 'inconclusive'
        assert call('-', 2, 3, path.read_bytes())['observed_streak'] == 2
        call(path, 0, 2)
        call(path, 61, 2)
    with tempfile.TemporaryDirectory(dir=ROOT/'release-local', prefix='gate-cli-') as tmp:
        path = Path(tmp)/'gap.json'
        wire = json.loads((ROOT/'fixtures/file-session.json').read_text())
        wire['frames'][1]['locks_error'] = 'EACCES'
        path.write_text(json.dumps(wire))
        assert call(path, 3, 4)['evidence_gaps'] == 1
        path.write_text('{}')
        call(path, 2, 1)
    p = subprocess.run(['node',str(CLI),'report',str(ROOT/'fixtures/task-session.json'),'--wait-samples','2'],capture_output=True)
    assert p.returncode == 2
    print(json.dumps({'status':'passed','coverage':'task/file policies, sample threshold, full-window violations, insufficient samples, visibility gaps, stdin and exit statuses'}))


if __name__ == '__main__':
    main()
