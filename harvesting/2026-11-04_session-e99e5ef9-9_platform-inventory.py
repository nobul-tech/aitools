#!/usr/bin/env python3
"""platform-inventory.py -- classify every tracked .ps1/.sh/.py script by the
platforms its own OS guard allows (read-only).

Guard patterns (cross-platform.md "OS guard patterns"):
  ps1 windows-only: `-not $IsWindows` followed by an exit
  sh  posix-only:   case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) ... exit
Anything without a guard is "any" (all platforms) unless it says otherwise.
Also reports guard overrides (env vars that bypass a guard).
Usage: python3 platform-inventory.py [--tsv OUT]
"""
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

REPO = Path("/Users/new-jose/repos/aitools")
files = subprocess.run(["git", "-C", str(REPO), "ls-files", "*.ps1", "*.sh", "*.py"],
                       capture_output=True, text=True, check=True).stdout.split()

PS_WIN = re.compile(r"-not\s+\$IsWindows")
SH_POSIX = re.compile(r"MINGW\*\|MSYS\*\|CYGWIN\*\)[^;]*?(?:log_error|LogError|echo|printf)?[\s\S]{0,200}?exit\s+1", re.M)
OVERRIDE = re.compile(r"AITOOLS_[A-Z_]*ANY_OS|AITOOLS_[A-Z_]*SKIP_OS_GUARD|AITOOLS_[A-Z_]*OS_OVERRIDE")

rows = []
for rel in files:
    if rel.startswith(("harvesting/", ".aitools/", "deploy/")):
        continue
    p = REPO / rel
    try:
        text = p.read_text(encoding="utf-8", errors="replace")
    except OSError:
        continue
    head = text[:6000]
    if rel.endswith(".ps1"):
        target = "windows-only" if PS_WIN.search(head) else "any"
    elif rel.endswith(".sh"):
        target = "posix-only" if SH_POSIX.search(head) else "any"
    else:
        target = "any"
    ov = sorted(set(OVERRIDE.findall(text)))
    rows.append((rel, target, ",".join(ov)))

out = None
if len(sys.argv) > 2 and sys.argv[1] == "--tsv":
    out = open(sys.argv[2], "w", encoding="utf-8")
counts: dict[tuple[str, str], int] = {}
for rel, target, ov in rows:
    top = rel.split("/")[0]
    ext = rel.rsplit(".", 1)[-1]
    counts[(f"{top}/*.{ext}", target)] = counts.get((f"{top}/*.{ext}", target), 0) + 1
    if out:
        out.write(f"{rel}\t{target}\t{ov}\n")
for (grp, target), n in sorted(counts.items()):
    print(f"{n:4d}  {grp:28s} {target}")
print("--- guard overrides referenced ---")
for rel, target, ov in rows:
    if ov:
        print(f"  {rel}  [{target}]  {ov}")
