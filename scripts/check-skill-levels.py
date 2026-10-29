#!/usr/bin/env python3
"""check-skill-levels.py -- one skill name, one level.

intent: Detection for same-name skills at two levels (incident #80 shadowing
pattern; .claude/rules/documentation-standards.md "Skill placement"): a skill
name may exist in only one of shared/skills/ (user level), .claude/skills/
(project level) and the dotprofile's claude/skills/ (personal). NOT a check of
deployed copies under ~/.claude/skills. NOT a content check.
Consumed by: check-pre-commit.sh / check-pre-commit.ps1 step 21 (one
implementation for both platforms).

Usage:
    python3 scripts/check-skill-levels.py [--root DIR] [--dotprofile DIR]
    python3 scripts/check-skill-levels.py --help

A skill is a directory holding SKILL.md. --dotprofile is the user repo
(userRepoPath); when it is omitted or has no claude/skills/, only the two
aitools folders are compared.

Exit status: 0 = no name at two levels; 1 = collisions (each printed);
2 = usage or environment error.
Platform: macOS, Linux, Windows (stdlib only).
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path


def skill_names(base: Path) -> set[str]:
    if not base.is_dir():
        return set()
    return {p.name for p in base.iterdir() if p.is_dir() and (p / "SKILL.md").is_file()}


def main() -> int:
    ap = argparse.ArgumentParser(description="Fail when a skill name exists at two levels.")
    ap.add_argument("--root", default=None, help="aitools repo root (default: parent of this script's directory)")
    ap.add_argument("--dotprofile", default=None, help="dotprofile repo (userRepoPath); optional")
    args = ap.parse_args()
    root = Path(args.root) if args.root else Path(__file__).resolve().parent.parent
    if not (root / "shared" / "skills").is_dir():
        print(f"check-skill-levels: {root}/shared/skills not found", file=sys.stderr)
        return 2
    levels = {
        "shared/skills (user)": skill_names(root / "shared" / "skills"),
        ".claude/skills (project)": skill_names(root / ".claude" / "skills"),
    }
    if args.dotprofile:
        dp = Path(args.dotprofile)
        if not dp.is_dir():
            print(f"check-skill-levels: dotprofile {dp} not found; comparing aitools folders only", file=sys.stderr)
        else:
            levels["dotprofile claude/skills (personal)"] = skill_names(dp / "claude" / "skills")
    seen: dict[str, list[str]] = {}
    for level, names in levels.items():
        for n in names:
            seen.setdefault(n, []).append(level)
    collisions = {n: lv for n, lv in seen.items() if len(lv) > 1}
    for n in sorted(collisions):
        print(f"{n}: {' and '.join(collisions[n])}")
    counts = ", ".join(f"{len(v)} in {k}" for k, v in levels.items())
    print(f"skills: {counts}; names at two levels: {len(collisions)}")
    return 1 if collisions else 0


if __name__ == "__main__":
    sys.exit(main())
