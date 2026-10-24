#!/usr/bin/env python3
"""Export a portable Windows demo from a clean, committed source revision."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import zipfile


def sha256(path):
    with path.open('rb') as handle:
        return hashlib.file_digest(handle, 'sha256').hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True, help='Godot 4.7.2 Standard editor executable')
    parser.add_argument('--version', required=True, help='For example: 0.1.0-alpha.1')
    args = parser.parse_args()
    if not re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+(?:-[a-zA-Z0-9.]+)?', args.version):
        parser.error('Use a version such as 0.1.0-alpha.1.')
    repo = Path(__file__).resolve().parent.parent
    git = lambda *command: subprocess.check_output(['git', '-C', str(repo), *command], text=True).strip()
    if git('status', '--porcelain'):
        raise SystemExit('Commit or remove pending source changes before packaging.')
    source_sha = git('rev-parse', 'HEAD')
    engine = str(Path(args.godot).resolve())
    engine_version = subprocess.check_output([engine, '--version'], text=True).strip()
    if not engine_version.startswith('4.7.2.stable.'):
        raise SystemExit('Use Godot 4.7.2 Standard and matching export templates.')
    name = f'AO-Mini-{args.version}-Windows-x64'
    output = repo / 'builds' / 'releases' / name
    archive = output.parent / (name + '.zip')
    if output.exists() or archive.exists():
        raise SystemExit('Choose a new version or preserve/move the previous build first.')
    output.mkdir(parents=True)
    logs = repo / 'builds' / 'logs'
    logs.mkdir(parents=True, exist_ok=True)

    def run(label, *arguments):
        log = logs / f'{name}-{label}.log'
        with log.open('w', encoding='utf-8') as handle:
            result = subprocess.run([engine, '--headless', '--path', str(repo), *arguments],
                                    cwd=repo, stdout=handle, stderr=subprocess.STDOUT)
        content = log.read_text(encoding='utf-8', errors='replace')
        if result.returncode or 'SCRIPT ERROR:' in content or 'ERROR:' in content:
            raise SystemExit(f'{label} failed; inspect {log}')

    run('import', '--editor', '--import')
    run('export', '--export-release', 'Windows Desktop', str(output / 'AO-Mini.exe'))
    for filename in ('AO-Mini.exe', 'AO-Mini.pck'):
        if not (output / filename).is_file():
            raise SystemExit(f'Missing exported file: {filename}')
    if (output / 'AO-Mini.exe').read_bytes()[:2] != b'MZ':
        raise SystemExit('The exported executable is not a Windows PE binary.')

    notices = output / 'LICENSES'
    notices.mkdir()
    run('licenses', '--script', 'tools/write_engine_notices.gd', '--',
        '--license-output=' + str(notices / 'Godot.json'))
    shutil.copy2(repo / 'LICENSE', output / 'LICENSE')
    resources = {
        'assets/argentum/interface/ao20/LICENSE-AO20.txt': 'AO20-LICENSE.txt',
        'assets/argentum/interface/ao20/README.md': 'AO20-CREDITS.md',
        'assets/argentum/interface/ao20/sources.json': 'AO20-sources.json',
        'assets/argentum/custom/audio/originals/kenney_impact/License.txt': 'Kenney-LICENSE.txt',
    }
    for source, target in resources.items():
        shutil.copy2(repo / source, notices / target)
    for source in (repo / 'assets').rglob('*sources.json'):
        target = notices / 'sources' / source.relative_to(repo / 'assets')
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
    shutil.copy2(repo / 'distribution/windows/LEEME.txt', output / 'LEEME.txt')
    (output / 'THIRD_PARTY_NOTICES.txt').write_text(
        (repo / 'distribution/windows/THIRD_PARTY_NOTICES.txt').read_text(encoding='utf-8').replace('<source_sha>', source_sha),
        encoding='utf-8')
    files = {str(p.relative_to(output)).replace('\\', '/'): sha256(p)
             for p in sorted(output.rglob('*')) if p.is_file()}
    (output / 'release.json').write_text(json.dumps({
        'version': args.version, 'source_sha': source_sha, 'godot': engine_version,
        'platform': 'windows-x86_64', 'mode': 'local-practice', 'files_sha256': files,
    }, indent=2) + '\n', encoding='utf-8')
    if git('status', '--porcelain'):
        raise SystemExit('Import changed source files. Commit the changes and rebuild with a new output directory.')
    with zipfile.ZipFile(archive, 'x', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as target:
        for path in sorted(output.rglob('*')):
            if path.is_file():
                target.write(path, path.relative_to(output.parent))
    checksum = sha256(archive)
    archive.with_name(archive.name + '.sha256').write_text(f'{checksum}  {archive.name}\n', encoding='ascii')
    print(json.dumps({'file': str(archive), 'bytes': archive.stat().st_size,
                      'sha256': checksum, 'source_sha': source_sha}, indent=2))


if __name__ == '__main__':
    main()
