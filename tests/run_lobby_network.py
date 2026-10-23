#!/usr/bin/env python3
"""Reproducible real WebSocket lobby regression: four clients/two rooms, then solo+bot."""
import argparse
import json
import pathlib
import shutil
import subprocess
import tempfile
import time

parser = argparse.ArgumentParser()
parser.add_argument("--godot", default="godot", help="Godot 4.7 Standard executable")
parser.add_argument("--output", help="Optional directory for logs and fresh coordination markers")
args = parser.parse_args()
repo = pathlib.Path(__file__).resolve().parent.parent
output = pathlib.Path(args.output).resolve() if args.output else pathlib.Path(tempfile.mkdtemp(prefix="ao-lobby-tests-"))
output.mkdir(parents=True, exist_ok=True)
markers = output / "markers"
shutil.rmtree(markers, ignore_errors=True)
markers.mkdir()
processes = []
files = []
failures = []

def spawn(label, command):
    path = output / f"{label}.log"
    handle = path.open("w")
    files.append(handle)
    process = subprocess.Popen(command, cwd=repo, stdout=handle, stderr=subprocess.STDOUT)
    processes.append(process)
    return process, path

try:
    server, server_log = spawn("server", [args.godot, "--headless", "--path", str(repo), "--log-file", str(output / "engine-server.log"), "--", "--server", "--port=17877"])
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline and server.poll() is None:
        if "Argentum server ready." in server_log.read_text():
            break
        time.sleep(0.05)
    else:
        raise RuntimeError("Dedicated server did not start on port17877: " + server_log.read_text())
    for roles in [("A", "B", "C", "D"), ("S",)]:
        clients = []
        for role in roles:
            client, log = spawn(role, [args.godot, "--headless", "--path", str(repo), "--log-file", str(output / f"engine-{role}.log"), "--script", "tests/lobby_network_client.gd", "--", "--no-auto-server", f"--lobby-role={role}", f"--lobby-markers={markers}"])
            clients.append((role, client, log))
            time.sleep(0.15)
        for role, client, log in clients:
            try:
                code = client.wait(timeout=60)
            except subprocess.TimeoutExpired:
                code = -1
            content = log.read_text()
            result_path = markers / f"{role}-result.json"
            result = json.loads(result_path.read_text()) if result_path.exists() else {}
            if code != 0 or int(result.get("checks", 0)) < 10 or int(result.get("failures", -1)) != 0 or "ERROR:" in content or "SCRIPT ERROR" in content or "FAIL [" in content:
                failures.append(role)
                print(f"Client {role} failed with exit status {code}")
                print(content)
            else:
                print(f"Lobby network checks [{role}]: {result['checks']}; failures: {result['failures']}")
        time.sleep(0.2)
    if "ERROR:" in server_log.read_text():
        failures.append("server")
        print(server_log.read_text())
finally:
    for process in processes:
        if process.poll() is None:
            process.terminate()
    for process in processes:
        try:
            process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=3)
    for handle in files:
        handle.close()
print("Logs:", output)
raise SystemExit(1 if failures else 0)
