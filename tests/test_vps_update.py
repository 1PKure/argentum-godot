"""Exercise the maintenance script without Docker, secrets, or a live server."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'hosting/vps/update-game.sh'
NEW = 'a' * 40
OLD = 'b' * 40

class UpdateTest(unittest.TestCase):
    def run_update(self, fault=''):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        (root / 'hosting/vps').mkdir(parents=True)
        self.env_file = root / 'hosting/vps/.env'
        self.original = f'AO_SOURCE_SHA={OLD}\nAO_STORE_KEY=private-test-value\nAO_HOST=test.invalid\n'
        self.env_file.write_text(self.original)
        binaries = root / 'bin'
        binaries.mkdir()
        for tool in ['git', 'docker']:
            target = binaries / tool
            target.write_text('''#!/usr/bin/env python3
import io,json,os,pathlib,sys,tarfile
args=sys.argv[1:]
root=pathlib.Path(os.environ['AO_REPO_ROOT'])
with (root/'calls.jsonl').open('a') as log:log.write(json.dumps([pathlib.Path(sys.argv[0]).name]+args)+'\\n')
if pathlib.Path(sys.argv[0]).name=='git':
 if args[0]=='archive':
  with tarfile.open(fileobj=sys.stdout.buffer,mode='w|') as archive:
   info=tarfile.TarInfo('hosting/Dockerfile'); data=b'FROM scratch\\n';info.size=len(data);archive.addfile(info,io.BytesIO(data))
 sys.exit(0)
if args[0]=='inspect': print('ao-mini-pilot:'+('b'*40))
if args[0]=='build' and os.environ.get('FAULT')=='build':sys.exit(2)
if 'up' in args and os.environ.get('FAULT')=='health' and ('AO_SOURCE_SHA='+('a'*40)) in (root/'hosting/vps/.env').read_text():sys.exit(3)
''')
            target.chmod(0o700)
        env = dict(os.environ, AO_REPO_ROOT=str(root), FAULT=fault, PATH=str(binaries)+os.pathsep+os.environ['PATH'])
        result = subprocess.run(['bash', str(SCRIPT), NEW], env=env, capture_output=True, text=True, timeout=10)
        self.calls = [json.loads(line) for line in (root/'calls.jsonl').read_text().splitlines()]
        self.assertNotIn('private-test-value', result.stdout+result.stderr)
        backups = list((root/'hosting/vps/ranking-backups').glob('*.env'))
        self.assertEqual(len(backups),1)
        self.assertEqual(backups[0].read_text(),self.original)
        self.assertEqual(backups[0].stat().st_mode & 0o777, 0o600)
        return result

    def test_success_builds_exact_commit_and_preserves_secrets(self):
        result = self.run_update()
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertIn('AO_SOURCE_SHA='+NEW,self.env_file.read_text())
        self.assertIn('AO_STORE_KEY=private-test-value',self.env_file.read_text())
        self.assertIn(['git','archive',NEW],self.calls)
        stops = [i for i,c in enumerate(self.calls) if 'stop' in c]
        builds = [i for i,c in enumerate(self.calls) if c[0:2]==['docker','build']]
        self.assertLess(stops[0],builds[0])
        self.assertEqual(len([c for c in self.calls if 'up' in c]),1)

    def test_failed_build_restarts_previous_image(self):
        result = self.run_update('build')
        self.assertNotEqual(result.returncode,0)
        self.assertEqual(self.env_file.read_text(),self.original)
        self.assertEqual(len([c for c in self.calls if 'up' in c]),1)

    def test_failed_health_restores_previous_configuration(self):
        result = self.run_update('health')
        self.assertNotEqual(result.returncode,0)
        self.assertEqual(self.env_file.read_text(),self.original)
        self.assertEqual(len([c for c in self.calls if 'up' in c]),2)

if __name__ == '__main__':unittest.main()
