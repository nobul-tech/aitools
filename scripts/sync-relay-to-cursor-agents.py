#!/usr/bin/env python3
"""
Sync `.aitools/channel/relay.md` into `~/.cursor/AGENTS.md`.

Preserves everything above `## Agent relay channel` (your HTML / email block).
Rebuilds the relay section: canonical note + relay body with headings demoted
one level so structure matches a nested section under `# User-level agent instructions`.

Usage (from aitools repo root):

  python3 scripts/sync-relay-to-cursor-agents.py
  python3 scripts/sync-relay-to-cursor-agents.py --dry-run
  python3 scripts/sync-relay-to-cursor-agents.py --target ~/.cursor/AGENTS.md
"""

from __future__ import annotations

import argparse
import difflib
import re
import sys
from pathlib import Path

RELAY_SECTION_HEADING = "## Agent relay channel"

CANONICAL_NOTE = (
    "*Canonical source: `.aitools/channel/relay.md` in the **aitools** git "
    "repository (clone path varies by machine). **Keep this section in sync** "
    "when you update relay in git; this mirror is for Cursor sessions that may "
    "not have that repo open.*\n\n"
)


def repo_root() -> Path:
    return Path(__file__).resolve().parent.parent


def demote_headings(text: str) -> str:
    """Add one `#` to each ATX heading line outside fenced code blocks."""

    def demote_line(line: str) -> str:
        m = re.match(r"^(#{1,6})(\s.*)$", line)
        if not m:
            return line
        depth = len(m.group(1))
        rest = m.group(2)
        if depth >= 6:
            return line
        return "#" * (depth + 1) + rest

    out: list[str] = []
    in_fence = False
    for line in text.splitlines():
        stripped = line.lstrip()
        if stripped.startswith("```"):
            in_fence = not in_fence
            out.append(line)
            continue
        if in_fence:
            out.append(line)
            continue
        out.append(demote_line(line))
    return "\n".join(out)


def strip_relay_title(text: str) -> str:
    """Remove top-level `# Agent Relay Channel` so the AGENTS section title is unique."""
    return re.sub(
        r"^#\s+Agent Relay Channel\s*\n",
        "",
        text,
        count=1,
        flags=re.MULTILINE,
    )


def split_agents_before_relay(content: str) -> tuple[str, bool]:
    """
    Return (prefix_before_heading, found_heading).
    Prefix is everything before the line `## Agent relay channel` (exclusive).
    """
    lines = content.splitlines(keepends=True)
    for i, line in enumerate(lines):
        if line.rstrip("\r\n") == RELAY_SECTION_HEADING:
            return "".join(lines[:i]), True
    return content, False


def build_agents_md(prefix: str, relay_body: str) -> str:
    body = relay_body.strip("\n") + "\n"
    block = (
        RELAY_SECTION_HEADING
        + "\n\n"
        + CANONICAL_NOTE
        + body
    )
    if not prefix:
        return block
    # Ensure exactly one blank line between prefix and relay section
    prefix = prefix.rstrip("\r\n") + "\n\n"
    return prefix + block


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument(
        "--relay",
        type=Path,
        default=None,
        help="Path to relay.md (default: <repo>/.aitools/channel/relay.md)",
    )
    p.add_argument(
        "--target",
        type=Path,
        default=Path.home() / ".cursor" / "AGENTS.md",
        help="Path to AGENTS.md (default: ~/.cursor/AGENTS.md)",
    )
    p.add_argument(
        "--dry-run",
        action="store_true",
        help="Print unified diff instead of writing",
    )
    args = p.parse_args()

    root = repo_root()
    relay_path = args.relay or (root / ".aitools" / "channel" / "relay.md")
    target_path = args.target.expanduser()

    if not relay_path.is_file():
        print(f"error: relay not found: {relay_path}", file=sys.stderr)
        return 1

    raw_relay = relay_path.read_text(encoding="utf-8")
    relay_body = demote_headings(strip_relay_title(raw_relay))

    old = ""
    if target_path.is_file():
        old = target_path.read_text(encoding="utf-8")

    prefix, found = split_agents_before_relay(old)
    if not found:
        print(
            f"warning: `{RELAY_SECTION_HEADING}` not found in {target_path}; "
            "prepended full relay section after existing content.",
            file=sys.stderr,
        )
        if old and not old.endswith("\n"):
            old += "\n"

    new = build_agents_md(prefix if found else old, relay_body)

    if args.dry_run:
        diff = difflib.unified_diff(
            old.splitlines(keepends=True),
            new.splitlines(keepends=True),
            fromfile=str(target_path),
            tofile=str(target_path) + " (new)",
        )
        sys.stdout.writelines(diff)
        return 0

    target_path.parent.mkdir(parents=True, exist_ok=True)
    target_path.write_text(new, encoding="utf-8")
    print(f"Wrote {target_path} ({len(new)} bytes) from {relay_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
