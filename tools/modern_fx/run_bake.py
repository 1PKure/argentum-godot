"""Regenerate approved procedural FX; --metadata-only verifies existing atlas bounds."""
import argparse,os,pathlib,subprocess,time,sys
p=argparse.ArgumentParser();p.add_argument('--godot',required=True);p.add_argument('--xvfb',required=True);p.add_argument('--library-path',default='');p.add_argument('--display',default='198');p.add_argument('--metadata-only',action='store_true');args=p.parse_args()
repo=pathlib.Path(__file__).resolve().parents[2]
env=os.environ.copy();env['DISPLAY']='127.0.0.1:'+args.display
if args.library_path:env['LD_LIBRARY_PATH']=args.library_path
with open('/tmp/ao-bake-xvfb.log','w') as log:
 x=subprocess.Popen([args.xvfb,':'+args.display,'-screen','0','1280x800x24','-listen','tcp','-ac'],env=env,stdout=log,stderr=log)
 try:
  time.sleep(.4)
  if x.poll()!=None:raise RuntimeError('Xvfb failed; see /tmp/ao-bake-xvfb.log')
  command=[args.godot,'--path',str(repo),'--audio-driver','Dummy','--rendering-method','gl_compatibility','--script','tools/modern_fx/bake.gd']
  if args.metadata_only:command+=['--','--metadata-only']
  subprocess.run(command,cwd=repo,env=env,check=True)
 finally:x.terminate();x.wait()
if not args.metadata_only:subprocess.run([sys.executable,str(repo/'tools/modern_fx/unpremultiply.py')],check=True)
