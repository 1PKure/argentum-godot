#!/usr/bin/env python3
import argparse
import json
import os
import pathlib
import shutil
import subprocess
import tempfile
import time

parser = argparse.ArgumentParser(description="Rendered two-client lobby/input regression against an exported Godot PCK.")
parser.add_argument("--godot", default="godot")
parser.add_argument("--pck", required=True)
parser.add_argument("--xvfb", default=shutil.which("Xvfb") or "Xvfb")
parser.add_argument("--library-path", help="Optional additional LD_LIBRARY_PATH for a local Xvfb runtime")
parser.add_argument("--display", type=int, default=191)
parser.add_argument("--output", help="Fresh log and capture directory")
args = parser.parse_args()
repo = pathlib.Path(__file__).resolve().parent.parent
binary = args.godot
pack = pathlib.Path(args.pck).resolve()
output = pathlib.Path(args.output).resolve() if args.output else pathlib.Path(tempfile.mkdtemp(prefix="ao-lobby-native-"))
output.mkdir(parents=True, exist_ok=True)
if any(output.iterdir()):
    raise SystemExit("Use an empty output directory to keep coordination markers isolated.")
env = os.environ.copy()
if args.library_path:
    env["LD_LIBRARY_PATH"] = args.library_path
if not pack.is_file():
    raise SystemExit("Exported PCK does not exist: " + str(pack))
env["DISPLAY"] = "127.0.0.1:" + str(args.display)
files=[]
processes=[]
failed=False

def spawn(label,args):
    file=(output/(label+'.log')).open('w')
    files.append(file)
    process=subprocess.Popen(args,cwd=repo,env=env,stdout=file,stderr=subprocess.STDOUT)
    processes.append(process)
    return process

try:
    xv=spawn('xvfb',[args.xvfb,':'+str(args.display),'-screen','0','1920x1080x24','-listen','tcp','-ac'])
    time.sleep(.5)
    if xv.poll() is not None: raise RuntimeError('Xvfb191 did not start')
    server=spawn('server',[str(binary),'--headless','--path',str(repo),'--log-file',str(output/'engine-server.log'),'--','--server'])
    deadline=time.monotonic()+10
    while time.monotonic()<deadline:
        if 'Argentum server ready.' in (output/'server.log').read_text(): break
        if server.poll() is not None: raise RuntimeError('Dedicated startup failed')
        time.sleep(.05)
    clients=[]
    for role in ['host','guest']:
        client=spawn(role,[str(binary),'--path',str(repo),'--main-pack',str(pack),'--audio-driver','Dummy','--rendering-method','gl_compatibility','--log-file',str(output/('engine-'+role+'.log')),'--script',str(repo/'tests/lobby_native_client.gd'),'--','--no-auto-server','--lobby-role='+role,'--lobby-markers='+str(output)])
        clients.append((role,client))
        time.sleep(.3)
    for role,client in clients:
        try: code=client.wait(timeout=80)
        except subprocess.TimeoutExpired: code=-1
        path=output/(role+'-result.json')
        result=json.loads(path.read_text()) if path.exists() else {}
        log=(output/(role+'.log')).read_text()
        print(role,'exit',code,'result',result)
        if code!=0 or result.get('failures',-1)!=0 or 'ERROR:' in log or 'FAIL [' in log:
            failed=True
            print(log[-14000:])
    server_log=(output/'server.log').read_text()
    if 'ERROR:' in server_log:
        failed=True
        print(server_log[-5000:])
finally:
    for process in processes:
        if process.poll() is None: process.terminate()
    for process in processes:
        try:process.wait(timeout=3)
        except subprocess.TimeoutExpired:process.kill();process.wait(timeout=3)
    for file in files:file.close()
print('Logs/captures:',output)
raise SystemExit(1 if failed else 0)
