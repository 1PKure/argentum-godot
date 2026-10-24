#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
compose=(docker compose --env-file hosting/vps/.env -p ao-mini -f hosting/vps/compose.yaml -f hosting/vps/public-beta.yaml)
"${compose[@]}" config --quiet
image=$(docker inspect --format '{{.Config.Image}}' ao-mini-arena-1)
mkdir -p hosting/vps/ranking-backups
chmod 700 hosting/vps/ranking-backups
# Always bring the same public dedicated back, including on a failed cleanup.
trap '"${compose[@]}" up -d --no-build' EXIT
"${compose[@]}" stop arena
docker run --rm --user 0:0 --env-file hosting/vps/.env \
  -v "$PWD/hosting/gateway/clean-ranking.mjs:/app/hosting/gateway/clean-ranking.mjs:ro" \
  -v "$PWD/hosting/vps/ranking-backups:/backup" \
  --entrypoint node "$image" /app/hosting/gateway/clean-ranking.mjs \
  --keep-name=1kurep --backup-dir=/backup
