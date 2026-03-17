#!/usr/bin/env python3
"""Extract intent-approval interactions from tool-ops session JSONL.

Purpose: Parse the session transcript and extract text content from user
and assistant messages, focusing on intent approvals, batch boundaries,
user feedback, and approach changes.
"""

import json
import re
import sys
from pathlib import Path
from typing import Any

SESSION_FILE = Path("/Users/pepe/repos/aitools-nobul-jose/sessions/aitools/2026-03-15_eaacf9da.jsonl")
OUTPUT_DIR = Path("/Users/pepe/repos/aitools/.scratch/session-952OZxWICI")


def extract_text_content(content: Any) -> str:
    """Extract text from message content (can be string or list of blocks)."""
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts = []
        for block in content:
            if isinstance(block, dict):
                if block.get("type") == "text":
                    parts.append(block.get("text", ""))
                elif block.get("type") == "tool_use":
                    tool_name = block.get("name", "")
                    tool_input = block.get("input", {})
                    if tool_name == "TaskCreate":
                        desc = tool_input.get("description", "")
                        parts.append(f"[TaskCreate: {desc[:300]}]")
                    elif tool_name in ("Write", "Edit"):
                        fp = tool_input.get("file_path", "")
                        if "intent" in str(tool_input).lower():
                            new_s = tool_input.get("new_string", tool_input.get("content", ""))
                            parts.append(f"[{tool_name}: {fp}]\n  content with intent: {new_s[:500]}")
                        else:
                            parts.append(f"[{tool_name}: {fp}]")
                    elif tool_name == "Read":
                        fp = tool_input.get("file_path", "")
                        parts.append(f"[Read: {fp}]")
                    else:
                        parts.append(f"[{tool_name}]")
        return "\n".join(parts)
    return str(content)


def main() -> None:
    # Phase 1: Extract all user/assistant messages with their line numbers
    messages: list[dict] = []

    with open(SESSION_FILE) as f:
        for line_num, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            try:
                record = json.loads(line)
            except json.JSONDecodeError:
                continue

            rec_type = record.get("type", "")
            if rec_type not in ("user", "assistant"):
                continue

            role = rec_type
            message = record.get("message", {})
            content = message.get("content", "")
            text = extract_text_content(content)
            ts = record.get("timestamp", "")

            if not text.strip():
                continue

            messages.append({
                "line_num": line_num,
                "role": role,
                "text": text,
                "timestamp": ts,
            })

    # Phase 2: Identify batch boundaries
    # Look for messages that mark batch transitions
    batch_markers = []
    for msg in messages:
        text_lower = msg["text"].lower()
        for batch_num in range(1, 9):
            patterns = [
                f"batch {batch_num}",
                f"batch{batch_num}",
            ]
            for p in patterns:
                if p in text_lower:
                    batch_markers.append({
                        "line_num": msg["line_num"],
                        "role": msg["role"],
                        "batch": batch_num,
                        "timestamp": msg["timestamp"],
                    })
                    break

    # Phase 3: Extract key interactions
    key_patterns = {
        "intent_presentation": re.compile(r'(?:intent|purpose|scope|audience).*?:', re.IGNORECASE),
        "approval_request": re.compile(r'(?:approve|approval|confirm|good to go|ready to|shall I|OK with)', re.IGNORECASE),
        "user_feedback": re.compile(r'(?:perfect|lgtm|looks good|go ahead|yes|great|nice|approved|ship|rough|frustrat|confus|better|smooth)', re.IGNORECASE),
        "approach_change": re.compile(r'(?:present.*together|all intents|consolidat|streamlin|batch.*intent|combined.*review|group.*together|upfront|front-load|up.?front)', re.IGNORECASE),
        "protected_file": re.compile(r'(?:protected|source.of.truth|review gate|present for review|wait for approval)', re.IGNORECASE),
        "delegation": re.compile(r'(?:delegat|sub.?agent|TaskCreate)', re.IGNORECASE),
    }

    # Phase 4: Build detailed report for key lines
    # Focus on lines identified in the initial scan
    key_lines = [68, 73, 74, 78, 81, 83, 87, 90, 91,
                 149, 162, 213, 219, 254, 303, 339,
                 373, 534, 548, 555, 556,
                 691, 699, 700, 851, 853,
                 863, 870, 875, 876,
                 921, 923, 937, 950, 951,
                 1086, 1088, 1101, 1102,
                 1237, 1238, 1293, 1294]

    report_lines = []
    for msg in messages:
        # Check if this message matches any key pattern or is in our key lines
        matched = {}
        for name, pattern in key_patterns.items():
            if pattern.search(msg["text"]):
                matched[name] = True

        is_key_line = msg["line_num"] in key_lines
        is_user = msg["role"] == "user"

        if matched or is_key_line or is_user:
            # Determine current batch context
            batch_refs = re.findall(r'[Bb]atch\s*(\d)', msg["text"])

            report_lines.append({
                "line_num": msg["line_num"],
                "role": msg["role"],
                "timestamp": msg["timestamp"],
                "matched_patterns": list(matched.keys()),
                "batch_refs": sorted(set(batch_refs)),
                "text_preview": msg["text"][:3000],
                "is_key_line": is_key_line,
            })

    # Write detailed report
    with open(OUTPUT_DIR / "intent-report-detail.json", "w") as f:
        json.dump(report_lines, f, indent=2)

    # Print summary for key interactions
    print(f"Total messages: {len(messages)}")
    print(f"  User messages: {sum(1 for m in messages if m['role'] == 'user')}")
    print(f"  Assistant messages: {sum(1 for m in messages if m['role'] == 'assistant')}")
    print()

    print("=== KEY INTERACTIONS (user messages) ===")
    for item in report_lines:
        if item["role"] == "user":
            text = item["text_preview"][:200].replace("\n", " ")
            print(f"  L{item['line_num']:4d} [{item['timestamp'][:19]}] batch={item['batch_refs']} patterns={item['matched_patterns']}")
            print(f"         {text}")
            print()

    print("=== APPROACH CHANGES (assistant) ===")
    for item in report_lines:
        if item["role"] == "assistant" and "approach_change" in item["matched_patterns"]:
            text = item["text_preview"][:500].replace("\n", " ")
            print(f"  L{item['line_num']:4d} [{item['timestamp'][:19]}] batch={item['batch_refs']}")
            print(f"         {text}")
            print()

    print("=== INTENT PRESENTATIONS (assistant, with approval_request) ===")
    for item in report_lines:
        if item["role"] == "assistant" and "intent_presentation" in item["matched_patterns"]:
            if item["batch_refs"]:
                text = item["text_preview"][:500].replace("\n", " ")
                print(f"  L{item['line_num']:4d} [{item['timestamp'][:19]}] batch={item['batch_refs']}")
                print(f"         {text}")
                print()

    print("=== DELEGATION POINTS ===")
    for item in report_lines:
        if "delegation" in item["matched_patterns"] and item["batch_refs"]:
            text = item["text_preview"][:300].replace("\n", " ")
            print(f"  L{item['line_num']:4d} [{item['timestamp'][:19]}] {item['role']} batch={item['batch_refs']}")
            print(f"         {text}")
            print()


if __name__ == "__main__":
    main()
