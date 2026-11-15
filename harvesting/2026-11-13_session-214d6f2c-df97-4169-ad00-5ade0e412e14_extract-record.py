#!/usr/bin/env python3
"""extract-record.py -- pull a BEGIN/END RECORD block out of a session transcript.

Reads a Claude Code session JSONL, finds assistant text blocks that contain
"BEGIN RECORD <id>" ... "END RECORD <id>", and writes the first block found
to the output file (trailing newline added). Exit 0 when found, 1 when not,
2 on bad usage.

Usage: python3 extract-record.py <session.jsonl> <record-id> <out-file>
"""
import json
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 4 or sys.argv[1] in ("-h", "--help"):
        print(__doc__, file=sys.stderr)
        return 2
    session, record_id, out = Path(sys.argv[1]), sys.argv[2], Path(sys.argv[3])
    begin, end = f"BEGIN RECORD {record_id}", f"END RECORD {record_id}"
    found: list[str] = []
    with session.open(encoding="utf-8") as fh:
        for raw in fh:
            try:
                obj = json.loads(raw)
            except json.JSONDecodeError:
                continue
            if obj.get("type") != "assistant":
                continue
            content = obj.get("message", {}).get("content", [])
            if not isinstance(content, list):
                continue
            for block in content:
                if not isinstance(block, dict) or block.get("type") != "text":
                    continue
                text = block.get("text", "")
                if begin in text and end in text:
                    start = text.index(begin)
                    stop = text.index(end, start) + len(end)
                    found.append(text[start:stop])
    if not found:
        print(f"no record {record_id} found in {session}", file=sys.stderr)
        return 1
    out.write_text(found[0] + "\n", encoding="utf-8")
    print(f"records found: {len(found)}; first written to {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
