"""Real WebSocket probes and a controlled movement acknowledgment delay."""
import argparse,pathlib,subprocess,tempfile,time
parser=argparse.ArgumentParser();parser.add_argument('--godot',required=True);args=parser.parse_args()
root=pathlib.Path(__file__).resolve().parents[1]
out=pathlib.Path(tempfile.mkdtemp(prefix='ao-diagnostic-network-'))
command=[args.godot,'--headless','--path',str(root),'--script','tests/diagnostic_network.gd']
with (out/'server.log').open('w') as log:
    server=subprocess.Popen(command+['--','--diagnostic-server'],cwd=root,stdout=log,stderr=subprocess.STDOUT)
    try:
        deadline=time.monotonic()+10
        while 'DIAGNOSTIC SERVER READY' not in (out/'server.log').read_text():
            if server.poll() is not None or time.monotonic()>deadline:raise RuntimeError('Dedicated startup failed; inspect '+str(out))
            time.sleep(.05)
        result=subprocess.run(command,cwd=root,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=15)
        (out/'client.log').write_text(result.stdout)
        print(result.stdout)
        if result.returncode or 'ERROR:' in result.stdout:raise RuntimeError('Diagnostic regression failed')
    finally:
        server.terminate()
        try:server.wait(timeout=5)
        except subprocess.TimeoutExpired:server.kill();server.wait()
print('Logs:',out)
