"""Run real dedicated + five clients through the production WebSocket gateway."""
import argparse, json, os, pathlib, subprocess, tempfile, time
p=argparse.ArgumentParser(); p.add_argument('--godot',required=True); a=p.parse_args()
repo=pathlib.Path(__file__).resolve().parents[1]
out=pathlib.Path(tempfile.mkdtemp(prefix='ao-gateway-lobby-'))
env=os.environ.copy(); env.update(TEST_GODOT=a.godot,TEST_GAME_PORT='17878',XDG_DATA_HOME=str(out/'profiles'))
with (out/'fixture.log').open('w') as log:
    fixture=subprocess.Popen(['node','hosting/tests/native-fixture.mjs',str(out)],cwd=repo,env=env,stdout=log,stderr=subprocess.STDOUT)
    try:
        deadline=time.monotonic()+25
        while time.monotonic()<deadline:
            if fixture.poll() is not None: raise RuntimeError('Gateway exited; inspect '+str(out))
            if (out/'fixture.json').exists() and 'Argentum server ready.' in (out/'fixture.log').read_text(): break
            time.sleep(.1)
        else: raise RuntimeError('Gateway startup timed out; inspect '+str(out))
        metadata=json.loads((out/'fixture.json').read_text())
        url=f"ws://127.0.0.1:{metadata['port']}/game?ticket=local-test-ticket-12345678901234567890"
        result=subprocess.run(['python3','tests/run_lobby_network.py','--godot',a.godot,'--external-url',url,'--output',str(out/'clients')],cwd=repo,env=env,timeout=180)
        if result.returncode: raise RuntimeError('Gateway lobby regression failed')
        if 'ERROR:' in (out/'fixture.log').read_text(): raise RuntimeError('Dedicated logged errors')
    finally:
        fixture.terminate()
        try: fixture.wait(timeout=10)
        except subprocess.TimeoutExpired: fixture.kill(); fixture.wait()
print('Gateway lobby verification passed; logs:',out)
