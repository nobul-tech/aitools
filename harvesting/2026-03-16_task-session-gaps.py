#!/usr/bin/env python3
"""Scan recent session transcripts for unfiled issues.

Reads JSONL session files from 2026-03-09 through 2026-03-16,
searches for keywords indicating problems that should have been
filed as incidents but weren't.
"""

import json
import os
import sys
from pathlib import Path
from datetime import date

SESSIONS_DIR = Path("/Users/pepe/repos/aitools-nobul-jose/sessions/aitools")
START_DATE = "2026-03-09"
END_DATE = "2026-03-16"

KEYWORDS = [
    "incident", "bug", "broken", "crash", "error", "fail",
    "wrong", "missing", "stale", "phantom", "TODO(incident)",
    "unbound variable", "unarchived", "unfiled", "gap",
    "not filed", "should file", "deviation", "bypass",
    "fake session", "fake ID", "mismatch", "date mismatch",
    "delegation failure", "can't write", "cannot write",
    "explore agent", "subagent"
]

FRUSTRATION_MARKERS = [
    "that's broken", "this is broken", "doesn't work",
    "not working", "failed", "still failing",
    "why is", "why does", "why didn't",
    "shouldn't", "should have", "should be",
    "that's wrong", "this is wrong",
    "problem", "issue", "concern"
]


def is_in_date_range(filename: str) -> bool:
    """Check if a session file date is in our target range."""
    # Files are named YYYY-MM-DD_<id>.jsonl
    try:
        file_date = filename[:10]
        return START_DATE <= file_date <= END_DATE
    except (IndexError, ValueError):
        return False


def extract_text_from_message(msg: dict) -> str:
    """Extract readable text from a JSONL message entry."""
    text_parts = []

    # Handle different message formats
    if isinstance(msg, dict):
        # Direct message content
        if "message" in msg:
            inner = msg["message"]
            if isinstance(inner, dict):
                content = inner.get("content", "")
                if isinstance(content, str):
                    text_parts.append(content)
                elif isinstance(content, list):
                    for block in content:
                        if isinstance(block, dict):
                            if block.get("type") == "text":
                                text_parts.append(block.get("text", ""))
                            elif block.get("type") == "tool_use":
                                text_parts.append(f"[tool: {block.get('name', '')}]")
                                inp = block.get("input", {})
                                if isinstance(inp, dict):
                                    for v in inp.values():
                                        if isinstance(v, str):
                                            text_parts.append(v[:500])
                            elif block.get("type") == "tool_result":
                                result_content = block.get("content", "")
                                if isinstance(result_content, str):
                                    text_parts.append(result_content[:500])
                                elif isinstance(result_content, list):
                                    for rb in result_content:
                                        if isinstance(rb, dict) and rb.get("type") == "text":
                                            text_parts.append(rb.get("text", "")[:500])
        # Type field
        if "type" in msg:
            if msg["type"] == "user":
                text_parts.append(f"[user message]")
            elif msg["type"] == "assistant":
                text_parts.append(f"[assistant message]")

    return " ".join(text_parts)


def get_role(msg: dict) -> str:
    """Get the role (human/assistant/system) from a message."""
    if isinstance(msg, dict):
        if "message" in msg and isinstance(msg["message"], dict):
            return msg["message"].get("role", "unknown")
        return msg.get("type", "unknown")
    return "unknown"


def scan_session(filepath: Path) -> dict:
    """Scan a single session file for issues."""
    findings = []
    line_count = 0
    errors = 0

    try:
        with open(filepath, "r", encoding="utf-8") as f:
            for line_num, line in enumerate(f, 1):
                line = line.strip()
                if not line:
                    continue
                line_count += 1

                try:
                    msg = json.loads(line)
                except json.JSONDecodeError:
                    errors += 1
                    continue

                text = extract_text_from_message(msg)
                role = get_role(msg)
                text_lower = text.lower()

                # Check for keywords
                matched_keywords = []
                for kw in KEYWORDS:
                    if kw.lower() in text_lower:
                        matched_keywords.append(kw)

                # Check for frustration markers
                matched_frustration = []
                for fm in FRUSTRATION_MARKERS:
                    if fm.lower() in text_lower:
                        matched_frustration.append(fm)

                if matched_keywords or matched_frustration:
                    # Extract a snippet around the match
                    snippet = text[:300].replace("\n", " ").strip()
                    if len(text) > 300:
                        snippet += "..."

                    findings.append({
                        "line": line_num,
                        "role": role,
                        "keywords": matched_keywords,
                        "frustration": matched_frustration,
                        "snippet": snippet,
                    })

    except Exception as e:
        return {
            "file": str(filepath),
            "error": str(e),
            "findings": [],
            "line_count": 0,
        }

    return {
        "file": str(filepath.name),
        "line_count": line_count,
        "parse_errors": errors,
        "findings": findings,
        "finding_count": len(findings),
    }


def main():
    # Get all session files in date range
    session_files = sorted([
        f for f in SESSIONS_DIR.iterdir()
        if f.suffix == ".jsonl" and is_in_date_range(f.name)
    ])

    print(f"Found {len(session_files)} sessions in range {START_DATE} to {END_DATE}")
    print()

    all_results = []
    for sf in session_files:
        print(f"Scanning {sf.name} ({sf.stat().st_size / 1024:.0f} KB)...")
        result = scan_session(sf)
        all_results.append(result)

        # Print summary for this session
        if result.get("finding_count", 0) > 0:
            print(f"  -> {result['finding_count']} findings ({result['line_count']} lines)")

            # Group by unique keyword combinations
            keyword_summary = {}
            for f in result["findings"]:
                key = tuple(sorted(set(f["keywords"])))
                if key not in keyword_summary:
                    keyword_summary[key] = 0
                keyword_summary[key] += 1

            for kws, count in sorted(keyword_summary.items(), key=lambda x: -x[1])[:10]:
                print(f"     {', '.join(kws) if kws else '(frustration only)'}: {count}x")
        else:
            print(f"  -> no findings")
        print()

    # Write detailed results to JSON for the report
    output_path = Path("/Users/pepe/repos/aitools/.scratch/session-952OZxWICI/scan-results.json")
    with open(output_path, "w") as f:
        json.dump(all_results, f, indent=2, default=str)
    print(f"\nDetailed results written to {output_path}")

    # Focus on the 5 known issues - look for specific patterns
    print("\n" + "=" * 60)
    print("FOCUSED SEARCH: 5 Known Unfiled Issues")
    print("=" * 60)

    focus_patterns = {
        "Stop hook crash": ["unbound variable", "surfacing-duty-stop", "line 54", "stop hook error"],
        "Uncommitted sessions on Mac": ["unarchived", "not archived", "session.*not.*archived", "uncommitted session", "missing session"],
        "Fake session ID 2Hb40B0VEu": ["2Hb40B0VEu", "fake.*session", "fake.*ID", "phantom.*session"],
        "Date mismatch archive/harvest": ["date mismatch", "date.*mismatch", "archive.*harvest", "harvest.*date"],
        "Explore agents can't write scratch": ["explore.*agent.*scratch", "explore.*write", "delegation.*failure", "can't write.*scratch", "cannot write.*scratch", "subagent.*scratch"],
    }

    for issue_name, patterns in focus_patterns.items():
        print(f"\n--- {issue_name} ---")
        found_any = False
        for result in all_results:
            for finding in result.get("findings", []):
                text_lower = finding["snippet"].lower()
                for pattern in patterns:
                    if pattern.lower() in text_lower:
                        print(f"  [{result['file']}:L{finding['line']}] ({finding['role']})")
                        print(f"    {finding['snippet'][:200]}")
                        found_any = True
                        break
        if not found_any:
            print("  (no direct mentions found in session text)")


if __name__ == "__main__":
    main()
