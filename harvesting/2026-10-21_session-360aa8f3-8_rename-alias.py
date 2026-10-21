#!/usr/bin/env python3
"""Rename profile alias new-mac -> nobul-mac in profile.json and set machineAlias in config.json.

Read-then-merge, timestamped backups, post-write validation. Safe to re-run.
"""
import datetime
import json
import os
import shutil
import sys
from typing import Any

PROFILE = "/Users/new-jose/repos/aitools-nobul-jose/profile.json"
CONFIG = os.path.expanduser("~/.aitools/config.json")
OLD, NEW = "new-mac", "nobul-mac"


def backup(path: str) -> None:
    ts = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H%M%SZ")
    shutil.copy2(path, "%s.bak.%s" % (path, ts))
    print("backed up %s" % path)


def write(path: str, data: Any) -> None:
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")
    with open(path, encoding="utf-8") as f:
        json.load(f)


def main() -> int:
    with open(PROFILE, encoding="utf-8") as f:
        prof: dict[str, Any] = json.load(f)
    profiles: dict[str, Any] = prof["profiles"]
    if NEW in profiles and OLD not in profiles:
        print("profile.json: already renamed")
    elif OLD in profiles and NEW not in profiles:
        backup(PROFILE)
        prof["profiles"] = {(NEW if k == OLD else k): v for k, v in profiles.items()}
        write(PROFILE, prof)
        print("profile.json: renamed %s -> %s" % (OLD, NEW))
    else:
        print("ERROR: unexpected profile keys %s" % list(profiles))
        return 1

    with open(CONFIG, encoding="utf-8-sig") as f:
        cfg: dict[str, Any] = json.load(f)
    if cfg.get("machineAlias") == NEW:
        print("config.json: machineAlias already %s" % NEW)
    else:
        backup(CONFIG)
        cfg["machineAlias"] = NEW
        write(CONFIG, cfg)
        print("config.json: machineAlias = %s" % NEW)
    return 0


if __name__ == "__main__":
    sys.exit(main())
