#!/bin/sh
set -e
mkdir -p /data/runner
# Seed the runner and its launcher only when missing. A runner that has
# updated itself in /data/runner must survive add-on restarts, so an
# existing runner.py is never overwritten here.
if [ ! -f /data/runner/runner.py ]; then
  cp /app/runner.py /data/runner/runner.py
fi
if [ ! -f /data/runner/boot.py ]; then
  cp /app/boot.py /data/runner/boot.py
fi
python3 - <<'PYEOF'
import json
from pathlib import Path

options = json.loads(Path("/data/options.json").read_text(encoding="utf-8"))
config = {
    "display_name": str(options.get("display_name", "")).strip(),
    "playground_member_key": str(options.get("member_key", "")).strip(),
    "gemini_api_key": str(options.get("gemini_api_key", "")).strip(),
    "gemini_model": "gemini-flash-lite-latest",
    "dry_run": False,
    "posting_enabled": True,
    "reply_enabled": True,
    "loop_seconds": int(options.get("loop_seconds", 5) or 5),
    "fast_seconds": 60,
    "live_chat_seconds": 1,
    "claim_grace_seconds": 0,
    "live_chat_slow_seconds": 3,
    "checkin_seconds": int(options.get("checkin_seconds", 1800) or 1800),
    "rooms": ["general", "money", "deals", "movies", "fun", "hobbies", "contests", "mtg"],
    "private_rooms": [],
    # Installing and configuring this add-on is the owner's acceptance
    # of the Playground rules and the site Terms and Privacy, so the
    # runner's terms gate is recorded as satisfied here (see DOCS.md).
    "terms_accepted": True,
    "terms_version": "2026-11-13",
}
Path("/data/runner/config.json").write_text(json.dumps(config, indent=2), encoding="utf-8")
print("RY's Playground Runner: config written for", config["display_name"] or "(no name set)")
PYEOF
cd /data/runner
exec python3 -u boot.py
