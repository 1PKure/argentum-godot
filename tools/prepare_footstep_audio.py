#!/usr/bin/env python3
"""Verify (or --restore) exact original AO20 footstep WAVs. Never process audio."""
import argparse
import hashlib
import json
from pathlib import Path
from urllib.request import urlopen


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--restore', action='store_true', help='Restore original bytes from the pinned resource commit')
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    manifest = json.loads((root/'assets/argentum/source/data/footstep_sources.json').read_text())
    for source in manifest['files']:
        path = root/'assets/argentum/source/audio'/source['file']
        if args.restore:
            url = f"https://raw.githubusercontent.com/ao-org/Recursos/{manifest['commit']}/wav/{source['file']}"
            with urlopen(url,timeout=30) as response:
                original = response.read()
            if hashlib.sha256(original).hexdigest()!=source['sha256']:
                raise ValueError('Source checksum mismatch: '+source['file'])
            path.write_bytes(original)
        if hashlib.sha256(path.read_bytes()).hexdigest()!=source['sha256']:
            raise ValueError('Local file differs from original: '+str(path))
    print('6 original AO20 footstep files verified byte-for-byte; no processing.')


if __name__=='__main__': main()
