#!/usr/bin/env python3
"""Exercise local-server gameplay and verify cleanup after a client crash."""
import argparse
import json
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import time
from urllib.parse import urlsplit

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--godot', required=True)
args = parser.parse_args()
repo = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix='ao-local-demo-') as temporary:
    output = Path(temporary)
    state = output / 'state.json'
    with (output / 'host.log').open('w') as log:
        host = subprocess.Popen([args.godot, '--headless', '--path', str(repo),
                                 '--script', 'tests/local_demo_host.gd', '--',
                                 '--demo-state-output=' + str(state)], cwd=repo,
                                stdout=log, stderr=subprocess.STDOUT)
        try:
            deadline = time.monotonic() + 20
            while not state.exists():
                if host.poll() is not None or time.monotonic() > deadline:
                    raise RuntimeError((output / 'host.log').read_text())
                time.sleep(0.05)
            url = json.loads(state.read_text())['url']
            subprocess.run([sys.executable, str(repo / 'tests/run_lobby_network.py'),
                            '--godot', args.godot, '--external-url', url,
                            '--output', str(output / 'network')], cwd=repo, check=True)
            endpoint = urlsplit(url)
            host.kill()
            host.wait(timeout=5)
            deadline = time.monotonic() + 13
            while time.monotonic() < deadline:
                with socket.socket() as probe:
                    probe.settimeout(0.5)
                    if probe.connect_ex((endpoint.hostname, endpoint.port)) != 0:
                        break
                time.sleep(0.2)
            else:
                raise RuntimeError('The dedicated survived the local client crash.')
            print('PASS: Local gameplay and dedicated shutdown after a client crash.')
        finally:
            if host.poll() is None:
                host.terminate()
                host.wait(timeout=5)
