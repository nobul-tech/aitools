#!/usr/bin/env python3
"""clean-harvest-junk.py -- remove harvested files the fixed classifier would
never have harvested (gap G2): harness bookkeeping such as .harvested,
.intelligence-last-check, events.jsonl and other dotfiles.

Junk = files in harvesting/ (and manifest entries) whose ORIGINAL scratch name
is ephemeral per _is_ephemeral() in scripts/ait-harvest.py (imported, so the
rule is the harvester's own). The original name is the harvested name without
its "<date>_[<n>_][session-<tag>_]" prefix.

Usage: python3 clean-harvest-junk.py [--apply]
  (default: dry run, prints what would go)
--apply: git rm each junk file that git tracks, delete untracked ones, drop
their manifest entries, write the manifest atomically (temp + os.replace).
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import os
import re
import subprocess
import sys
from pathlib import Path

REPO = Path("/Users/new-jose/repos/aitools")
HARVESTING = REPO / "harvesting"
MANIFEST = HARVESTING / "harvest-manifest.json"
PREFIX = re.compile(r"^\d{4}-\d{2}-\d{2}_(?:\d+_)?(?:session-[^_]+_)?(?P<orig>.+)$")


def load_classifier():
    spec = importlib.util.spec_from_file_location("ait_harvest", REPO / "scripts" / "ait-harvest.py")
    if spec is None or spec.loader is None:
        raise RuntimeError("cannot load ait-harvest.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod._is_ephemeral


def original_name(harvested: str) -> str | None:
    m = PREFIX.match(harvested)
    return m.group("orig") if m else None


def tracked(path: Path) -> bool:
    out = subprocess.run(["git", "-C", str(REPO), "ls-files", "--error-unmatch", "--",
                          str(path.relative_to(REPO))], capture_output=True, text=True)
    return out.returncode == 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--apply", action="store_true", help="delete (default: dry run)")
    args = ap.parse_args()

    is_ephemeral = load_classifier()
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    artifacts: dict = manifest.get("artifacts", {})

    names = {p.name for p in HARVESTING.iterdir() if p.is_file() and p.name != MANIFEST.name}
    names |= set(artifacts)
    unparsed = sorted(n for n in names if original_name(n) is None)
    junk = sorted(n for n in names if (o := original_name(n)) is not None and is_ephemeral(o))

    by_orig: dict[str, int] = {}
    for n in junk:
        o = original_name(n) or n
        key = o if o.startswith(".") or o == "events.jsonl" else f"other: {o}"
        by_orig[key] = by_orig.get(key, 0) + 1
    print(f"harvesting/ files + manifest keys: {len(names)}")
    print(f"junk: {len(junk)}  (on disk: {sum((HARVESTING / n).exists() for n in junk)}, "
          f"in manifest: {sum(n in artifacts for n in junk)})")
    for k, v in sorted(by_orig.items()):
        print(f"  {v:4d}  {k}")
    if unparsed:
        print(f"names without a <date>_ prefix (left alone): {unparsed}")

    if not args.apply:
        print("dry run: nothing changed (pass --apply)")
        return 0

    removed_files = 0
    for n in junk:
        p = HARVESTING / n
        if p.exists():
            if tracked(p):
                rc = subprocess.run(["git", "-C", str(REPO), "rm", "-q", "--", str(p.relative_to(REPO))])
                if rc.returncode != 0:
                    print(f"ERROR: git rm failed for {n}", file=sys.stderr)
                    return 1
            else:
                p.unlink()
            removed_files += 1
        artifacts.pop(n, None)

    tmp = MANIFEST.with_name(MANIFEST.name + f".tmp.{os.getpid()}")
    tmp.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    json.loads(tmp.read_text(encoding="utf-8"))  # validate before replacing
    os.replace(tmp, MANIFEST)
    print(f"removed {removed_files} file(s); manifest now {len(artifacts)} entries")
    return 0


if __name__ == "__main__":
    sys.exit(main())
