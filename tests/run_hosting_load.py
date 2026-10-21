#!/usr/bin/env python3
"""Local, synthetic real-WS soak. Measures one dedicated process, not Internet capacity."""
import argparse,json,os,pathlib,subprocess,time,statistics,platform
p=argparse.ArgumentParser();p.add_argument('--godot',required=True);p.add_argument('--clients',type=int,default=8);p.add_argument('--seconds',type=float,default=12);p.add_argument('--output',required=True);a=p.parse_args()
if not 2<=a.clients<=64 or a.clients%2: p.error('Use an even client count between 2 and 64.')
repo=pathlib.Path(__file__).resolve().parent.parent;out=pathlib.Path(a.output).resolve();out.mkdir(parents=True,exist_ok=True)
if any(out.iterdir()): raise SystemExit('Use a fresh output folder.')
processes=[];handles=[]
def spawn(label,cmd,extra=None):
 h=(out/(label+'.log')).open('w');handles.append(h);env=os.environ.copy()
 if extra:env.update(extra)
 proc=subprocess.Popen(cmd,cwd=repo,env=env,stdout=h,stderr=subprocess.STDOUT);processes.append(proc);return proc
try:
 server=spawn('server',[a.godot,'--headless','--path',str(repo),'--','--server','--port=17901','--ranking-path='+str(out/'ranking.json')])
 deadline=time.monotonic()+15
 while time.monotonic()<deadline:
  if 'Argentum server ready.' in (out/'server.log').read_text():break
  if server.poll() is not None:raise RuntimeError('Server failed to start.')
  time.sleep(.05)
 clients=[]
 for i in range(a.clients):
  clients.append(spawn('client-'+str(i),[a.godot,'--headless','--path',str(repo),'--script','tests/hosting_load_client.gd','--','--no-auto-server','--load-index='+str(i),'--load-count='+str(a.clients),'--load-folder='+str(out),'--load-seconds='+str(a.seconds)],{'XDG_DATA_HOME':str(out/'userdata'/str(i))}))
  time.sleep(.08)
 deadline=time.monotonic()+45
 while time.monotonic()<deadline:
  if len(list(out.glob('ready-*')))==a.clients:break
  if any(c.poll() is not None for c in clients):raise RuntimeError('Client failed before barrier. Inspect logs.')
  time.sleep(.05)
 else:raise RuntimeError('Not all clients reached fighting phase.')
 # Resolve the actual procfs PID by command identity. Some sandboxes expose
 # host procfs IDs while Popen returns a nested namespace's PID.
 server_proc=None
 for entry in pathlib.Path('/proc').iterdir():
  if not entry.name.isdigit():continue
  try:cmd=(entry/'cmdline').read_bytes().split(b'\0')
  except (FileNotFoundError,PermissionError,ProcessLookupError):continue
  if b'--port=17901' in cmd and b'--server' in cmd and pathlib.Path(cmd[0].decode()).name.startswith('Godot'):
   if server_proc is not None:raise RuntimeError('More than one matching server process; refusing misleading metrics.')
   server_proc=entry
 if server_proc is None:raise RuntimeError('Could not verify server identity in procfs; cannot report CPU/RSS.')
 def sample():
  fields=(server_proc/'stat').read_text().rsplit(') ',1)[1].split()
  ticks=int(fields[11])+int(fields[12]);rss=int(fields[21])*os.sysconf('SC_PAGE_SIZE')/1024/1024
  return ticks,rss
 first,_=sample();started=time.monotonic();memory=[];cpu=[];last=first;last_at=started
 (out/'go').write_text('go')
 while len(list(out.glob('done-*')))<a.clients and time.monotonic()-started<a.seconds+10:
  ticks,rss=sample();now=time.monotonic();memory.append(rss);cpu.append((ticks-last)/os.sysconf('SC_CLK_TCK')/(now-last_at)*100);last=ticks;last_at=now;time.sleep(.2)
 (out/'stop').write_text('stop')
 for client in clients:client.wait(timeout=25)
 results=[json.loads((out/('client-'+str(i)+'.json')).read_text()) for i in range(a.clients)]
 errors=[i for i,c in enumerate(clients) if c.poll()!=0 or not results[i]['ok']]
 errors += ['server'] if 'ERROR:' in (out/'server.log').read_text() else []
 rtts=sorted(x for r in results for x in r['chat_rtt_ms'])
 summary={'environment':'Local Linux/container, loopback WS; not Internet or provider capacity','cpu_count':os.cpu_count(),'clients':a.clients,'rooms':a.clients//2,'duration_seconds':a.seconds,'server_rss_peak_mib':round(max(memory),2),'server_cpu_mean_percent_one_core':round(statistics.mean(cpu),2),'server_cpu_p95_percent_one_core':round(sorted(cpu)[int(len(cpu)*.95)-1],2),'chat_rtt_p50_ms':statistics.median(rtts) if rtts else None,'chat_rtt_p95_ms':rtts[max(0,int(len(rtts)*.95)-1)] if rtts else None,'spell_events_received':sum(r['spell_events'] for r in results),'failed_clients':errors,'workload':'Every client: move/150ms, self-heal/1050ms, mana potion/300ms, room chat/1500ms. No renderer, simulated delay or TLS. Steady-state samples exclude peer cleanup. Procfs PID verified by executable/port.'}
 (out/'summary.json').write_text(json.dumps(summary,indent=2));print(json.dumps(summary,indent=2))
 if errors:raise SystemExit(1)
finally:
 for proc in processes:
  if proc.poll() is None:proc.terminate()
 for proc in processes:
  try:proc.wait(timeout=3)
  except subprocess.TimeoutExpired:proc.kill();proc.wait(timeout=3)
 for h in handles:h.close()
