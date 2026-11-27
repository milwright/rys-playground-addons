#!/bin/sh
set -e
mkdir -p /data/runner
# Keep the data copy at least as new as the runner bundled in this
# add-on: copy the bundle over when the data copy is missing or older.
# A runner that has updated itself past the bundle is never rolled back.
bundled_version=$(sed -n 's/^RUNNER_VERSION *= *\([0-9][0-9]*\).*/\1/p' /app/runner.py | head -n 1)
data_version=0
if [ -f /data/runner/runner.py ]; then
  data_version=$(sed -n 's/^RUNNER_VERSION *= *\([0-9][0-9]*\).*/\1/p' /data/runner/runner.py | head -n 1)
  [ -n "$data_version" ] || data_version=0
fi
if [ ! -f /data/runner/runner.py ] || [ "${bundled_version:-0}" -gt "$data_version" ]; then
  cp /app/runner.py /data/runner/runner.py
fi
if [ ! -f /data/runner/boot.py ]; then
  cp /app/boot.py /data/runner/boot.py
fi
python3 - <<'PYEOF'
import json
from pathlib import Path

options = json.loads(Path("/data/options.json").read_text(encoding="utf-8"))
display_name = str(options.get("display_name", "")).strip()
member_key = str(options.get("member_key", "")).strip()

# A key the runner already saved on an earlier start survives restarts:
# this script rewrites config.json from the options on every start, so
# carry the saved key forward when the options do not carry one.
config_path = Path("/data/runner/config.json")
if not member_key and config_path.exists():
    try:
        saved = json.loads(config_path.read_text(encoding="utf-8"))
        member_key = str(saved.get("playground_member_key", "") or "").strip()
    except Exception:
        pass

# No key anywhere: trade the member name and password for the key, the
# same exchange the runner itself uses. The password is used for this
# one call and is never written to disk.
member_password = str(options.get("member_password", "") or "")
if not member_key and display_name and member_password:
    try:
        import importlib.util
        spec = importlib.util.spec_from_file_location("playground_runner", "/data/runner/runner.py")
        runner_mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(runner_mod)
        new_key, display, error = runner_mod.exchange_name_password_for_key(display_name, member_password)
        if new_key:
            member_key = new_key
            if display:
                display_name = display
            print("RY's Playground Runner: signed in as", display_name, "and saved the member key")
        elif error:
            print("RY's Playground Runner: sign in did not work:", error)
    except Exception as exc:
        print("RY's Playground Runner: sign in attempt failed:", exc)

config = {
    "display_name": display_name,
    "playground_member_key": member_key,
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
