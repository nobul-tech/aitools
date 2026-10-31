#!/usr/bin/env python3
"""List path-like references in reference/*.md that do not exist in the repo.

Usage: pathcheck.py <repo-root>
Prints file:line: token for every path token (inside backticks or after @)
whose target is missing. Also lists /skill references whose skill dir is missing.
"""
import os
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
home = Path.home()
dotprofile = home / "repos" / "aitools-nobul-jose"
skill_dirs = [root / "shared/skills", root / ".claude/skills", dotprofile / "claude/skills", home / ".claude/skills"]
skills = set()
for d in skill_dirs:
    if d.is_dir():
        for p in d.iterdir():
            if p.is_dir():
                skills.add(p.name)

prefixes = ("reference/", "scripts/", "shared/", "plans/", ".claude/", "registries/", "tests/",
            ".github/", ".aitools/", "deploy/", "harvesting/", ".cursor/", "docs/")
tok_re = re.compile(r"[`@]((?:\.?[A-Za-z0-9_\-]+/)+[A-Za-z0-9_\-\.\*]+)")
skill_re = re.compile(r"`/([a-z][a-z0-9\-]+)`")
missing = []
for md in sorted((root / "reference").rglob("*.md")):
    rel = md.relative_to(root)
    for i, line in enumerate(md.read_text(encoding="utf-8").splitlines(), 1):
        for m in tok_re.finditer(line):
            t = m.group(1).rstrip(".,:;)")
            if not t.startswith(prefixes):
                continue
            if "*" in t or "<" in t:
                continue
            if not (root / t).exists():
                print(f"PATH {rel}:{i}: {t}")
        for m in skill_re.finditer(line):
            s = m.group(1)
            if s not in skills and s not in ("help", "clear", "compact", "resume", "rewind", "memory", "config", "hooks", "agents", "context", "model", "status", "doctor", "init", "permissions", "mcp", "loop", "schedule", "plugin", "login", "logout", "cost", "review", "export", "add-dir", "tools", "artifacts", "statusline", "terminal-setup", "ide", "vim", "bug", "release-notes", "upgrade", "fast", "effort", "security-review", "simplify", "code-review", "fewer-permission-prompts"):
                print(f"SKILL {rel}:{i}: /{s}")
