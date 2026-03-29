#!/usr/bin/env python3
"""Read Claude Code session JSONL files and extract human-readable conversation.

Extracts only user (COMMANDER) and assistant (AGENT) text messages,
filtering out tool calls, hooks, system messages, and thinking blocks.

Usage:
    python3 scripts/read-session.py path/to/session.jsonl
    python3 scripts/read-session.py path/to/session.jsonl --last 10
    python3 scripts/read-session.py path/to/session.jsonl --after 2026-03-26T21:00:00Z
    python3 scripts/read-session.py path/to/session.jsonl --search "verbatim"
"""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path


@dataclass
class Exchange:
    """A single message in the conversation."""

    role: str  # "COMMANDER" or "AGENT"
    text: str
    timestamp: str


def parse_timestamp(ts: str) -> datetime:
    """Parse ISO 8601 timestamp, handling Z suffix."""
    ts = ts.replace("Z", "+00:00")
    return datetime.fromisoformat(ts)


def extract_exchanges(jsonl_path: Path) -> list[Exchange]:
    """Extract user and assistant text messages from a session JSONL file."""
    exchanges: list[Exchange] = []

    with jsonl_path.open("r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                continue

            msg_type = obj.get("type", "")
            timestamp = obj.get("timestamp", "")

            if msg_type == "user":
                message = obj.get("message", {})
                content = message.get("content", "")
                # Skip tool results (content is a list with tool_result items)
                if isinstance(content, list):
                    # Check if it's a task notification with readable text
                    for item in content:
                        if isinstance(item, dict) and item.get("type") == "tool_result":
                            # Skip tool results entirely
                            pass
                    continue
                # Skip system injections and task notifications
                if not isinstance(content, str):
                    continue
                if content.startswith("<task-notification>"):
                    continue
                # Skip if it looks like a system prompt injection
                origin = obj.get("origin", {})
                if isinstance(origin, dict) and origin.get("kind") == "task-notification":
                    continue

                exchanges.append(Exchange(
                    role="COMMANDER",
                    text=content,
                    timestamp=timestamp,
                ))

            elif msg_type == "assistant":
                message = obj.get("message", {})
                content_blocks = message.get("content", [])
                # Extract only text blocks (skip thinking, tool_use)
                text_parts: list[str] = []
                for block in content_blocks:
                    if isinstance(block, dict) and block.get("type") == "text":
                        text_parts.append(block["text"])

                if text_parts:
                    full_text = "\n\n".join(text_parts)
                    exchanges.append(Exchange(
                        role="AGENT",
                        text=full_text,
                        timestamp=timestamp,
                    ))

    return exchanges


def format_timestamp(ts: str) -> str:
    """Format timestamp for display."""
    if not ts:
        return ""
    try:
        dt = parse_timestamp(ts)
        return dt.strftime("%H:%M:%S")
    except (ValueError, TypeError):
        return ts[:19]


def filter_exchanges(
    exchanges: list[Exchange],
    *,
    last_n: int | None = None,
    after: str | None = None,
    search: str | None = None,
) -> list[Exchange]:
    """Apply filters to the exchange list."""
    result = exchanges

    if after is not None:
        after_dt = parse_timestamp(after)
        result = [
            ex for ex in result
            if ex.timestamp and parse_timestamp(ex.timestamp) >= after_dt
        ]

    if search is not None:
        term = search.lower()
        result = [
            ex for ex in result
            if term in ex.text.lower()
        ]

    if last_n is not None:
        # "Last N exchanges" means last N pairs of commander+agent
        # But we count individual messages to be safe
        result = result[-last_n:]

    return result


def print_exchanges(exchanges: list[Exchange]) -> None:
    """Print exchanges in clean readable format."""
    for ex in exchanges:
        ts = format_timestamp(ex.timestamp)
        prefix = f"[{ts}] " if ts else ""
        print(f"{prefix}{ex.role}: {ex.text}")
        print()


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Read Claude Code session JSONL and extract conversation.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s session.jsonl                      Show full conversation
  %(prog)s session.jsonl --last 20            Show last 20 messages
  %(prog)s session.jsonl --after 2026-03-26T21:00:00Z  After timestamp
  %(prog)s session.jsonl --search "verbatim"  Find messages with term
        """,
    )
    parser.add_argument(
        "jsonl_file",
        type=Path,
        help="Path to the session JSONL file",
    )
    parser.add_argument(
        "--last",
        type=int,
        default=None,
        metavar="N",
        help="Show only the last N messages",
    )
    parser.add_argument(
        "--after",
        type=str,
        default=None,
        metavar="TIMESTAMP",
        help="Show messages after this ISO 8601 timestamp (e.g., 2026-03-26T21:00:00Z)",
    )
    parser.add_argument(
        "--search",
        type=str,
        default=None,
        metavar="TERM",
        help="Show only messages containing this term (case-insensitive)",
    )

    args = parser.parse_args()

    if not args.jsonl_file.exists():
        print(f"Error: file not found: {args.jsonl_file}", file=sys.stderr)
        sys.exit(1)

    exchanges = extract_exchanges(args.jsonl_file)

    if not exchanges:
        print("No conversation exchanges found.", file=sys.stderr)
        sys.exit(0)

    filtered = filter_exchanges(
        exchanges,
        last_n=args.last,
        after=args.after,
        search=args.search,
    )

    if not filtered:
        print("No exchanges match the filters.", file=sys.stderr)
        sys.exit(0)

    print_exchanges(filtered)


if __name__ == "__main__":
    main()
