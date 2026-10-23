"""Create VPS-only credentials once; never print the storage bearer key."""
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import sys
from urllib.parse import urlsplit


def main():
    if len(sys.argv) != 4:
        raise SystemExit("Usage: prepare-pilot.py HOST BUILT_IMAGE_GIT_SHA SUPABASE_ORIGIN")
    host, source_sha, supabase = sys.argv[1:]
    origin = urlsplit(supabase)
    if not re.fullmatch(r"[a-z0-9]+(?:[.-][a-z0-9]+)*", host):
        raise SystemExit("Invalid hostname")
    if not re.fullmatch(r"[0-9a-f]{40}", source_sha):
        raise SystemExit("Expected full built-image commit SHA")
    if (origin.scheme != "https" or not origin.hostname or origin.username
            or origin.password or origin.path or origin.query or origin.fragment):
        raise SystemExit("Expected an HTTPS Supabase origin")
    target = Path(__file__).resolve().parent / ".env"
    storage_key = secrets.token_hex(32)
    pilot_key = secrets.token_hex(32)
    values = {"AO_HOST": host, "AO_SOURCE_SHA": source_sha,
              "SUPABASE_URL": supabase, "AO_STORE_KEY": storage_key,
              "AO_PILOT_KEY": pilot_key}
    try:
        fd = os.open(target, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    except FileExistsError:
        raise SystemExit("Existing .env preserved; refusing to replace credentials")
    with os.fdopen(fd, "w") as out:
        out.write("".join(f"{key}={value}\n" for key, value in values.items()))
    print("STORAGE_KEY_SHA256=" + hashlib.sha256(storage_key.encode()).hexdigest())
    print("PRIVATE_CLIENT_CONFIG=" + json.dumps({
        "server_url": f"wss://{host}/game?ticket={pilot_key}",
        "ranking_url": f"https://{host}/api/ranking?ticket={pilot_key}",
        "ranking_refresh_seconds": 30,
    }, separators=(",", ":")))
    print("The client invitation is private. Do not publish it to GitHub.")


if __name__ == "__main__":
    main()
