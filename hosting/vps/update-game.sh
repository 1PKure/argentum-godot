#!/usr/bin/env bash
# Run on the existing VPS. Build an exact commit and restore the old image on failure.
set -euo pipefail
umask 077
cd "${AO_REPO_ROOT:-/opt/ao-mini}"
source_sha=${1:?Pass the full tested Git commit SHA}
[[ "$source_sha" =~ ^[0-9a-f]{40}$ ]] || { echo 'Invalid commit SHA.' >&2; exit 1; }
git cat-file -e "$source_sha^{commit}"
compose=(docker compose --env-file hosting/vps/.env -p ao-mini -f hosting/vps/compose.yaml -f hosting/vps/public-beta.yaml)
"${compose[@]}" config --quiet
old_image=$(docker inspect ao-mini-arena-1 --format '{{.Config.Image}}')
# Refuse to operate on an unexpected service or configuration.
[[ "$old_image" == ao-mini-pilot:* ]] || { echo 'Unexpected running image.' >&2; exit 1; }
release="hosting/vps/releases/$source_sha"
[[ ! -e "$release" ]] || { echo 'This release directory already exists; inspect it before retrying.' >&2; exit 1; }
mkdir -p "$release" hosting/vps/ranking-backups
chmod 700 hosting/vps/ranking-backups
backup="hosting/vps/ranking-backups/before-update-$(date -u +%Y%m%dT%H%M%SZ)-$$.env"
cp hosting/vps/.env "$backup"
chmod 600 "$backup"
git archive "$source_sha" | tar -x -C "$release"
completed=false
restore_on_failure() {
  code=$?
  if [[ "$completed" != true ]]; then
    echo 'Update failed. Restoring the previous configuration and image.' >&2
    cp "$backup" hosting/vps/.env
    chmod 600 hosting/vps/.env
    "${compose[@]}" up -d --no-build --wait --wait-timeout 180 || echo 'Automatic recovery failed; inspect the service before reopening.' >&2
  fi
  exit "$code"
}
trap restore_on_failure EXIT
# The 1 GB pilot needs its memory for the import/build; take the short maintenance
# window before building rather than competing with active duels.
echo 'Starting maintenance: active games will disconnect.'
"${compose[@]}" stop arena
docker build --tag "ao-mini-pilot:$source_sha" --file "$release/hosting/Dockerfile" "$release"
python3 - "$source_sha" <<'PY'
import os,pathlib,re,sys
path=pathlib.Path('hosting/vps/.env')
text=path.read_text()
if len(re.findall(r'^AO_SOURCE_SHA=',text,re.M)) != 1:
    raise SystemExit('Expected one AO_SOURCE_SHA entry; previous config will be restored.')
text=re.sub(r'^AO_SOURCE_SHA=.*$',lambda _: 'AO_SOURCE_SHA='+sys.argv[1],text,flags=re.M)
temporary=path.with_name('.env.update.tmp')
fd=os.open(temporary,os.O_CREAT|os.O_EXCL|os.O_WRONLY,0o600)
with os.fdopen(fd,'w') as f:f.write(text)
os.replace(temporary,path)
PY
"${compose[@]}" up -d --no-build --wait --wait-timeout 180
completed=true
echo "Server healthy. Running commit: $source_sha"
echo "Previous image retained: $old_image"
echo 'Publish the matching web ZIP, then ask players to close and reload the game.'
