#!/usr/bin/env python3
"""Two real clients: turn toward an occupied tile, replicate facing, then melee."""
import argparse
from pathlib import Path
import subprocess
import time


def wait_for(path, phrase, process):
    deadline = time.monotonic() + 8
    while time.monotonic() < deadline:
        if phrase in path.read_text(errors="replace"):
            return
        if process.poll() is not None:
            raise RuntimeError(f"Process exited before {phrase}: {path.read_text()}")
        time.sleep(0.05)
    raise TimeoutError(phrase)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", required=True)
    parser.add_argument("--output", type=Path, default=Path("/tmp/facing-network-qa"))
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    repo = Path(__file__).resolve().parent.parent
    command = [args.godot, "--headless", "--path", str(repo), "--script",
               "res://tests/facing_network_smoke.gd", "--"]
    processes = {}
    files = {}
    try:
        for role in ["server", "actor", "observer"]:
            path = args.output / f"{role}.log"
            files[role] = path.open("w")
            process = subprocess.Popen(command + [f"--facing-{role}"],
                                       stdout=files[role], stderr=subprocess.STDOUT)
            processes[role] = process
            if role == "server":
                wait_for(path, "FACING SERVER READY", process)
            elif role == "actor":
                wait_for(args.output / "server.log", "Player registered:", processes["server"])
        failed = False
        for role in ["actor", "observer", "server"]:
            code = processes[role].wait(timeout=15)
            text = (args.output / f"{role}.log").read_text(errors="replace")
            invalid = code != 0 or "ERROR:" in text or "FAIL:" in text
            if role != "server":
                invalid |= "Facing WebSocket checks: 6; failures: 0" not in text
            print(f"{role}: exit={code}, clean={not invalid}")
            failed |= invalid
        return 1 if failed else 0
    finally:
        for process in processes.values():
            if process.poll() is None:
                process.terminate()
                process.wait(timeout=5)
        for stream in files.values():
            stream.close()


if __name__ == "__main__":
    raise SystemExit(main())
