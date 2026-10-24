#!/usr/bin/env python3
"""Update the exported game without changing the already-tested web engine/site."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import struct
import zipfile

parser = argparse.ArgumentParser()
parser.add_argument('--base-zip', required=True)
parser.add_argument('--pck', required=True)
parser.add_argument('--source-sha', required=True)
parser.add_argument('--output', required=True)
a = parser.parse_args()
if not re.fullmatch(r'[0-9a-f]{40}',a.source_sha):
    raise SystemExit('Use the full tested commit SHA.')
output = Path(a.output)
if output.exists() or output.resolve() == Path(a.base_zip).resolve():
    raise SystemExit('Choose a new output ZIP; preserve the previous release.')
pck = Path(a.pck).read_bytes()
with zipfile.ZipFile(a.base_zip) as source:
    files = {name:source.read(name) for name in source.namelist() if not name.endswith('/')}
if any(Path(name).is_absolute() or '..' in Path(name).parts for name in files):
    raise SystemExit('Unsafe ZIP path.')
if struct.unpack('<5I',files['index.pck'][:20]) != struct.unpack('<5I',pck[:20]):
    raise SystemExit('PCK engine format/version differs from the deployed runtime.')
config = json.loads(files['arena-config.json'])
if not config['server_url'].startswith('wss://') or '?' in config['server_url']:
    raise SystemExit('Expected the public WSS configuration without invitation tokens.')
html = files['play.html'].decode()
match = re.search(r'const GODOT_CONFIG = (\{[^\n]+\});',html)
if not match:raise SystemExit('Missing Godot loader configuration.')
godot = json.loads(match[1])
godot['fileSizes']['index.pck'] = len(pck)
files['play.html'] = (html[:match.start(1)]+json.dumps(godot,separators=(',',':'))+html[match.end(1):]).encode()
files['index.pck'] = pck
files['release.json'] = json.dumps({'source_sha':a.source_sha,'pck_sha256':hashlib.sha256(pck).hexdigest()},indent=2).encode()+b'\n'
if any(len(data)>25*1024*1024 for data in files.values()):
    raise SystemExit('An asset exceeds the current static upload file-size budget.')
with zipfile.ZipFile(output,'x',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as target:
    for name,data in files.items():target.writestr(name,data)
print(json.dumps({'file':str(output),'bytes':output.stat().st_size,'source_sha':a.source_sha,'pck_sha256':hashlib.sha256(pck).hexdigest()}))
