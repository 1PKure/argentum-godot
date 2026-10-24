#!/usr/bin/env python3
"""Bounded owner-private pilot checks. No renderer, public opening, or fake wins.

Uses installed websockets (16+) and a loopback message bridge because the Work
runtime's supported HTTPS proxy is not implemented by Godot's native transport.
Every upstream connection still verifies public TLS and traverses the real VPS.
The client-only QA identity remains outside Git and is shared by synthetic peers;
this validates concurrent connections/rooms, not eight independent accounts.
"""
import argparse, asyncio, json, os, pathlib, secrets, subprocess, time, urllib.request
import urllib.error
import websockets

p = argparse.ArgumentParser()
p.add_argument('--godot', required=True)
p.add_argument('--config', required=True, help='Private deployed arena-config.json; never copied to results')
p.add_argument('--output', required=True)
p.add_argument('--identity', required=True, help='Reusable private QA identity outside repository')
p.add_argument('--seconds', type=int, default=300)
p.add_argument('--port', type=int, default=17877)
a = p.parse_args()
if not 30 <= a.seconds <= 900: p.error('Duration must be between 30 and 900 seconds.')
repo = pathlib.Path(__file__).resolve().parents[1]
if not (repo/'.godot'/'global_script_class_cache.cfg').exists():
    raise SystemExit('Import the project first: Godot --headless --editor --path <repo> --import')
out = pathlib.Path(a.output).resolve(); out.mkdir(parents=True, exist_ok=True)
if any(out.iterdir()): raise SystemExit('Use an empty output directory.')
config = json.loads(pathlib.Path(a.config).read_text())
url = config['server_url']; ranking_url = config['ranking_url']
origin = 'https://argentum-arena-mati.smartpine8.chatgpt.site'
identity_file = pathlib.Path(a.identity).resolve()
if identity_file.is_relative_to(repo): raise SystemExit('QA identity must be outside repository.')
identity_file.parent.mkdir(parents=True, exist_ok=True)
if not identity_file.exists():
    fd = os.open(identity_file, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, 'w') as f:
        json.dump({'id':secrets.token_hex(16), 'secret':secrets.token_hex(32), 'nickname':'QA_carga'}, f)
identity = json.loads(identity_file.read_text())
userdata = out/'userdata'/'godot'/'app_userdata'/'ArgentumGodot'; userdata.mkdir(parents=True)
cfg = ''.join('\n['+profile+']\n'+''.join(k+'="'+v+'"\n' for k,v in identity.items())
              for profile in ['local']+['__ranking_network_'+x for x in 'ABCDS'])
fd = os.open(userdata/'ranking_identity_v1.cfg', os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
with os.fdopen(fd,'w') as f: f.write(cfg)
processes=[]; handles=[]; bridge_failures=[]
summary={'environment':'Work native headless clients through supported HTTPS proxy to Chile public TLS/WSS',
         'rendering_audio_tested':False, 'independent_accounts':1, 'checks':{}, 'duration_seconds':a.seconds}

def read_http(target, request_origin=origin):
    request=urllib.request.Request(target,headers={'Origin':request_origin})
    try:
        with urllib.request.urlopen(request, timeout=15) as r:
            return r.status, json.load(r), r.headers.get('Access-Control-Allow-Origin')
    except urllib.error.HTTPError as e:
        return e.code, json.load(e), e.headers.get('Access-Control-Allow-Origin')

def spawn(label, command):
    f=(out/(label+'.log')).open('w'); handles.append(f)
    env=os.environ.copy(); env.update(XDG_DATA_HOME=str(out/'userdata'),AO_QA_URL=f'ws://127.0.0.1:{a.port}')
    proc=subprocess.Popen(command,cwd=repo,env=env,stdout=f,stderr=subprocess.STDOUT)
    processes.append(proc); return proc

async def bridge(local):
    try:
        async with websockets.connect(url,origin=origin,open_timeout=15,close_timeout=3,max_size=8*1024*1024) as remote:
            async def copy(source,target):
                async for message in source: await target.send(message)
            tasks=[asyncio.create_task(copy(local,remote)),asyncio.create_task(copy(remote,local))]
            done,pending=await asyncio.wait(tasks,return_when=asyncio.FIRST_COMPLETED)
            for task in pending: task.cancel()
            await asyncio.gather(*tasks,return_exceptions=True)
    except Exception as e:
        # Never include URLs, tickets, or exception request headers in logs.
        bridge_failures.append(type(e).__name__)
        await local.close(code=1011,reason='Remote validation connection failed')

async def wait_for(predicate,timeout):
    deadline=time.monotonic()+timeout
    while time.monotonic()<deadline:
        if predicate():return
        await asyncio.sleep(.1)
    raise RuntimeError('Timed out waiting for test clients; inspect sanitized logs')

async def main():
    base=url.split('/game?',1)[0].replace('wss:','https:')
    status,health,_=await asyncio.to_thread(read_http,base+'/healthz')
    summary['checks']['health_before']=status==200 and health=={'ready':True,'capacity':8}
    status,before,cors=await asyncio.to_thread(read_http,ranking_url)
    summary['checks']['ranking_before']=status==200 and cors==origin and before['entries'][0]['nickname']=='milusita' and before['entries'][0]['points']==9999999999
    status,_,_=await asyncio.to_thread(read_http,base+'/api/ranking')
    summary['checks']['ranking_requires_invitation']=status==403
    for label,target,test_origin in [('wrong_ticket',url.split('?')[0]+'?ticket=invalid',origin),('wrong_origin',url,'https://invalid.example')]:
        try:
            async with websockets.connect(target,origin=test_origin,open_timeout=15,close_timeout=2):pass
            summary['checks'][label+'_rejected']=False
        except websockets.exceptions.InvalidStatus as e:
            summary['checks'][label+'_rejected']=e.response.status_code==403
    async with websockets.serve(bridge,'127.0.0.1',a.port,max_size=8*1024*1024):
        # Full existing 4-peer/2-room isolation, chat, ready, bot, pause and map suite.
        proc=spawn('lobby-suite',['python3','tests/run_lobby_network.py','--godot',a.godot,'--external-url',f'ws://127.0.0.1:{a.port}','--output',str(out/'lobby')])
        await wait_for(lambda:proc.poll() is not None,200)
        summary['checks']['lobby_and_bot_suite']=proc.returncode==0
        print('Lobby and bot suite:',proc.returncode,flush=True)
        if proc.returncode:raise RuntimeError('Lobby regression failed; refusing to start soak')
        await asyncio.sleep(2)
        soak=out/'soak';soak.mkdir()
        clients=[]
        for i in range(8):
            clients.append(spawn('load-'+str(i),[a.godot,'--headless','--path',str(repo),'--script','tests/hosting_load_client.gd','--','--no-auto-server','--load-index='+str(i),'--load-count=8','--load-folder='+str(soak),'--load-seconds='+str(a.seconds)]))
            await asyncio.sleep(.4)
        await wait_for(lambda:len(list(soak.glob('ready-*')))==8 or any(c.poll() is not None for c in clients),60)
        if any(c.poll() is not None for c in clients):raise RuntimeError('Load client exited before barrier')
        summary['checks']['eight_clients_four_rooms']=True
        try:
            async with websockets.connect(url,origin=origin,open_timeout=15,close_timeout=2):pass
            summary['checks']['ninth_connection_rejected']=False
        except websockets.exceptions.InvalidStatus as e:
            summary['checks']['ninth_connection_rejected']=e.response.status_code==503
        (soak/'go').write_text('go');started=time.monotonic()
        print('Soak started: 8 clients / 4 rooms /',a.seconds,'seconds',flush=True)
        while len(list(soak.glob('done-*')))<8:
            if time.monotonic()-started>a.seconds+20:raise RuntimeError('Soak deadline exceeded')
            if any(c.poll() is not None for c in clients):raise RuntimeError('Load peer exited prematurely')
            await asyncio.sleep(1)
        (soak/'stop').write_text('stop')
        await wait_for(lambda:all(c.poll() is not None for c in clients),30)
        results=[json.loads((soak/f'client-{i}.json').read_text()) for i in range(8)]
        summary['checks']['soak_all_clients_pass']=all(r['ok'] and c.returncode==0 for r,c in zip(results,clients))
        summary['checks']['no_movement_or_probe_timeouts']=all(r['move_timeouts']==0 and r['probe_timeouts']==0 for r in results)
        summary['checks']['all_clients_confirmed_movement']=all(r['confirmed_moves']>0 for r in results)
        for key in ['spell_events','confirmed_moves','blocked_moves','move_timeouts','probe_timeouts']:
            summary[key]=sum(r[key] for r in results)
        for key in ['chat_rtt_ms','ping_samples_ms','move_samples_ms','server_samples_ms']:
            values=sorted(v for r in results for v in r[key])
            summary[key]={'samples':len(values),'p50':values[len(values)//2] if values else None,'p95':values[max(0,int(len(values)*.95)-1)] if values else None}
        await asyncio.sleep(2)
        async with websockets.connect(url,origin=origin,open_timeout=15,close_timeout=3) as remote:
            first=await asyncio.wait_for(remote.recv(),5)
            summary['checks']['reconnect_after_full_capacity']=isinstance(first,bytes) and len(first)==4
    status,after,_=await asyncio.to_thread(read_http,ranking_url)
    prior={e['nickname']:e for e in before['entries']}
    final={e['nickname']:e for e in after['entries']}
    summary['checks']['existing_ranking_entries_unchanged']=status==200 and all(final.get(k)==v for k,v in prior.items())
    qa=final.get(identity['nickname'],{})
    summary['checks']['qa_has_no_awarded_points']=qa.get('points')==0 and qa.get('wins')==0
    summary['checks']['no_bridge_failures']=not bridge_failures
    status,health,_=await asyncio.to_thread(read_http,base+'/healthz')
    summary['checks']['health_after']=status==200 and health['ready']
    summary['checks']['no_native_errors']=all('ERROR:' not in f.read_text() and 'SCRIPT ERROR' not in f.read_text() for f in out.rglob('*.log'))

try:
    asyncio.run(main())
except Exception as e:
    summary['failure_type']=type(e).__name__
    print('Validation stopped:',type(e).__name__,flush=True)
finally:
    for proc in processes:
        if proc.poll() is None: proc.terminate()
    for proc in processes:
        try:proc.wait(timeout=4)
        except subprocess.TimeoutExpired:proc.kill();proc.wait()
    for f in handles:f.close()
    summary['passed']='failure_type' not in summary and all(summary['checks'].values())
    (out/'summary.json').write_text(json.dumps(summary,indent=2))
    print(json.dumps(summary,indent=2))
raise SystemExit(0 if summary['passed'] else 1)
