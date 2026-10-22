#!/usr/bin/env python3
"""check-path-refs.py -- verify that repo paths cited in harness docs exist.

intent: Detection for dead repo-path references (incidents #59, #70, #84, #115):
every repo-relative path that a skill, rule, Cursor rule, hook, reference doc
or CLAUDE.md cites must exist in the working tree. NOT a link checker for
URLs, home-directory paths (~/...), or placeholders. NOT a content check.
Consumed by: check-pre-commit.sh / check-pre-commit.ps1 step 20 (one
implementation for both platforms, so results are identical).

Usage:
    python3 scripts/check-path-refs.py [--root DIR] [--quiet]
    python3 scripts/check-path-refs.py --help

What is checked:
    - Markdown (.md, .mdc): every `backticked` span and every @path token
      whose first segment is a repo top-level directory (see TOP_DIRS).
    - Shell hooks (shared/hooks/*.sh): every literal registries/<x>.json or
      reference/<x>.(md|json) token.

Skipped tokens: placeholders and globs (< > { } * ? $ space |), URLs,
paths under ~/ or /, and paths git ignores (git check-ignore).

Pair shorthand: `scripts/x.sh/.ps1` checks both scripts/x.sh and scripts/x.ps1;
an extensionless `scripts/x` passes when scripts/x.sh or scripts/x.ps1 exists.

Exemptions, for intentional mentions of a path that does not exist (test
fixtures, examples, history, planned files):
    - a line containing the marker "path-ref: ignore" is skipped;
    - scripts/check-path-refs-allow.txt lists "file|path|reason" entries
      (protected files take an allowlist entry instead of a marker).

Exit status: 0 = every cited path exists; 1 = one or more dead paths
(each printed as file:line: path); 2 = usage or environment error.
Platform: macOS, Linux, Windows (stdlib only).
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

TOP_DIRS = (
    "registries/", "reference/", "scripts/", "shared/", ".claude/", ".cursor/",
    "plans/", "tests/", "rfcs/", "harvesting/", ".github/", "generated/",
)

# Files scanned, as (directory, glob, recursive) relative to the repo root.
SCAN = (
    (".claude/skills", "*.md", True),
    ("shared/skills", "*.md", True),
    (".claude/rules", "*.md", False),
    (".cursor/rules", "*.mdc", False),
    ("reference", "*.md", False),
    ("shared/hooks", "*.sh", False),
)
SCAN_FILES = ("CLAUDE.md", "shared/claude-shared.md", "shared/README.md")

BACKTICK = re.compile(r"`([^`\n]+)`")
AT_PATH = re.compile(r"(?<![\w/~.])@([.A-Za-z][A-Za-z0-9._/-]*)")
HOOK_PATH = re.compile(r"(?<![\w.-])((?:registries/[A-Za-z0-9._-]+\.json)|(?:reference/[A-Za-z0-9._-]+\.(?:md|json)))")
BAD_CHARS = set("<>{}*?$| ")
LINE_SUFFIX = re.compile(r":\d+(?:[-,]\d+)*$")
IGNORE_MARKER = "path-ref: ignore"


def candidate(token: str) -> str | None:
    """Return the repo-relative path a token cites, or None if it is not one."""
    tok = token.strip()
    if tok.startswith("@"):
        tok = tok[1:]
    tok = tok.rstrip(".,;:)")
    tok = LINE_SUFFIX.sub("", tok)
    if not tok or any(c in BAD_CHARS for c in tok):
        return None
    if "://" in tok or tok.startswith(("~", "/")):
        return None
    if not tok.startswith(TOP_DIRS):
        return None
    # A bare top-level directory (e.g. `scripts/`) always exists or is a typo
    # worth flagging; keep it.
    return tok


def files_to_scan(root: Path) -> list[Path]:
    out: list[Path] = []
    for rel_dir, pattern, recursive in SCAN:
        base = root / rel_dir
        if not base.is_dir():
            continue
        it = base.rglob(pattern) if recursive else base.glob(pattern)
        out.extend(sorted(p for p in it if p.is_file()))
    for rel in SCAN_FILES:
        p = root / rel
        if p.is_file():
            out.append(p)
    return out


def git_ignored(root: Path, paths: list[str]) -> set[str]:
    """Return the subset of paths that git ignores (best effort, logged)."""
    if not paths:
        return set()
    try:
        proc = subprocess.run(
            ["git", "-C", str(root), "check-ignore", "--no-index", "--stdin"],
            input="\n".join(paths), capture_output=True, text=True, check=False,
        )
    except FileNotFoundError:
        print("check-path-refs: git not found; ignored-path filtering disabled", file=sys.stderr)
        return set()
    # Exit 0 = some ignored, 1 = none ignored, >1 = error.
    if proc.returncode > 1:
        print(f"check-path-refs: git check-ignore failed: {proc.stderr.strip()}", file=sys.stderr)
        return set()
    return {line.strip() for line in proc.stdout.splitlines() if line.strip()}


ALLOW_FILE = "scripts/check-path-refs-allow.txt"


def load_allow(root: Path) -> set[tuple[str, str]]:
    """Read file|path|reason entries; a malformed line is an error (exit 2)."""
    allow: set[tuple[str, str]] = set()
    p = root / ALLOW_FILE
    if not p.is_file():
        return allow
    for lineno, line in enumerate(p.read_text(encoding="utf-8").splitlines(), 1):
        s = line.strip()
        if not s or s.startswith("#"):
            continue
        parts = [x.strip() for x in s.split("|")]
        if len(parts) != 3 or not all(parts):
            print(f"check-path-refs: {ALLOW_FILE}:{lineno}: expected file|path|reason", file=sys.stderr)
            raise SystemExit(2)
        allow.add((parts[0], parts[1]))
    return allow


def exists(root: Path, cand: str) -> bool:
    if cand.endswith(".sh/.ps1"):
        stem = cand[: -len(".sh/.ps1")]
        return (root / f"{stem}.sh").is_file() and (root / f"{stem}.ps1").is_file()
    target = root / cand
    if target.exists():
        return True
    if not target.suffix:
        return (root / f"{cand}.sh").is_file() or (root / f"{cand}.ps1").is_file()
    return False


def scan(root: Path) -> list[tuple[str, int, str]]:
    refs: set[tuple[str, int, str]] = set()
    for path in files_to_scan(root):
        rel_file = path.relative_to(root).as_posix()
        try:
            text = path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError) as exc:
            print(f"check-path-refs: cannot read {rel_file}: {exc}", file=sys.stderr)
            raise SystemExit(2)
        is_hook = path.suffix == ".sh"
        for lineno, line in enumerate(text.splitlines(), 1):
            if IGNORE_MARKER in line:
                continue
            tokens = HOOK_PATH.findall(line) if is_hook else BACKTICK.findall(line) + AT_PATH.findall(line)
            for tok in tokens:
                cand = candidate(tok)
                if cand:
                    refs.add((rel_file, lineno, cand))
    allow = load_allow(root)
    missing = sorted(r for r in refs if not exists(root, r[2]) and (r[0], r[2]) not in allow)
    ignored = git_ignored(root, sorted({r[2] for r in missing}))
    return [r for r in missing if r[2] not in ignored]


def main() -> int:
    ap = argparse.ArgumentParser(description="Verify that repo paths cited in harness docs exist.")
    ap.add_argument("--root", default=None, help="repo root (default: parent of this script's directory)")
    ap.add_argument("--quiet", action="store_true", help="print only the dead-path count")
    args = ap.parse_args()
    root = Path(args.root) if args.root else Path(__file__).resolve().parent.parent
    if not (root / ".git").exists():
        print(f"check-path-refs: {root} is not a git checkout", file=sys.stderr)
        return 2
    dead = scan(root)
    if not args.quiet:
        for rel_file, lineno, cand in dead:
            print(f"{rel_file}:{lineno}: {cand}")
    print(f"dead path references: {len(dead)}")
    return 1 if dead else 0


if __name__ == "__main__":
    sys.exit(main())
