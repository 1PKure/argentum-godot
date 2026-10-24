"""Real Godot coordinator + HTTP gateway + PostgreSQL WASM, across process restarts."""
import argparse,json,os,pathlib,subprocess,tempfile,time,shutil
p=argparse.ArgumentParser();p.add_argument('--godot',required=True);p.add_argument('--output');a=p.parse_args()
repo=pathlib.Path(__file__).resolve().parents[1]
out=pathlib.Path(a.output or tempfile.mkdtemp(prefix='ao-remote-qa-')).resolve();out.mkdir(parents=True,exist_ok=True)
if any(out.iterdir()):raise SystemExit('Output must be empty')
for restore in [False,True]:
 metadata=out/'fixture.json';metadata.unlink(missing_ok=True)
 with (out/('fixture-restore.log' if restore else 'fixture.log')).open('w') as log:
  fixture=subprocess.Popen(['node','hosting/tests/native-fixture.mjs',str(out)],cwd=repo,stdout=log,stderr=subprocess.STDOUT)
  try:
   deadline=time.monotonic()+20
   while not metadata.exists() and time.monotonic()<deadline:
    if fixture.poll() is not None:raise RuntimeError('Fixture exited; inspect logs')
    time.sleep(.05)
   settings=json.loads(metadata.read_text());env=os.environ.copy();env.update(AO_STORE_URL=settings['url'],AO_STORE_TOKEN=settings['token'],AO_TEST_CONTROL=settings['control'],XDG_DATA_HOME=str(out/('fresh-cache' if restore else 'cache')))
   args=[a.godot,'--headless','--path',str(repo),'--script','tests/remote_ranking_smoke.gd']
   if restore:args+=['--','--restore']
   r=subprocess.run(args,cwd=repo,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=45)
   (out/('restore.log' if restore else 'initial.log')).write_text(r.stdout)
   print('\n'.join(line for line in r.stdout.splitlines() if any(tag in line for tag in ['checks:','FAIL','ERROR'])))
   if r.returncode or 'ERROR:' in r.stdout or 'FAIL:' in r.stdout:raise RuntimeError('Native persistence regression failed')
  finally:
   fixture.terminate()
   try:fixture.wait(timeout=10)
   except subprocess.TimeoutExpired:fixture.kill();fixture.wait()
print('Persistence/restart verification passed; logs:',out)
