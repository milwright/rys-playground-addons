#!/usr/bin/env python3
"""Boot launcher for the RY's Playground Runner.

Every start goes through here (run-hidden.vbs points at this file):
it is the rollback guard for the runner's self update.

How it works, in plain words. When the runner swaps in an update, it
records a trial in update-state.json and keeps the old runner as
runner.py.bak. This launcher then starts runner.py and waits for it.
If that updated runner finishes its first full pass, it marks the
trial good in the same file, and starts are normal from then on. If
a later start finds a trial that was already attempted once and
never marked good, the updated runner did not start properly: this
launcher puts runner.py.bak back as runner.py, notes the failed
version so the runner does not try that same version again, and
starts the restored runner instead.

With no trial in flight, this file simply starts runner.py and waits
for it, passing its exit code along.

Brought to you by RY.
"""

import json
import subprocess
import sys
import time
from pathlib import Path

BASE = Path(__file__).resolve().parent
RUNNER_PATH = BASE / "runner.py"
BACKUP_PATH = BASE / "runner.py.bak"
UPDATE_STATE_PATH = BASE / "update-state.json"
LOG_PATH = BASE / "runner.log"


def log(*parts):
    line = time.strftime("%H:%M:%S") + " " + " ".join(str(p) for p in parts)
    try:
        with LOG_PATH.open("a", encoding="utf-8") as fh:
            fh.write(line + "\n")
    except Exception:
        pass
    try:
        print(line, flush=True)
    except Exception:
        pass


def load_update_state():
    try:
        return json.loads(UPDATE_STATE_PATH.read_text(encoding="utf-8-sig"))
    except Exception:
        return {}


def save_update_state(data):
    UPDATE_STATE_PATH.write_text(json.dumps(data, indent=2, sort_keys=True), encoding="utf-8")


def main():
    state = load_update_state()
    if state.get("status") == "trial":
        if state.get("attempted"):
            failed = state.get("to_version")
            if BACKUP_PATH.exists():
                RUNNER_PATH.write_bytes(BACKUP_PATH.read_bytes())
                log("boot: the updated runner (version", failed, ") did not start properly, so the previous version was restored from runner.py.bak and is starting instead. That version will not be tried again; a newer publish will still come through.")
            else:
                log("boot: the updated runner did not start properly and no backup was found, so the current runner.py is starting as it stands.")
            save_update_state({"status": "rolledback", "failed_version": failed, "at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())})
        else:
            state["attempted"] = True
            save_update_state(state)
            log("boot: starting the updated runner (version", state.get("to_version"), ") for the first time.")
    return subprocess.call([sys.executable, str(RUNNER_PATH)], cwd=str(BASE))


if __name__ == "__main__":
    sys.exit(main())
