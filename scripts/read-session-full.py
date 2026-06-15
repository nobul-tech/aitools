#!/usr/bin/env python3
"""Read Claude Code session JSONL with FULL fidelity — text, thinking, tools, everything.

Unlike read-session.py (text-only, lossy), this preserves all content types:
user messages, assistant text, thinking blocks, tool calls, tool results,
and hook outputs. Designed for loading full session context into agents.

Usage:
    python3 scripts/read-session-full.py path/to/session.jsonl
    python3 scripts/read-session-full.py path/to/session.jsonl --last 50
    python3 scripts/read-session-full.py path/to/session.jsonl --search "verbatim"
    python3 scripts/read-session-full.py path/to/session.jsonl --no-hooks
    python3 scripts/read-session-full.py path/to/session.jsonl --output /tmp/session.md
"""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path

# Force UTF-8 stdout/stderr so non-ASCII transcript content (arrows, em-dashes,
# emoji) does not crash on a Windows console using a legacy code page (cp1252).
# reconfigure() exists on Python 3.7+ TextIOWrapper; guard for stdout objects
# that lack it (e.g. some test harnesses) and check the result below.
for _stream in (sys.stdout, sys.stderr):
    _reconfigure = getattr(_stream, "reconfigure", None)
    if _reconfigure is not None:
        try:
            _reconfigure(encoding="utf-8")
        except (ValueError, OSError):
            # Stream does not support re-encoding; output may mangle non-ASCII
            # but the tool should still run. Honor PYTHONIOENCODING if set.
            pass


@dataclass
class Entry:
    """A single JSONL entry with all content preserved."""
    entry_type: str  # user, assistant, tool_use, tool_result, hook, thinking, progress
    role: str
    text: str
    timestamp: str
    tool_name: str = ""
    tool_input: str = ""
    metadata: dict = field(default_factory=dict)


def parse_timestamp(ts: str) -> datetime:
    ts = ts.replace("Z", "+00:00")
    return datetime.fromisoformat(ts)


def format_ts(ts: str) -> str:
    if not ts:
        return ""
    try:
        dt = parse_timestamp(ts)
        return dt.strftime("%H:%M:%S")
    except (ValueError, TypeError):
        return ts[:19]


def extract_all(jsonl_path: Path, include_hooks: bool = True) -> list[Entry]:
    """Extract all content from a session JSONL file."""
    entries: list[Entry] = []
    seen_texts: set[str] = set()

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

            # Skip file-history-snapshot entries
            if msg_type == "file-history-snapshot":
                continue

            # Hook progress
            if msg_type == "progress":
                data = obj.get("data", {})
                if data.get("type") == "hook_progress" and include_hooks:
                    hook_name = data.get("hookName", "")
                    entries.append(Entry(
                        entry_type="hook",
                        role="HOOK",
                        text=hook_name,
                        timestamp=timestamp,
                    ))
                continue

            # User messages
            if msg_type == "user":
                message = obj.get("message", {})
                content = message.get("content", "")

                if isinstance(content, str):
                    # Skip task notifications
                    if content.startswith("<task-notification>"):
                        continue
                    origin = obj.get("origin", {})
                    if isinstance(origin, dict) and origin.get("kind") == "task-notification":
                        continue
                    entries.append(Entry(
                        entry_type="user",
                        role="COMMANDER",
                        text=content,
                        timestamp=timestamp,
                    ))
                elif isinstance(content, list):
                    # Tool results from user
                    for item in content:
                        if isinstance(item, dict) and item.get("type") == "tool_result":
                            tool_id = item.get("tool_use_id", "")
                            result_content = item.get("content", "")
                            if isinstance(result_content, list):
                                texts = [b.get("text", "") for b in result_content if isinstance(b, dict) and b.get("type") == "text"]
                                result_content = "\n".join(texts)
                            if isinstance(result_content, str) and len(result_content) > 500:
                                result_content = result_content[:500] + f"\n... [{len(result_content)} chars total]"
                            entries.append(Entry(
                                entry_type="tool_result",
                                role="TOOL_RESULT",
                                text=str(result_content),
                                timestamp=timestamp,
                                tool_name=tool_id,
                            ))
                continue

            # Assistant messages
            if msg_type == "assistant":
                message = obj.get("message", {})
                content_blocks = message.get("content", [])

                for block in content_blocks:
                    if not isinstance(block, dict):
                        continue

                    block_type = block.get("type", "")

                    if block_type == "thinking":
                        thinking_text = block.get("thinking", "")
                        if thinking_text and thinking_text not in seen_texts:
                            seen_texts.add(thinking_text)
                            if len(thinking_text) > 2000:
                                thinking_text = thinking_text[:2000] + f"\n... [{len(thinking_text)} chars total]"
                            entries.append(Entry(
                                entry_type="thinking",
                                role="THINKING",
                                text=thinking_text,
                                timestamp=timestamp,
                            ))

                    elif block_type == "text":
                        text = block.get("text", "")
                        if text and text not in seen_texts:
                            seen_texts.add(text)
                            entries.append(Entry(
                                entry_type="assistant",
                                role="AGENT",
                                text=text,
                                timestamp=timestamp,
                            ))

                    elif block_type == "tool_use":
                        tool_name = block.get("name", "")
                        tool_input = block.get("input", {})
                        # Summarize large inputs
                        input_str = json.dumps(tool_input, indent=2)
                        if len(input_str) > 1000:
                            # For file writes, show path + first 200 chars of content
                            if "file_path" in tool_input:
                                content_preview = str(tool_input.get("content", ""))[:200]
                                input_str = f'{{"file_path": "{tool_input["file_path"]}", "content": "{content_preview}..."}}'
                            else:
                                input_str = input_str[:1000] + f"\n... [{len(input_str)} chars total]"
                        entries.append(Entry(
                            entry_type="tool_use",
                            role="TOOL",
                            text=f"{tool_name}",
                            timestamp=timestamp,
                            tool_name=tool_name,
                            tool_input=input_str,
                        ))

                continue

    return entries


def filter_entries(
    entries: list[Entry],
    *,
    last_n: int | None = None,
    search: str | None = None,
) -> list[Entry]:
    result = entries
    if search is not None:
        term = search.lower()
        result = [e for e in result if term in e.text.lower() or term in e.tool_input.lower()]
    if last_n is not None:
        result = result[-last_n:]
    return result


def format_entries(entries: list[Entry]) -> str:
    lines: list[str] = []
    for e in entries:
        ts = format_ts(e.timestamp)
        prefix = f"[{ts}] " if ts else ""

        if e.entry_type == "thinking":
            lines.append(f"{prefix}THINKING: {e.text}")
        elif e.entry_type == "tool_use":
            lines.append(f"{prefix}TOOL: {e.text}")
            if e.tool_input:
                lines.append(f"  INPUT: {e.tool_input}")
        elif e.entry_type == "tool_result":
            lines.append(f"{prefix}RESULT: {e.text}")
        elif e.entry_type == "hook":
            lines.append(f"{prefix}HOOK: {e.text}")
        else:
            lines.append(f"{prefix}{e.role}: {e.text}")

        lines.append("")
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Read Claude Code session JSONL with full fidelity.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("jsonl_file", type=Path, help="Path to session JSONL")
    parser.add_argument("--last", type=int, default=None, metavar="N", help="Last N entries")
    parser.add_argument("--search", type=str, default=None, metavar="TERM", help="Search term")
    parser.add_argument("--no-hooks", action="store_true", help="Exclude hook progress entries")
    parser.add_argument("--no-thinking", action="store_true", help="Exclude thinking blocks")
    parser.add_argument("--no-tools", action="store_true", help="Exclude tool use/result entries")
    parser.add_argument("--output", type=Path, default=None, metavar="FILE", help="Write to file instead of stdout")

    args = parser.parse_args()

    if not args.jsonl_file.exists():
        print(f"Error: file not found: {args.jsonl_file}", file=sys.stderr)
        sys.exit(1)

    entries = extract_all(args.jsonl_file, include_hooks=not args.no_hooks)

    if args.no_thinking:
        entries = [e for e in entries if e.entry_type != "thinking"]
    if args.no_tools:
        entries = [e for e in entries if e.entry_type not in ("tool_use", "tool_result")]

    filtered = filter_entries(entries, last_n=args.last, search=args.search)

    if not filtered:
        print("No entries match the filters.", file=sys.stderr)
        sys.exit(0)

    output = format_entries(filtered)

    if args.output:
        args.output.write_text(output, encoding="utf-8")
        print(f"Written to {args.output} ({len(filtered)} entries)", file=sys.stderr)
    else:
        print(output)


if __name__ == "__main__":
    main()
