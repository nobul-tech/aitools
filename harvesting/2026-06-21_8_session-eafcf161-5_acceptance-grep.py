#!/usr/bin/env python3
"""Acceptance test for the logging migration (reference/logging.md §migration):
old log-path literals must be gone outside reference/logging.md and plans/.
Reports every hit with file:line so install-path LOCALAPPDATA (legit) can be
distinguished from any leftover logging literal."""
import os

ROOT = "/Users/new-jose/repos/aitools"
SCAN_DIRS = ["scripts", "shared", "reference", ".claude"]
LITERALS = [".local/state", "Library/Logs", "LOCALAPPDATA", "LocalApplicationData", "XDG_STATE_HOME"]
# Allowed to retain old literals (the spec itself + plans are excluded by design)
ALLOW = {"reference/logging.md"}

hits = {lit: [] for lit in LITERALS}
for d in SCAN_DIRS:
    for dirpath, _, files in os.walk(os.path.join(ROOT, d)):
        if "/.git" in dirpath:
            continue
        for fn in files:
            full = os.path.join(dirpath, fn)
            rel = os.path.relpath(full, ROOT)
            if rel in ALLOW:
                continue
            try:
                with open(full, encoding="utf-8") as f:
                    for i, line in enumerate(f, 1):
                        for lit in LITERALS:
                            if lit in line:
                                hits[lit].append((rel, i, line.strip()[:110]))
            except (UnicodeDecodeError, OSError):
                continue

total = 0
for lit in LITERALS:
    if hits[lit]:
        print("=== %s (%d) ===" % (lit, len(hits[lit])))
        for rel, i, ln in hits[lit]:
            print("  %s:%d  %s" % (rel, i, ln))
        total += len(hits[lit])
print("---")
print("total hits outside logging.md/plans:", total)
