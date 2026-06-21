#!/usr/bin/env python3
"""Dedup harvesting/ -- keep newest copy per (session, base-filename).

The catchup re-harvest loop produced many duplicate copies of the same source
artifact (differing only by date + collision counter). Group by provenance
(session prefix + underlying filename), keep the newest, list the rest.

Usage:
  dedup-harvesting.py            # dry run: print what would be deleted
  dedup-harvesting.py --apply    # delete redundant files + rewrite manifest
                                 # + drop .harvested markers in scratch dirs

Idempotent. Never touches harvest-manifest.json entries whose survivor file
still exists.
"""
from __future__ import annotations

import hashlib
import json
import os
import re
import sys
from pathlib import Path

REPO = Path("/Users/new-jose/repos/aitools")
HARVEST_DIR = REPO / "harvesting"
MANIFEST = HARVEST_DIR / "harvest-manifest.json"
SCRATCH = REPO / ".scratch"

NAME_RE = re.compile(
    r"^(?P<date>\d{4}-\d{2}-\d{2})_"
    r"(?:(?P<counter>\d+)_)?"
    r"(?:session-(?P<sess>[0-9a-zA-Z-]+?)_)?"
    r"(?P<base>.+)$"
)


def sha(p: Path) -> str:
    try:
        return hashlib.sha256(p.read_bytes()).hexdigest()
    except OSError:
        return "?"


def main() -> int:
    apply = "--apply" in sys.argv

    files = [
        p for p in HARVEST_DIR.iterdir()
        if p.is_file() and p.name != "harvest-manifest.json"
    ]

    groups: dict[tuple, list[tuple]] = {}
    unparsed: list[str] = []
    for p in files:
        m = NAME_RE.match(p.name)
        if not m:
            unparsed.append(p.name)
            # unparsed -> unique key so it is always kept
            groups[("__unparsed__", p.name)] = [(("", 0), p)]
            continue
        sess = m.group("sess") or ""
        base = m.group("base")
        date = m.group("date")
        counter = int(m.group("counter") or "0")
        key = (sess, base)
        groups.setdefault(key, []).append(((date, counter), p))

    survivors: set[str] = set()
    deletions: list[Path] = []
    multi_hash_groups = 0
    for key, items in groups.items():
        items.sort(key=lambda t: t[0])  # (date, counter) ascending
        keep = items[-1][1]
        survivors.add(keep.name)
        drop = [p for (_, p) in items[:-1]]
        if drop:
            hashes = {sha(p) for (_, p) in items}
            if len(hashes) > 1:
                multi_hash_groups += 1
        deletions.extend(drop)

    print(f"harvesting/ files (excl. manifest): {len(files)}")
    print(f"distinct (session, base) groups:    {len(groups)}")
    print(f"survivors (kept):                   {len(survivors)}")
    print(f"redundant copies to delete:         {len(deletions)}")
    print(f"groups with non-identical content:  {multi_hash_groups} "
          f"(newest kept per directive)")
    if unparsed:
        print(f"unparsed names (always kept):       {len(unparsed)}")

    listing = REPO / ".scratch" / "session-dbeefed3-d" / "dedup-delete-list.txt"
    listing.write_text("\n".join(sorted(p.name for p in deletions)) + "\n",
                       encoding="utf-8")
    print(f"\nfull delete list written to: {listing}")
    print("sample (first 15):")
    for p in sorted(deletions, key=lambda x: x.name)[:15]:
        print(f"  - {p.name}")

    if not apply:
        print("\nDRY RUN -- nothing deleted. Re-run with --apply to execute.")
        return 0

    # --- apply ---
    deleted = 0
    for p in deletions:
        try:
            p.unlink()
            deleted += 1
        except OSError as e:
            print(f"  ! could not delete {p.name}: {e}")

    # Rewrite manifest: keep only entries whose file survives.
    if MANIFEST.exists():
        data = json.loads(MANIFEST.read_text(encoding="utf-8"))
        arts = data.get("artifacts", {})
        before = len(arts)
        data["artifacts"] = {n: e for n, e in arts.items() if n in survivors}
        MANIFEST.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
        print(f"\nmanifest artifacts: {before} -> {len(data['artifacts'])}")

    # Mark every existing scratch session dir harvested so the next SessionStart
    # does not re-harvest them (belt-and-suspenders with the code fix).
    marked = 0
    if SCRATCH.is_dir():
        from datetime import datetime, timezone
        stamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ") + "\n"
        for sd in SCRATCH.iterdir():
            if sd.is_dir() and sd.name.startswith("session-"):
                try:
                    (sd / ".harvested").write_text(stamp, encoding="utf-8")
                    marked += 1
                except OSError as e:
                    print(f"  ! could not mark {sd.name}: {e}")

    print(f"deleted {deleted} files; marked {marked} scratch dirs harvested.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
