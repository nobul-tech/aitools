#!/usr/bin/env python3
"""Idempotently register block-explore-agent.sh as a PreToolUse[Agent] hook in
~/.claude/settings.json. Backs up first. Mirrors mergeHookEntry semantics."""
import json
import os
import shutil
from datetime import datetime, timezone

HOME = os.path.expanduser("~")
SETTINGS = os.path.join(HOME, ".claude", "settings.json")
HOOK_ID = "block-explore-agent.sh"
MATCHER = "Agent"
CMD = 'bash "%s/.claude/hooks/block-explore-agent.sh"' % HOME

with open(SETTINGS, "r", encoding="utf-8") as f:
    s = json.load(f)

# Backup
ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H%M%SZ")
shutil.copy2(SETTINGS, "%s.bak.%s" % (SETTINGS, ts))

hooks = s.setdefault("hooks", {})
pre = hooks.setdefault("PreToolUse", [])


def has_entry(arr):
    for rule in arr:
        for h in rule.get("hooks", []):
            if HOOK_ID in (h.get("command") or ""):
                return True
    return False


if has_entry(pre):
    print("already registered")
else:
    pre.append({"matcher": MATCHER, "hooks": [{"type": "command", "command": CMD}]})
    with open(SETTINGS, "w", encoding="utf-8") as f:
        json.dump(s, f, indent=2)
        f.write("\n")
    # Validate
    with open(SETTINGS, "r", encoding="utf-8") as f:
        v = json.load(f)
    count = sum(
        1
        for rule in v["hooks"]["PreToolUse"]
        for h in rule.get("hooks", [])
        if HOOK_ID in (h.get("command") or "")
    )
    print("registered, count=%d" % count)
